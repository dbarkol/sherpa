# Camp 1: Get MCP Token (Authorization Code + PKCE)
$ErrorActionPreference = 'Stop'

Write-Host "🎫 Camp 1: Get MCP Token (Authorization Code + PKCE)"
Write-Host "===================================================="

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

Write-Host ""

Write-Host "Client ID: $env:AZURE_CLIENT_ID"
Write-Host "Tenant ID: $env:AZURE_TENANT_ID"
Write-Host ""

# Generate PKCE code verifier (43-128 characters)
# Use 32 random bytes, base64url encode
$bytes = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$CODE_VERIFIER = [Convert]::ToBase64String($bytes) -replace '\+', '-' -replace '/', '_' -replace '='

# Save code verifier for token exchange later
$verifierFile = Join-Path $env:TEMP "pkce_code_verifier"
$CODE_VERIFIER | Set-Content -Path $verifierFile -NoNewline -Encoding UTF8

# Generate PKCE code challenge (base64url encoded SHA256 hash of verifier)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$challengeBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($CODE_VERIFIER))
$CODE_CHALLENGE = [Convert]::ToBase64String($challengeBytes) -replace '\+', '-' -replace '/', '_' -replace '='

Write-Host "Code verifier length: $($CODE_VERIFIER.Length)"
Write-Host "Code challenge length: $($CODE_CHALLENGE.Length)"
Write-Host "Code verifier saved to: $verifierFile"
Write-Host ""

$REDIRECT_URI = "http://localhost:8080/callback"
$SCOPE = "api://$env:AZURE_CLIENT_ID/access_as_user"
$AUTH_URL = "https://login.microsoftonline.com/$env:AZURE_TENANT_ID/oauth2/v2.0/authorize"

# Build authorization URL
$AUTH_REQUEST = "${AUTH_URL}?client_id=$env:AZURE_CLIENT_ID&response_type=code&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

Write-Host "🌐 Opening browser for authentication..."
Write-Host ""
Write-Host "Authorization URL:"
Write-Host $AUTH_REQUEST
Write-Host ""
Write-Host "📋 Steps to get your token:"
Write-Host "=========================================="
Write-Host ""
Write-Host "1. Browser will open for authentication"
Write-Host "2. After login, you'll be redirected to: http://localhost:8080/callback?code=..."
Write-Host "3. You'll see a '404 Not Found' - this is EXPECTED! (no callback server running)"
Write-Host "4. Copy the ENTIRE redirect URL from your browser's address bar"
Write-Host "5. Extract the 'code' parameter (the long string after 'code=' and before '&')"
Write-Host "6. Run the following commands to exchange code for token:"
Write-Host ""
Write-Host "-----------------------------------------------------------"
Write-Host "`$AUTH_CODE = 'PASTE_YOUR_CODE_HERE'"
Write-Host ""
Write-Host "`$CODE_VERIFIER = Get-Content '$verifierFile'"
Write-Host "`$RESPONSE = curl.exe -s -X POST https://login.microsoftonline.com/$env:AZURE_TENANT_ID/oauth2/v2.0/token ``"
Write-Host "  -d `"client_id=$env:AZURE_CLIENT_ID`" ``"
Write-Host "  -d 'grant_type=authorization_code' ``"
Write-Host "  -d `"code=`$AUTH_CODE`" ``"
Write-Host "  -d 'redirect_uri=$REDIRECT_URI' ``"
Write-Host "  -d `"code_verifier=`$CODE_VERIFIER`""
Write-Host ""
Write-Host "`$TOKEN = (`$RESPONSE | ConvertFrom-Json).access_token"
Write-Host "Write-Host `"Token: `$TOKEN`""
Write-Host "-----------------------------------------------------------"
Write-Host ""
Write-Host "7. The `$TOKEN variable is now set and ready to use in Step 5d!"
Write-Host ""
Write-Host "💡 TIP: The code is valid for only a few minutes - exchange it quickly!"
Write-Host ""

# Open browser
try {
    Start-Process $AUTH_REQUEST
} catch {
    Write-Host ""
    Write-Host "⚠️  Could not open browser automatically. Copy the URL above."
}
