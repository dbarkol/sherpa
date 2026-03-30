# Waypoint 1.2: Deploy Security Function
# Deploys the Azure Function with input_check and sanitize_output endpoints
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $ScriptDir "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.2: Deploy Security Function"
Write-Host "=========================================="
Write-Host ""

$FUNCTION_APP_NAME = azd env get-value FUNCTION_APP_NAME
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP
$FUNCTION_APP_URL = azd env get-value FUNCTION_APP_URL

Write-Host "Function App: $FUNCTION_APP_NAME"
Write-Host "Resource Group: $RG_NAME"
Write-Host ""

Write-Host "Deploying security function code..."
Write-Host ""

# Navigate to function directory
Set-Location security-function

# Deploy using Azure Functions Core Tools
Write-Host "Building and deploying function..."
func azure functionapp publish $FUNCTION_APP_NAME --python

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Deployment failed. Trying alternative method..."

    # Alternative: use az functionapp deployment
    Set-Location (Join-Path $ScriptDir "..")

    # Create a zip package
    Write-Host "Creating deployment package..."
    Set-Location security-function
    $zipPath = Join-Path (Split-Path -Parent (Get-Location)) "function-package.zip"
    Compress-Archive -Path .\* -DestinationPath $zipPath -Force
    Set-Location ..

    Write-Host "Deploying via zip deployment..."
    az functionapp deployment source config-zip `
        --name $FUNCTION_APP_NAME `
        --resource-group $RG_NAME `
        --src $zipPath

    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Verifying deployment..."

# Wait for function to warm up
Start-Sleep -Seconds 10

# Test health endpoint
Write-Host "Testing health endpoint..."
try {
    $HEALTH_RESPONSE = curl.exe -s "$FUNCTION_APP_URL/api/health" 2>$null
} catch {
    $HEALTH_RESPONSE = '{"error": "unavailable"}'
}
Write-Host "Health check: $HEALTH_RESPONSE"

if ($HEALTH_RESPONSE -match "healthy") {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "Function Deployed Successfully!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Function URL: $FUNCTION_APP_URL"
    Write-Host ""
    Write-Host "Available endpoints:"
    Write-Host "  - POST /api/input-check     - Validates input for injection patterns"
    Write-Host "  - POST /api/sanitize-output - Redacts PII and credentials"
    Write-Host "  - GET  /api/health          - Health check"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Warning: Health check didn't return expected response."
    Write-Host "The function may still be starting up. Wait a moment and try again."
}

Write-Host ""
Write-Host "Next: Enable I/O security in APIM"
Write-Host "  ./scripts/1.2-enable-io-security.ps1"
Write-Host ""
