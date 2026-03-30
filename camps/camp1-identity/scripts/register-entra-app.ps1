# Camp 1: Register Entra ID Application
$ErrorActionPreference = 'Stop'

Write-Host "🔐 Camp 1: Register Entra ID Application"
Write-Host "========================================"

$APP_NAME = "sherpa-mcp-camp1-$(Get-Date -UFormat %s)"
$DEVICE_CODE_REDIRECT_URI = "urn:ietf:wg:oauth:2.0:oob"

Write-Host "Creating Entra ID app registration: $APP_NAME"
Write-Host ""

# Create app registration
$APP_ID = az ad app create `
    --display-name $APP_NAME `
    --sign-in-audience "AzureADMyOrg" `
    --query appId -o tsv

if (-not $APP_ID) {
    Write-Host "❌ Failed to create app registration"
    exit 1
}

Write-Host "✅ App ID: $APP_ID"

# Set identifier URI
Write-Host "Setting identifier URI..."
az ad app update `
    --id $APP_ID `
    --identifier-uris "api://$APP_ID"

# Expose an API with a default scope
Write-Host "Exposing API scope..."
$SCOPE_ID = [guid]::NewGuid().ToString()
$AZURE_CLI_APP_ID = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
$VSCODE_CLIENT_ID = "aebc6443-996d-45c2-90f0-388ff96faa56"

# Step 1: Create the API scope first (without pre-authorized apps)
$scopeJson = @{
    oauth2PermissionScopes = @(
        @{
            adminConsentDescription = "Allow the application to access the MCP server on behalf of the signed-in user"
            adminConsentDisplayName = "Access MCP server"
            id = $SCOPE_ID
            isEnabled = $true
            type = "User"
            userConsentDescription = "Allow the application to access the MCP server on your behalf"
            userConsentDisplayName = "Access MCP server"
            value = "access_as_user"
        }
    )
} | ConvertTo-Json -Depth 5

$scopeFile = Join-Path $env:TEMP "api-scope.json"
$scopeJson | Set-Content -Path $scopeFile -Encoding UTF8

az ad app update `
    --id $APP_ID `
    --set api=@$scopeFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to configure API scope"
    Remove-Item -Path $scopeFile -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -Path $scopeFile -ErrorAction SilentlyContinue
Write-Host "✅ API scope created"

# Wait a moment for the API update to propagate
Start-Sleep -Seconds 2

# Step 2: Now add pre-authorized applications
Write-Host "Pre-authorizing clients (Azure CLI + VS Code)..."

# Create updated API config with pre-authorized apps
$updatedApiJson = @{
    acceptMappedClaims = $null
    knownClientApplications = @()
    oauth2PermissionScopes = @(
        @{
            adminConsentDescription = "Allow the application to access the MCP server on behalf of the signed-in user"
            adminConsentDisplayName = "Access MCP server"
            id = $SCOPE_ID
            isEnabled = $true
            type = "User"
            userConsentDescription = "Allow the application to access the MCP server on your behalf"
            userConsentDisplayName = "Access MCP server"
            value = "access_as_user"
        }
    )
    preAuthorizedApplications = @(
        @{
            appId = $AZURE_CLI_APP_ID
            delegatedPermissionIds = @($SCOPE_ID)
        },
        @{
            appId = $VSCODE_CLIENT_ID
            delegatedPermissionIds = @($SCOPE_ID)
        }
    )
    requestedAccessTokenVersion = 2
} | ConvertTo-Json -Depth 5

$updatedApiFile = Join-Path $env:TEMP "updated-api.json"
$updatedApiJson | Set-Content -Path $updatedApiFile -Encoding UTF8

az ad app update `
    --id $APP_ID `
    --set api=@$updatedApiFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to pre-authorize clients"
    Remove-Item -Path $updatedApiFile -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -Path $updatedApiFile -ErrorAction SilentlyContinue
Write-Host "✅ Clients pre-authorized"

# Add redirect URIs for device code flow, VS Code OAuth, and demo client
Write-Host "Configuring redirect URIs..."
az ad app update `
    --id $APP_ID `
    --public-client-redirect-uris $DEVICE_CODE_REDIRECT_URI `
    --web-redirect-uris "http://127.0.0.1:33418" "https://vscode.dev/redirect" "http://localhost:8090/callback"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to configure redirect URIs"
    exit 1
}

Write-Host "✅ Redirect URIs configured"
Write-Host "   Public client: device code flow"
Write-Host "   Web: VS Code OAuth, demo client (port 8090)"

# Set as confidential client (allows client secrets for demo)
# Note: isFallbackPublicClient=false means the app uses client secrets
# This is needed for the demo client with authorization code flow
Write-Host "Configuring client type (confidential for demo with secrets)..."
az ad app update `
    --id $APP_ID `
    --set isFallbackPublicClient=false

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to configure client type"
    exit 1
}

Write-Host "✅ Client type configured (confidential - supports client secrets)"

# Get tenant ID
$TENANT_ID = az account show --query tenantId -o tsv

if (-not $TENANT_ID) {
    Write-Host "❌ Failed to get tenant ID"
    exit 1
}

# Save to azd environment
Write-Host "Saving to azd environment..."
azd env set AZURE_CLIENT_ID $APP_ID
azd env set AZURE_TENANT_ID $TENANT_ID
Write-Host "✅ Environment variables saved"

Write-Host ""
Write-Host "✅ Entra ID Application Registered!"
Write-Host "===================================="
Write-Host "App Name: $APP_NAME"
Write-Host "Client ID: $APP_ID"
Write-Host "Tenant ID: $TENANT_ID"
Write-Host "Identifier URI: api://$APP_ID"
Write-Host ""
Write-Host "✅ Pre-authorized clients:"
Write-Host "   - Azure CLI (for Device Code Flow)"
Write-Host "   - VS Code (for PRM-based authentication)"
Write-Host ""
Write-Host "✅ Redirect URIs configured:"
Write-Host "   - urn:ietf:wg:oauth:2.0:oob (device code flow)"
Write-Host "   - http://127.0.0.1:33418 (VS Code)"
Write-Host "   - https://vscode.dev/redirect (VS Code)"
Write-Host "   - http://localhost:8090/callback (demo client)"
Write-Host ""
Write-Host "✅ Environment variables set:"
Write-Host "   AZURE_CLIENT_ID=$APP_ID"
Write-Host "   AZURE_TENANT_ID=$TENANT_ID"
Write-Host ""
Write-Host "💡 To enable the demo client with full OAuth flow:"
Write-Host "   Run: ./scripts/generate-client-secret.ps1"
