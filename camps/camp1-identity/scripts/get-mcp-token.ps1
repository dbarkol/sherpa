# Camp 1: Get MCP Token (Device Code Flow)
$ErrorActionPreference = 'Stop'

Write-Host "🎫 Camp 1: Get MCP Token (Device Code Flow)"
Write-Host "==========================================="

# Load azd environment variables
Write-Host "📦 Loading azd environment..."
azd env get-values | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        $varName = $matches[1].Trim().Trim('"')
        $varValue = $matches[2].Trim().Trim('"')
        Set-Item -Path "env:$varName" -Value $varValue
    }
}

# Check for required environment variables
if (-not $env:AZURE_CLIENT_ID) {
    Write-Host "❌ Error: AZURE_CLIENT_ID not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

if (-not $env:AZURE_TENANT_ID) {
    Write-Host "❌ Error: AZURE_TENANT_ID not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

Write-Host "Client ID: $env:AZURE_CLIENT_ID"
Write-Host "Tenant ID: $env:AZURE_TENANT_ID"
Write-Host ""
Write-Host "🔐 Acquiring access token..."
Write-Host "You may be prompted to authenticate in your browser."
Write-Host ""

# Get token for the Entra ID application
# The scope "api://{CLIENT_ID}/access_as_user" requests delegated permissions
try {
    $TOKEN = az account get-access-token `
        --resource "api://$env:AZURE_CLIENT_ID" `
        --scope "api://$env:AZURE_CLIENT_ID/access_as_user" `
        --query accessToken -o tsv 2>&1
} catch {
    $TOKEN = $null
}

if ($LASTEXITCODE -ne 0 -or -not $TOKEN) {
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
