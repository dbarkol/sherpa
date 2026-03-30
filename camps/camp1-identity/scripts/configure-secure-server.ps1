# Camp 1: Configure Secure Server
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Camp 1: Configure Secure Server"
Write-Host "==================================="

# Load azd environment variables
Write-Host "📦 Loading azd environment..."
azd env get-values | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        $varName = $matches[1].Trim().Trim('"')
        $varValue = $matches[2].Trim().Trim('"')
        Set-Item -Path "env:$varName" -Value $varValue
    }
}

# Verify we have the necessary variables
if (-not $env:AZURE_CLIENT_ID) {
    Write-Host "❌ Error: AZURE_CLIENT_ID not found in azd environment."
    Write-Host "Make sure you've run 'azd env set AZURE_CLIENT_ID <your-client-id>' first."
    exit 1
}

if (-not $env:SECURE_SERVER_NAME) {
    Write-Host "❌ Error: SECURE_SERVER_NAME not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

Write-Host "Updating secure server: $env:SECURE_SERVER_NAME"
Write-Host "Setting AZURE_CLIENT_ID to: $env:AZURE_CLIENT_ID"
Write-Host ""

# Update the Container App with the correct client ID
az containerapp update `
    --name $env:SECURE_SERVER_NAME `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --set-env-vars AZURE_CLIENT_ID="$env:AZURE_CLIENT_ID" `
    --output none

Write-Host ""
Write-Host "✅ Secure server configured!"
Write-Host "The Container App now uses your Entra ID application client ID for JWT validation."
