# Test OAuth flow with PRM discovery
$ErrorActionPreference = 'Stop'

Write-Host "=========================================="
Write-Host "Testing OAuth Flow with PRM Discovery"
Write-Host "=========================================="

# Check required variables
if (-not $env:APIM_GATEWAY_URL) {
    Write-Host "Error: APIM_GATEWAY_URL must be set"
    exit 1
}

Write-Host "Step 1: Discover OAuth configuration via PRM..."
$PRM_URL = "$($env:APIM_GATEWAY_URL)/.well-known/oauth-protected-resource"
Write-Host "Fetching PRM metadata from: $PRM_URL"

curl.exe -v $PRM_URL

Write-Host ""
Write-Host ""
Write-Host "Step 2: Get authorization endpoint from discovery..."
$prmResponse = curl.exe -s $PRM_URL | ConvertFrom-Json
$AUTH_SERVER = $prmResponse.authorization_servers[0]
Write-Host "Authorization server: $AUTH_SERVER"

$OPENID_CONFIG_URL = "$AUTH_SERVER/.well-known/openid-configuration"
Write-Host "Fetching OpenID configuration from: $OPENID_CONFIG_URL"

$openidResponse = curl.exe -s $OPENID_CONFIG_URL | ConvertFrom-Json
$openidResponse | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host ""
Write-Host "=========================================="
Write-Host "OAuth Discovery Testing Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "To complete OAuth flow:"
Write-Host "1. Configure VS Code MCP settings with APIM gateway URL"
Write-Host "2. VS Code will discover OAuth endpoints via PRM"
Write-Host "3. VS Code will initiate OAuth flow automatically"
