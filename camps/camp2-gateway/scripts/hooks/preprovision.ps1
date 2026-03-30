# Preprovision hook for Camp 2
# Creates Entra ID app registrations before infrastructure deployment

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "=========================================="
Write-Host "Camp 2: Entra ID App Registration"
Write-Host "=========================================="
Write-Host ""

# Sync AZURE_LOCATION with resource group location if RG already exists
# This ensures Bicep uses the same location as the resource group
if ($env:AZURE_RESOURCE_GROUP) {
    $RG_LOCATION = az group show -n $env:AZURE_RESOURCE_GROUP --query location -o tsv 2>$null
    if ($RG_LOCATION -and $RG_LOCATION -ne $env:AZURE_LOCATION) {
        Write-Host "Syncing AZURE_LOCATION to resource group location: $RG_LOCATION"
        azd env set AZURE_LOCATION $RG_LOCATION
        $env:AZURE_LOCATION = $RG_LOCATION
    }
}

# Get tenant ID
$TENANT_ID = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $TENANT_ID"

# Unique name for apps
$envName = if ($env:AZURE_ENV_NAME) { $env:AZURE_ENV_NAME } else { "camp2" }
$suffix = (Get-Date -UFormat %s).Substring((Get-Date -UFormat %s).Length - 4)
$APP_SUFFIX = "$envName-$suffix"

# Generate UUIDs upfront
$SCOPE_ID = [guid]::NewGuid().ToString()
$VS_CODE_APP_ID = "aebc6443-996d-45c2-90f0-388ff96faa56"
$AZURE_CLI_APP_ID = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"

# Create MCP Resource App
Write-Host ""
Write-Host "Creating MCP Resource App: sherpa-mcp-client-camp2-$APP_SUFFIX"
$MCP_APP_CLIENT_ID = az ad app create `
    --display-name "sherpa-mcp-client-camp2-$APP_SUFFIX" `
    --sign-in-audience "AzureADMyOrg" `
    --query appId -o tsv

if (-not $MCP_APP_CLIENT_ID) {
    Write-Host "Failed to create MCP app"
    exit 1
}

Write-Host "MCP App Client ID: $MCP_APP_CLIENT_ID"

# IMPORTANT: Do NOT set identifier URI!
# When identifierUris is empty, scopes are referenced as {appId}/scope_name
# This is required for VS Code MCP OAuth to work correctly.
# Setting identifier-uris to api://{appId} would change scope format to api://{appId}/scope_name
# which breaks the token audience matching.
Write-Host "Skipping identifier URI (must be empty for VS Code MCP OAuth)..."

# Create API scope
Write-Host "Creating OAuth scope..."
$scopeJson = @{
    oauth2PermissionScopes = @(
        @{
            adminConsentDescription = "Allow the application to access MCP servers on behalf of the signed-in user"
            adminConsentDisplayName = "Access MCP servers"
            id = $SCOPE_ID
            isEnabled = $true
            type = "User"
            userConsentDescription = "Allow this application to access MCP servers on your behalf"
            userConsentDisplayName = "Access MCP servers"
            value = "user_impersonate"
        }
    )
} | ConvertTo-Json -Depth 5

$scopeFile = Join-Path $env:TEMP "mcp-api-scope.json"
$scopeJson | Set-Content -Path $scopeFile -Encoding UTF8

az ad app update --id $MCP_APP_CLIENT_ID --set api=@$scopeFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create API scope"
    Remove-Item -Path $scopeFile -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -Path $scopeFile -ErrorAction SilentlyContinue
Write-Host "API scope created"

# Wait for API update to propagate
Start-Sleep -Seconds 2

# Pre-authorize VS Code and Azure CLI with updated API config
Write-Host "Pre-authorizing VS Code and Azure CLI..."
$fullApiJson = @{
    acceptMappedClaims = $null
    knownClientApplications = @()
    oauth2PermissionScopes = @(
        @{
            adminConsentDescription = "Allow the application to access MCP servers on behalf of the signed-in user"
            adminConsentDisplayName = "Access MCP servers"
            id = $SCOPE_ID
            isEnabled = $true
            type = "User"
            userConsentDescription = "Allow this application to access MCP servers on your behalf"
            userConsentDisplayName = "Access MCP servers"
            value = "user_impersonate"
        }
    )
    preAuthorizedApplications = @(
        @{
            appId = $VS_CODE_APP_ID
            delegatedPermissionIds = @($SCOPE_ID)
        },
        @{
            appId = $AZURE_CLI_APP_ID
            delegatedPermissionIds = @($SCOPE_ID)
        }
    )
    requestedAccessTokenVersion = 2
} | ConvertTo-Json -Depth 5

$fullApiFile = Join-Path $env:TEMP "mcp-api-full.json"
$fullApiJson | Set-Content -Path $fullApiFile -Encoding UTF8

az ad app update --id $MCP_APP_CLIENT_ID --set api=@$fullApiFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to pre-authorize clients"
    Remove-Item -Path $fullApiFile -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -Path $fullApiFile -ErrorAction SilentlyContinue
Write-Host "VS Code and Azure CLI pre-authorized"

# NOTE: We do NOT add VS Code redirect URIs to our app!
# VS Code uses its OWN Entra app (managed by Microsoft) with its own redirect URIs.
# The pre-authorization above is what allows VS Code to request tokens for our API.
# This is a cross-app OAuth flow: VS Code (client) -> our API (resource).

# Create Service Principal
Write-Host "Creating service principal for MCP app..."
az ad sp create --id $MCP_APP_CLIENT_ID 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "Service principal already exists" }

# Create APIM Client App
Write-Host ""
Write-Host "Creating APIM Client App: sherpa-apim-client-camp2-$APP_SUFFIX"
$APIM_CLIENT_APP_ID = az ad app create `
    --display-name "sherpa-apim-client-camp2-$APP_SUFFIX" `
    --sign-in-audience "AzureADMyOrg" `
    --query appId -o tsv

