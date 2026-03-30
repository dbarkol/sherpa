# Create a Sherpa MCP API in Azure API Management using ARM REST calls (via az rest).
#
# Required environment variables:
#   SUBSCRIPTION_ID
#   RESOURCE_GROUP
#   APIM_NAME
#   SHERPA_SERVER_URL   (example: https://<your-sherpa-server-host>)
#
# Optional environment variables (for OAuth PRM metadata):
#   TENANT_ID
#   MCP_APP_CLIENT_ID
#
# Optional naming overrides:
#   SERVER_NAME      (default: sherpa-mcp)
#   API_PATH         (default: sherpa/mcp)
#   BACKEND_ID       (default: <SERVER_NAME>-backend)
#
# Example for a second server name:
#   $env:SERVER_NAME = "sherpa-mcp2"
#   $env:API_PATH = "sherpa/mcp2"
#
# Example:
#   $env:SUBSCRIPTION_ID = az account show --query id -o tsv
#   $env:RESOURCE_GROUP = "rg-camp2-dev"
#   $env:APIM_NAME = "apim-rg-camp2-dev"
#   $env:SHERPA_SERVER_URL = "https://your-sherpa-server.example.com"
#   $env:TENANT_ID = az account show --query tenantId -o tsv
#   $env:MCP_APP_CLIENT_ID = "<entra-app-client-id>"
#   ./create-sherpa-mcp-apim.ps1

$ErrorActionPreference = 'Stop'

$API_VERSION = "2024-06-01-preview"
$SERVER_NAME = if ($env:SERVER_NAME) { $env:SERVER_NAME } else { "sherpa-mcp" }
$API_PATH = if ($env:API_PATH) { $env:API_PATH } else { "sherpa/mcp" }
$BACKEND_ID = if ($env:BACKEND_ID) { $env:BACKEND_ID } else { "$SERVER_NAME-backend" }
$API_ID = if ($env:API_ID) { $env:API_ID } else { $SERVER_NAME }
$MCP_OPERATION_ID = "mcp-endpoint"
$OAUTH_API_ID = "oauth-prm"
$PRM_RESOURCE_PATH = $API_PATH
$PRM_RESOURCE_PATH_ID = $PRM_RESOURCE_PATH -replace "/", "-"
$OAUTH_OPERATION_ID = "get-prm-$PRM_RESOURCE_PATH_ID"

# Validate required variables
$requiredVars = @("SUBSCRIPTION_ID", "RESOURCE_GROUP", "APIM_NAME", "SHERPA_SERVER_URL")
foreach ($v in $requiredVars) {
    if (-not [Environment]::GetEnvironmentVariable($v)) {
        Write-Host "Missing required env var: $v"
        exit 1
    }
}

$ENABLE_PRM = "true"
if (-not $env:TENANT_ID -or -not $env:MCP_APP_CLIENT_ID) {
    Write-Host "Warning: TENANT_ID and/or MCP_APP_CLIENT_ID not set."
    Write-Host "The API will still be created, but OAuth PRM metadata will be skipped."
    $ENABLE_PRM = "false"
}

$BASE = "https://management.azure.com/subscriptions/$($env:SUBSCRIPTION_ID)/resourceGroups/$($env:RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$($env:APIM_NAME)"

$APIM_GATEWAY_URL = az rest --method GET `
    --uri "$BASE`?api-version=$API_VERSION" `
    --query "properties.gatewayUrl" `
    -o tsv

if (-not $APIM_GATEWAY_URL) {
    Write-Host "Failed to resolve APIM gateway URL from ARM."
    exit 1
}

Write-Host "[1/6] Create backend '$BACKEND_ID'"
$backendBody = @{
    properties = @{
        protocol = "http"
        url = "$($env:SHERPA_SERVER_URL)/mcp"
        title = "Sherpa MCP Server"
        description = "Backend for Sherpa MCP Server"
    }
} | ConvertTo-Json -Depth 5 -Compress

az rest --method PUT `
    --uri "$BASE/backends/$BACKEND_ID`?api-version=$API_VERSION" `
    --body $backendBody `
    --output none

Write-Host "[2/6] Create MCP API '$API_ID'"
$apiBody = @{
    properties = @{
        displayName = $SERVER_NAME
        description = "MCP server passthrough for weather, trails, and gear tools"
        path = $API_PATH
        protocols = @("https")
        subscriptionRequired = $false
        type = "mcp"
        backendId = $BACKEND_ID
        mcpProperties = @{
            transportType = "streamable"
        }
    }
} | ConvertTo-Json -Depth 5 -Compress

