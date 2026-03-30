# Preprovision hook for Camp 4
# Creates Entra ID app registrations before infrastructure deployment
# OAuth is pre-configured so workshop can focus on monitoring and telemetry

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "=========================================="
Write-Host "Camp 4: Entra ID App Registration"
Write-Host "=========================================="
Write-Host ""

# ============================================
# Generate unique resource suffix
# ============================================
if (-not $env:RESOURCE_SUFFIX) {
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    $RESOURCE_SUFFIX = -join (1..5 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    Write-Host "Generated new resource suffix: $RESOURCE_SUFFIX"
    azd env set RESOURCE_SUFFIX "$RESOURCE_SUFFIX"
} else {
    $RESOURCE_SUFFIX = $env:RESOURCE_SUFFIX
    Write-Host "Using existing resource suffix: $RESOURCE_SUFFIX"
}

# ============================================
# Set resource group name
# ============================================
# Derive from env name if not already set in the azd environment.
# This prevents inheriting a stale AZURE_RESOURCE_GROUP shell variable
# from a different camp session.
$storedRG = azd env get-value AZURE_RESOURCE_GROUP 2>$null
if (-not $storedRG -or $storedRG -like "ERROR:*") {
    $defaultRG = "rg-$($env:AZURE_ENV_NAME)"
    Write-Host "Setting resource group: $defaultRG"
    azd env set AZURE_RESOURCE_GROUP "$defaultRG"
    $env:AZURE_RESOURCE_GROUP = $defaultRG
}

# Sync AZURE_LOCATION with resource group location if RG already exists
if ($env:AZURE_RESOURCE_GROUP) {
    $RG_LOCATION = az group show -n "$env:AZURE_RESOURCE_GROUP" --query location -o tsv 2>$null
    if ($RG_LOCATION -and $RG_LOCATION -ne $env:AZURE_LOCATION) {
        Write-Host "Syncing AZURE_LOCATION to resource group location: $RG_LOCATION"
        azd env set AZURE_LOCATION "$RG_LOCATION"
        $env:AZURE_LOCATION = $RG_LOCATION
    }
}

# Get tenant ID
$TENANT_ID = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $TENANT_ID"

# Unique name for apps
$envName = if ($env:AZURE_ENV_NAME) { $env:AZURE_ENV_NAME } else { "camp4" }
$timestamp = (Get-Date -UFormat %s).ToString()
$APP_SUFFIX = "$envName-$($timestamp.Substring($timestamp.Length - 4))"

# Generate UUIDs upfront
$SCOPE_ID = [guid]::NewGuid().ToString()
$VS_CODE_APP_ID = "aebc6443-996d-45c2-90f0-388ff96faa56"

# Create MCP Resource App
Write-Host ""
Write-Host "Creating MCP Resource App: sherpa-mcp-api-$APP_SUFFIX"
$MCP_APP_CLIENT_ID = az ad app create `
    --display-name "sherpa-mcp-api-$APP_SUFFIX" `
    --sign-in-audience "AzureADMyOrg" `
    --query appId -o tsv

if (-not $MCP_APP_CLIENT_ID) {
    Write-Host "Failed to create MCP app"
    exit 1
}

Write-Host "MCP App Client ID: $MCP_APP_CLIENT_ID"

# IMPORTANT: Do NOT set identifier URI!
Write-Host "Skipping identifier URI (must be empty for VS Code MCP OAuth)..."

# Create API scope with mcp.access
Write-Host "Creating OAuth scope (mcp.access)..."
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
            value = "mcp.access"
        }
    )
} | ConvertTo-Json -Depth 10

$scopeFile = Join-Path $env:TEMP "mcp-api-scope.json"
$scopeJson | Set-Content -Path $scopeFile -Encoding utf8

az ad app update --id "$MCP_APP_CLIENT_ID" --set "api=@$scopeFile"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create API scope"
    Remove-Item -Path $scopeFile -Force -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -Path $scopeFile -Force -ErrorAction SilentlyContinue
Write-Host "API scope created: mcp.access"

# Wait for API update to propagate
Start-Sleep -Seconds 2

# Pre-authorize VS Code and Azure CLI
Write-Host "Pre-authorizing VS Code and Azure CLI..."
$AZURE_CLI_APP_ID = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"

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
            value = "mcp.access"
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
} | ConvertTo-Json -Depth 10

$fullApiFile = Join-Path $env:TEMP "mcp-api-full.json"
$fullApiJson | Set-Content -Path $fullApiFile -Encoding utf8

az ad app update --id "$MCP_APP_CLIENT_ID" --set "api=@$fullApiFile"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to pre-authorize clients"
    Remove-Item -Path $fullApiFile -Force -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -Path $fullApiFile -Force -ErrorAction SilentlyContinue
Write-Host "VS Code and Azure CLI pre-authorized"

# Create Service Principal
Write-Host "Creating service principal for MCP app..."
az ad sp create --id "$MCP_APP_CLIENT_ID" 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "Service principal already exists" }

# Create APIM Client App for Credential Manager
Write-Host ""
Write-Host "Creating APIM Client App: sherpa-apim-client-$APP_SUFFIX"
$APIM_CLIENT_APP_ID = az ad app create `
    --display-name "sherpa-apim-client-$APP_SUFFIX" `
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
az ad app update --id "$APIM_CLIENT_APP_ID" --identifier-uris "api://$APIM_CLIENT_APP_ID"

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
    --id "$APIM_CLIENT_APP_ID" `
    --end-date "$END_DATE" `
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
Write-Host "  Scope: $MCP_APP_CLIENT_ID/mcp.access"
Write-Host "  Pre-authorized: VS Code, Azure CLI"
Write-Host ""
Write-Host "APIM Client App:"
Write-Host "  Client ID: $APIM_CLIENT_APP_ID"
Write-Host "  Has client secret for Credential Manager"
Write-Host ""
Write-Host "Saving to azd environment..."
azd env set MCP_APP_CLIENT_ID "$MCP_APP_CLIENT_ID"
azd env set APIM_CLIENT_APP_ID "$APIM_CLIENT_APP_ID"
azd env set APIM_CLIENT_SECRET -- "$APIM_CLIENT_SECRET"

Write-Host "Values saved to azd environment"
