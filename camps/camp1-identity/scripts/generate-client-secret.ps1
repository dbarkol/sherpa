# Generate Client Secret for Local Testing
# This script creates a client secret for the Entra ID app registration
# and saves it to .env for local demo client testing.

$ErrorActionPreference = 'Stop'

Write-Host "============================================"
Write-Host "Generate Client Secret for Demo Testing"
Write-Host "============================================"
Write-Host ""

# Get client ID from azd environment
$CLIENT_ID = azd env get-value AZURE_CLIENT_ID 2>$null

if (-not $CLIENT_ID) {
    Write-Host "❌ AZURE_CLIENT_ID not found in azd environment"
    Write-Host "   Run this from camps/camp1-identity after deploying with azd"
    exit 1
}

Write-Host "Client ID: $CLIENT_ID"
Write-Host ""

# Check if secret already exists in .env
$envFile = Join-Path "demo-client" ".env"
if (Test-Path $envFile) {
    Write-Host "⚠️  Found existing demo-client/.env file"
    $reply = Read-Host "   Overwrite? (y/N)"
    if ($reply -ne "y" -and $reply -ne "Y") {
        Write-Host "Cancelled"
        exit 0
    }
}

# Generate a new client secret (30 days to comply with org policies)
Write-Host "Generating client secret (30 day expiration)..."
$END_DATE = (Get-Date).AddDays(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$displayName = "Demo Client Local Testing $(Get-Date -Format 'yyyyMMdd-HHmmss')"
$SECRET_JSON = az ad app credential reset `
    --id $CLIENT_ID `
    --append `
    --display-name $displayName `
    --end-date $END_DATE `
    --only-show-errors `
    -o json

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to generate client secret"
    Write-Host $SECRET_JSON
    exit 1
}

$secretObj = $SECRET_JSON | ConvertFrom-Json
$CLIENT_SECRET = $secretObj.password
$EXPIRY = $secretObj.endDateTime

if (-not $CLIENT_SECRET -or $CLIENT_SECRET -eq "null") {
    Write-Host "❌ Failed to extract client secret from response"
    Write-Host $SECRET_JSON
    exit 1
}

# Create .env file
if (-not (Test-Path "demo-client")) {
    New-Item -ItemType Directory -Path "demo-client" | Out-Null
}

$envContent = @"
# Client Secret for Demo Testing
# Generated: $(Get-Date)
# Expires: $EXPIRY
#
# ⚠️  WARNING: Keep this file secure and DO NOT commit to git!
# This is for LOCAL TESTING ONLY.

CLIENT_SECRET=$CLIENT_SECRET
"@

$envContent | Set-Content -Path $envFile -Encoding UTF8

# Ensure .env is in .gitignore
$gitignoreFile = Join-Path "demo-client" ".gitignore"
if (-not (Test-Path $gitignoreFile)) {
    @(".env", "*.pyc", "__pycache__/") | Set-Content -Path $gitignoreFile -Encoding UTF8
} else {
    $gitignoreContent = Get-Content $gitignoreFile -Raw
    if ($gitignoreContent -notmatch '(?m)^\.env$') {
        Add-Content -Path $gitignoreFile -Value ".env"
    }
}

Write-Host ""
Write-Host "✅ Client secret generated and saved to demo-client/.env"
Write-Host ""
Write-Host "Security Notes:"
Write-Host "  • Secret expires: $EXPIRY"
Write-Host "  • For LOCAL TESTING ONLY"
Write-Host "  • .env file is git-ignored"
Write-Host "  • Never use client secrets in production public clients"
Write-Host ""
Write-Host "You can now run the demo client:"
Write-Host "  cd demo-client"
Write-Host "  uv run --project .. python mcp_prm_client.py ``"
Write-Host "    `"`${SECURE_SERVER_URL}`" ``"
Write-Host "    `"`${AZURE_CLIENT_ID}`""
Write-Host ""
Write-Host "Note: Demo uses port 8090 for OAuth callback to avoid conflicts"
Write-Host ""
