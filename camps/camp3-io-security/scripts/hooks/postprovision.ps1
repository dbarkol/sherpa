# Postprovision hook for Camp 3
# Called automatically by azd after infrastructure deployment

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $ScriptDir "..\..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Post-provision Configuration"
Write-Host "=========================================="
Write-Host ""

# Get deployment outputs from azd
Write-Host "Loading deployment outputs..."
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP
$LOCATION = azd env get-value AZURE_LOCATION
$ACR_NAME = azd env get-value AZURE_CONTAINER_REGISTRY_NAME
$APIM_NAME = azd env get-value APIM_NAME
$APIM_GATEWAY_URL = azd env get-value APIM_GATEWAY_URL
$APIM_LOCATION = azd env get-value APIM_LOCATION
$CONTENT_SAFETY_ENDPOINT = azd env get-value CONTENT_SAFETY_ENDPOINT
$CONTENT_SAFETY_LOCATION = azd env get-value CONTENT_SAFETY_LOCATION
$FUNCTION_APP_NAME = azd env get-value FUNCTION_APP_NAME
$FUNCTION_APP_URL = azd env get-value FUNCTION_APP_URL
$SHERPA_SERVER_URL = azd env get-value SHERPA_SERVER_URL
$TRAIL_API_URL = azd env get-value TRAIL_API_URL

# Show region adjustments if any
if ($APIM_LOCATION -ne $LOCATION -or $CONTENT_SAFETY_LOCATION -ne $LOCATION) {
    Write-Host ""
    Write-Host "Region adjustments made for service availability:"
    if ($APIM_LOCATION -ne $LOCATION) { Write-Host "  API Management: $LOCATION -> $APIM_LOCATION" }
    if ($CONTENT_SAFETY_LOCATION -ne $LOCATION) { Write-Host "  Content Safety: $LOCATION -> $CONTENT_SAFETY_LOCATION" }
}

# Load Entra ID app IDs from environment
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID
$TENANT_ID = azd env get-value AZURE_TENANT_ID 2>$null
if (-not $TENANT_ID) {
    $TENANT_ID = az account show --query tenantId -o tsv
}

Write-Host ""
Write-Host "Configuration:"
Write-Host "  Resource Group: $RG_NAME"
Write-Host "  ACR: $ACR_NAME"
Write-Host "  APIM: $APIM_NAME"
Write-Host "  Gateway URL: $APIM_GATEWAY_URL"
Write-Host "  Function App: $FUNCTION_APP_NAME"
Write-Host "  Function URL: $FUNCTION_APP_URL"
Write-Host "  Sherpa Server: $SHERPA_SERVER_URL"
Write-Host "  Trail API: $TRAIL_API_URL"
Write-Host "  Tenant ID: $TENANT_ID"
Write-Host "  MCP App Client ID: $MCP_APP_CLIENT_ID"
Write-Host ""

# Configure APIM APIs and backends
Write-Host "Configuring APIM APIs..."
az deployment group create `
    --resource-group $RG_NAME `
    --template-file infra/waypoints/initial-api-setup.bicep `
    --parameters `
        apimName=$APIM_NAME `
        sherpaServerUrl=$SHERPA_SERVER_URL `
        trailApiUrl=$TRAIL_API_URL `
        contentSafetyEndpoint=$CONTENT_SAFETY_ENDPOINT `
        tenantId=$TENANT_ID `
        mcpAppClientId=$MCP_APP_CLIENT_ID `
    --output none

Write-Host "APIM APIs configured successfully"

Write-Host ""
Write-Host "=========================================="
Write-Host "Post-provision Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "Infrastructure deployed successfully!"
Write-Host ""
Write-Host "Camp 3: I/O Security"
Write-Host "===================="
Write-Host ""
Write-Host "What's deployed:"
Write-Host "  - APIM with OAuth + Content Safety (Layer 1)"
Write-Host "  - Sherpa MCP Server (Container App)"
Write-Host "  - Trail API with PII endpoint (Container App)"
Write-Host "  - Security Function (not yet wired to APIM)"
Write-Host ""
Write-Host "The security function is deployed but NOT yet enabled."
Write-Host "This allows you to demonstrate the vulnerability first."
Write-Host ""
Write-Host "Next steps:"
Write-Host ""
Write-Host "  1. Demonstrate vulnerabilities (before fix):"
Write-Host "     ./scripts/1.1-exploit-injection.ps1"
Write-Host "     ./scripts/1.1-exploit-pii.ps1"
Write-Host ""
Write-Host "  2. Deploy and enable security function:"
Write-Host "     ./scripts/1.2-deploy-function.ps1"
Write-Host "     ./scripts/1.2-enable-io-security.ps1"
Write-Host ""
Write-Host "  3. Validate security (after fix):"
Write-Host "     ./scripts/1.3-validate-injection.ps1"
Write-Host "     ./scripts/1.3-validate-pii.ps1"
Write-Host ""
