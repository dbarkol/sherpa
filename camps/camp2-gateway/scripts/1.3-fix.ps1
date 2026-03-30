# Waypoint 1.3: Fix - Apply Rate Limiting
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.3: Apply Rate Limiting"
Write-Host "=========================================="
Write-Host ""

$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_NAME = azd env get-value APIM_NAME

Write-Host "Applying rate limiting to Trail API..."
Write-Host "  Rate: 10 requests per minute per subscription key"
Write-Host ""

az deployment group create `
  --resource-group $RG `
  --template-file infra/waypoints/1.3-ratelimit.bicep `
  --parameters apimName=$APIM_NAME `
  --output none

Write-Host ""
Write-Host "=========================================="
Write-Host "Rate Limiting Applied"
Write-Host "=========================================="
Write-Host ""
Write-Host "Changes made:"
Write-Host "  ✅ Added rate-limit-by-key policy to Trail API"
Write-Host "  ✅ Limited to 10 requests/minute per subscription key"
Write-Host "  ✅ Returns 429 when quota exceeded"
Write-Host ""
Write-Host "Next: Validate rate limiting works"
Write-Host "  ./scripts/1.3-validate.ps1"
Write-Host ""
