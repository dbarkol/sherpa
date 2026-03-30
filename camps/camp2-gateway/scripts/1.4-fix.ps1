# Waypoint 1.4: Register APIs in API Center
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.4: API Center Registration"
Write-Host "=========================================="
Write-Host ""

$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_URL = azd env get-value APIM_GATEWAY_URL
$API_CENTER_NAME = azd env get-value API_CENTER_NAME

Write-Host "Registering MCP servers in API Center..."
Write-Host "  API Center: $API_CENTER_NAME"
Write-Host ""

az deployment group create `
  --resource-group $RG `
  --template-file infra/waypoints/1.4-apicenter.bicep `
  --parameters apiCenterName=$API_CENTER_NAME `
               apimGatewayUrl=$APIM_URL `
  --output none

Write-Host ""
Write-Host "=========================================="
Write-Host "API Center Registration Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "Registered MCP Servers:"
Write-Host "  - Sherpa MCP Server (/sherpa/mcp)"
Write-Host "  - Trails MCP Server (/trails/mcp)"
Write-Host ""
Write-Host "Benefits:"
Write-Host "  - Central MCP server discovery"
Write-Host "  - Prevents shadow MCP servers"
Write-Host "  - Enables governance & compliance"
Write-Host ""
Write-Host "View in Azure Portal:"
Write-Host "  https://portal.azure.com/#@/resource/subscriptions/.../resourceGroups/$RG/providers/Microsoft.ApiCenter/services/$API_CENTER_NAME"
Write-Host ""
Write-Host "=========================================="
Write-Host " Section 1 Complete: Gateway & Governance"
Write-Host "=========================================="
Write-Host ""
Write-Host "Next: Content Safety protection"
Write-Host ""
