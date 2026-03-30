# ==============================================================================
# Camp 3: Get MCP Token (Device Code Flow)
# ==============================================================================
# Gets an OAuth token for authenticating with the Trails MCP server through APIM.
# Use this token in the trails-mcp.http file or with curl commands.
# ==============================================================================

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $ScriptDir "..")

Write-Host "🎫 Camp 3: Get MCP Token (Device Code Flow)"
Write-Host "==========================================="

# Load azd environment variables
Write-Host "📦 Loading azd environment..."
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID 2>$null
$AZURE_TENANT_ID = azd env get-value AZURE_TENANT_ID 2>$null
$APIM_GATEWAY_URL = azd env get-value APIM_GATEWAY_URL 2>$null

# Check for required environment variables
if (-not $MCP_APP_CLIENT_ID) {
    Write-Host "❌ Error: MCP_APP_CLIENT_ID not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

if (-not $AZURE_TENANT_ID) {
    Write-Host "❌ Error: AZURE_TENANT_ID not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

Write-Host "MCP App Client ID: $MCP_APP_CLIENT_ID"
Write-Host "Tenant ID: $AZURE_TENANT_ID"
Write-Host "APIM Gateway: $APIM_GATEWAY_URL"
Write-Host ""
Write-Host "🔐 Acquiring access token..."
Write-Host "You may be prompted to authenticate in your browser."
Write-Host ""

# Get token for the MCP application
try {
    $TOKEN = az account get-access-token `
        --resource $MCP_APP_CLIENT_ID `
        --query accessToken -o tsv
} catch {
    $TOKEN = $null
}

if (-not $TOKEN -or $LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Failed to acquire token"
    Write-Host $TOKEN
    exit 1
}

Write-Host ""
Write-Host "✅ Token acquired successfully!"
Write-Host ""
Write-Host "Your access token:"
Write-Host ""
Write-Host $TOKEN
Write-Host ""
Write-Host "💡 Tip: Decode this token at https://jwt.ms to see the claims inside (aud, iss, exp, scp, etc.)"
Write-Host ""
Write-Host "⚠️  Note: Tokens expire after ~1 hour. Run this script again to get a fresh token."
Write-Host ""
