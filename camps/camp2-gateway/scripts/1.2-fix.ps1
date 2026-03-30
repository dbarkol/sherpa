# Waypoint 1.2: Fix - Add OAuth to Trail MCP Server
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.2: Add OAuth to Trail MCP"
Write-Host "=========================================="
Write-Host ""

$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_NAME = azd env get-value APIM_NAME
$APIM_URL = azd env get-value APIM_GATEWAY_URL
$TENANT_ID = az account show --query tenantId -o tsv
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID

Write-Host "Applying OAuth validation + PRM discovery..."
Write-Host "  Subscription key: Still required (tracking/billing)"
Write-Host "  OAuth token: Now also required (authentication)"
Write-Host ""

# Build bicep to ARM JSON (workaround for CLI issues)
$tempTrailOauth = Join-Path $env:TEMP "trail-oauth.json"
az bicep build --file infra/waypoints/1.2-oauth.bicep --outfile $tempTrailOauth 2>$null

az deployment group create `
  --resource-group $RG `
  --template-file $tempTrailOauth `
  --parameters apimName=$APIM_NAME `
               tenantId=$TENANT_ID `
               mcpAppClientId=$MCP_APP_CLIENT_ID `
               apimGatewayUrl=$APIM_URL `
  --output none

Write-Host ""
Write-Host "=========================================="
Write-Host "OAuth Added to Trail MCP Server"
Write-Host "=========================================="
Write-Host ""
Write-Host "PRM Discovery endpoint (RFC 9728):"
Write-Host "  $APIM_URL/.well-known/oauth-protected-resource/trails/mcp"
Write-Host ""
Write-Host "Security now requires BOTH:"
Write-Host "  - Subscription key (which application)"
Write-Host "  - OAuth token (which user)"
Write-Host ""