if (-not $APIM_CLIENT_APP_ID) {
    Write-Host "Failed to create APIM client app"
    exit 1
}

Write-Host "APIM Client App ID: $APIM_CLIENT_APP_ID"

# Wait for app creation to propagate
Start-Sleep -Seconds 2

# Set identifier URI
Write-Host "Setting identifier URI for APIM app..."
az ad app update --id $APIM_CLIENT_APP_ID `
    --identifier-uris "api://$APIM_CLIENT_APP_ID"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set identifier URI"
    exit 1
}

# Wait for identifier URI to propagate
Start-Sleep -Seconds 2

# Create client secret for APIM app (30 days expiration for workshop)
Write-Host "Creating client secret for APIM app..."
$END_DATE = (Get-Date).AddDays(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$APIM_CLIENT_SECRET = az ad app credential reset `
    --id $APIM_CLIENT_APP_ID `
    --end-date $END_DATE `
    --query password -o tsv

if (-not $APIM_CLIENT_SECRET) {
    Write-Host "Failed to create client secret"
    exit 1
}

Write-Host "Client secret created (expires in 30 days)"

# Create Service Principal
Write-Host "Creating service principal for APIM app..."
az ad sp create --id $APIM_CLIENT_APP_ID 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "Service principal already exists" }

Write-Host ""
Write-Host "=========================================="
Write-Host "Entra ID Setup Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "MCP Resource App:"
Write-Host "  Client ID: $MCP_APP_CLIENT_ID"
Write-Host "  Identifier URI: api://$MCP_APP_CLIENT_ID"
Write-Host "  Pre-authorized: VS Code/GitHub Copilot"
Write-Host ""
Write-Host "APIM Client App:"
Write-Host "  Client ID: $APIM_CLIENT_APP_ID"
Write-Host "  Has client secret for Credential Manager"
Write-Host ""
Write-Host "Saving to azd environment..."
azd env set MCP_APP_CLIENT_ID $MCP_APP_CLIENT_ID
azd env set APIM_CLIENT_APP_ID $APIM_CLIENT_APP_ID
azd env set APIM_CLIENT_SECRET -- $APIM_CLIENT_SECRET

Write-Host "Values saved to azd environment"
