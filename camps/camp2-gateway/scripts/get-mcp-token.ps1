# Camp 2: Get MCP Token for APIM
param(
    [switch]$Pkce,
    [switch]$Json,
    [switch]$Export,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "Usage: ./get-mcp-token.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Pkce    Use PKCE flow (interactive browser login)"
    Write-Host "  -Json    Output full token response as JSON"
    Write-Host "  -Export  Output as `$env:MCP_TOKEN assignment for PowerShell"
    Write-Host "  -Help    Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  ./get-mcp-token.ps1                # Get token using client credentials"
    Write-Host "  ./get-mcp-token.ps1 -Pkce           # Get token using PKCE (user login)"
    Write-Host "  ./get-mcp-token.ps1 -Export          # Output: `$env:MCP_TOKEN=..."
    Write-Host "  Invoke-Expression (./get-mcp-token.ps1 -Export)  # Set MCP_TOKEN in current shell"
    exit 0
}

Write-Host "🎫 Camp 2: Get MCP Token for APIM"
Write-Host "================================="
Write-Host ""

# Load azd environment variables
$CAMP_DIR = Join-Path $PSScriptRoot ".."

Write-Host "📦 Loading azd environment..."
Push-Location $CAMP_DIR
try {
    $envValues = azd env get-values
    foreach ($line in $envValues) {
        if ($line -match '^([^=]+)="?([^"]*)"?$') {
            Set-Variable -Name $Matches[1] -Value $Matches[2] -Scope Local
        }
    }
} finally {
    Pop-Location
}

# Check for required environment variables
if (-not $MCP_APP_CLIENT_ID) {
    Write-Host "❌ Error: MCP_APP_CLIENT_ID not found in environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

if (-not $APIM_CLIENT_APP_ID) {
    Write-Host "❌ Error: APIM_CLIENT_APP_ID not found in environment."
    exit 1
}

if (-not $APIM_CLIENT_SECRET) {
    Write-Host "❌ Error: APIM_CLIENT_SECRET not found in environment."
    exit 1
}

$TENANT_ID = az account show --query tenantId -o tsv

Write-Host "MCP App Client ID:  $MCP_APP_CLIENT_ID"
Write-Host "APIM Client App ID: $APIM_CLIENT_APP_ID"
Write-Host "Tenant ID:          $TENANT_ID"
Write-Host ""

$FLOW = if ($Pkce) { "pkce" } else { "client_credentials" }
$OUTPUT = if ($Json) { "json" } elseif ($Export) { "export" } else { "token" }

$TOKEN = $null
$RESPONSE = $null

if ($FLOW -eq "client_credentials") {
    Write-Host "🔐 Acquiring token using client credentials flow..."
    Write-Host ""

    $body = @{
        client_id     = $APIM_CLIENT_APP_ID
        client_secret = $APIM_CLIENT_SECRET
        scope         = "$MCP_APP_CLIENT_ID/.default"
        grant_type    = "client_credentials"
    }

    $RESPONSE = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $body

    $TOKEN = $RESPONSE.access_token

    if (-not $TOKEN) {
        Write-Host "❌ Failed to acquire token"
        Write-Host ($RESPONSE | ConvertTo-Json -Depth 5)
        exit 1
    }

} elseif ($FLOW -eq "pkce") {
    Write-Host "🔐 Acquiring token using PKCE flow (interactive)..."
    Write-Host "You will be prompted to authenticate in your browser."
    Write-Host ""

    # Try using az login with the scope
    $TOKEN = az account get-access-token `
        --resource $MCP_APP_CLIENT_ID `
        --query accessToken -o tsv 2>&1

    if ($LASTEXITCODE -ne 0 -or -not $TOKEN) {
        Write-Host ""
        Write-Host "⚠️  Interactive login required. Run:"
        Write-Host ""
        Write-Host "  az login --scope $MCP_APP_CLIENT_ID/.default"
        Write-Host ""
        Write-Host "Then run this script again."
        exit 1
    }
}

# Output based on format
switch ($OUTPUT) {
    "json" {
        $RESPONSE | ConvertTo-Json -Depth 5
    }
    "export" {
        Write-Output "`$env:MCP_TOKEN=`"$TOKEN`""
    }
    "token" {
        Write-Host "✅ Token acquired successfully!"
        Write-Host ""
        Write-Host "Your access token:"
        Write-Host ""
        Write-Host $TOKEN
        Write-Host ""
        Write-Host "💡 Usage with MCP Inspector:"
        Write-Host ""
        Write-Host "  npx @modelcontextprotocol/inspector --transport http ``"
        Write-Host "    --server-url `"https://`${APIM_NAME}.azure-api.net/sherpa/mcp`" ``"
        Write-Host "    --header `"Authorization: Bearer `${TOKEN}`""
        Write-Host ""
        Write-Host "💡 Usage with curl:"
        Write-Host ""
        Write-Host "  curl.exe -X POST `"https://`${APIM_NAME}.azure-api.net/sherpa/mcp`" ``"
        Write-Host "    -H `"Authorization: Bearer `${TOKEN}`" ``"
        Write-Host "    -H `"Content-Type: application/json`" ``"
        Write-Host "    -H `"Accept: application/json, text/event-stream`" ``"
        Write-Host "    -d '{`"jsonrpc`":`"2.0`",`"method`":`"initialize`",...}'"
        Write-Host ""
        Write-Host "💡 Decode token at: https://jwt.ms"
        Write-Host ""
        Write-Host "⚠️  Tokens expire after ~1 hour. Run this script again to get a fresh token."
    }
}
