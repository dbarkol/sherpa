# Waypoint 2.1: Apply Content Safety
# Uses policy fragments for modular, reusable content safety checks
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 2.1: Apply Content Safety"
Write-Host "Using Policy Fragments"
Write-Host "=========================================="
Write-Host ""

$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_NAME = azd env get-value APIM_NAME
$APIM_URL = azd env get-value APIM_GATEWAY_URL
$TENANT_ID = az account show --query tenantId -o tsv
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID
$CONTENT_SAFETY_ENDPOINT = azd env get-value CONTENT_SAFETY_ENDPOINT
$MANAGED_IDENTITY_CLIENT_ID = azd env get-value MANAGED_IDENTITY_CLIENT_ID

Write-Host "Deploying:"
Write-Host "  - Named values for Content Safety"
Write-Host "  - Policy fragment: mcp-content-safety"
Write-Host "  - Updated API policies with include-fragment"
Write-Host ""

az deployment group create `
  --resource-group $RG `
  --template-file infra/waypoints/2.1-contentsafety.bicep `
  --parameters apimName=$APIM_NAME `
               tenantId=$TENANT_ID `
               mcpAppClientId=$MCP_APP_CLIENT_ID `
               apimGatewayUrl=$APIM_URL `
               contentSafetyEndpoint=$CONTENT_SAFETY_ENDPOINT `
               managedIdentityClientId=$MANAGED_IDENTITY_CLIENT_ID `
  --output none

Write-Host ""
Write-Host "=========================================="
Write-Host "Content Safety Applied (Fragment-based)"
Write-Host "=========================================="
Write-Host ""
Write-Host "Created:"
Write-Host "  - Named value: content-safety-endpoint"
Write-Host "  - Named value: managed-identity-client-id"
Write-Host "  - Fragment: mcp-content-safety"
Write-Host ""
Write-Host "Benefits:"
Write-Host "  - Reusable across multiple APIs"
Write-Host "  - Update fragment once, applies everywhere"
Write-Host "  - Cleaner, more maintainable policies"
Write-Host ""