az rest --method PUT `
    --uri "$BASE/apis/$API_ID`?api-version=$API_VERSION" `
    --body $apiBody `
    --output none

Write-Host "[3/6] Create MCP catch-all operation '$MCP_OPERATION_ID'"
$operationBody = @{
    properties = @{
        displayName = "MCP Endpoint"
        method = "*"
        urlTemplate = "/"
        description = "Catch-all MCP JSON-RPC endpoint"
    }
} | ConvertTo-Json -Depth 5 -Compress

az rest --method PUT `
    --uri "$BASE/apis/$API_ID/operations/$MCP_OPERATION_ID`?api-version=$API_VERSION" `
    --body $operationBody `
    --output none

Write-Host "[4/6] Apply base API policy (route API to backend)"
$MCP_POLICY = @"
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="$BACKEND_ID" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
"@

$policyBody = @{
    properties = @{
        format = "rawxml"
        value = $MCP_POLICY
    }
} | ConvertTo-Json -Depth 5 -Compress

az rest --method PUT `
    --uri "$BASE/apis/$API_ID/policies/policy`?api-version=$API_VERSION" `
    --body $policyBody `
    --output none

Write-Host "[5/6] (Optional) Create OAuth PRM discovery API at root"
if ($ENABLE_PRM -eq "true") {
    $oauthApiBody = @{
        properties = @{
            displayName = "OAuth Protected Resource Metadata"
            description = "RFC 9728 PRM discovery endpoint"
            path = ""
            protocols = @("https")
            subscriptionRequired = $false
            apiType = "http"
        }
    } | ConvertTo-Json -Depth 5 -Compress

    az rest --method PUT `
        --uri "$BASE/apis/$OAUTH_API_ID`?api-version=$API_VERSION" `
        --body $oauthApiBody `
        --output none

    $oauthOperationBody = @{
        properties = @{
            displayName = "Get PRM for MCP API"
            method = "GET"
            urlTemplate = "/.well-known/oauth-protected-resource/$PRM_RESOURCE_PATH"
            description = "RFC 9728 path-based PRM discovery for MCP API"
        }
    } | ConvertTo-Json -Depth 5 -Compress

    az rest --method PUT `
        --uri "$BASE/apis/$OAUTH_API_ID/operations/$OAUTH_OPERATION_ID`?api-version=$API_VERSION" `
        --body $oauthOperationBody `
        --output none

    $PRM_POLICY = @{
        issuer = "$APIM_GATEWAY_URL/"
        authorization_endpoint = "https://login.microsoftonline.com/$($env:TENANT_ID)/oauth2/v2.0/authorize"
        token_endpoint = "https://login.microsoftonline.com/$($env:TENANT_ID)/oauth2/v2.0/token"
        jwks_uri = "https://login.microsoftonline.com/$($env:TENANT_ID)/discovery/v2.0/keys"
        resource = "$APIM_GATEWAY_URL/$PRM_RESOURCE_PATH"
        scopes_supported = @("api://$($env:MCP_APP_CLIENT_ID)/.default")
    } | ConvertTo-Json -Depth 5

    $PRM_XML = "<policies><inbound><base /><return-response><set-status code=`"200`" reason=`"OK`" /><set-header name=`"Content-Type`" exists-action=`"override`"><value>application/json</value></set-header><set-body>$PRM_POLICY</set-body></return-response></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>"

    $prmPolicyBody = @{
        properties = @{
            format = "rawxml"
            value = $PRM_XML
        }
    } | ConvertTo-Json -Depth 5 -Compress

    az rest --method PUT `
        --uri "$BASE/apis/$OAUTH_API_ID/operations/$OAUTH_OPERATION_ID/policies/policy`?api-version=$API_VERSION" `
        --body $prmPolicyBody `
        --output none
}

Write-Host "[6/6] Verify API exists"
az rest --method GET `
    --uri "$BASE/apis/$API_ID`?api-version=$API_VERSION" `
    --query "properties | {displayName: displayName, path: path, type: type}" `
    -o table

Write-Host ""
Write-Host "Done. Test endpoint: $APIM_GATEWAY_URL/$API_PATH"
if ($ENABLE_PRM -eq "true") {
    Write-Host "PRM endpoint:      $APIM_GATEWAY_URL/.well-known/oauth-protected-resource/$PRM_RESOURCE_PATH"
}
