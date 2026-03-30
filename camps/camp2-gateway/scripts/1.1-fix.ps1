# Waypoint 1.1: Fix - Apply OAuth Authentication
#
# This script configures OAuth protection for the Sherpa MCP API:
# 1. Adds Entra ID token validation
# 2. Creates RFC 9728 Protected Resource Metadata (PRM) endpoints
# 3. Removes subscription key requirement
#
# Key learnings:
# - VS Code discovers PRM via suffix path: /{api-path}/.well-known/oauth-protected-resource
# - PRM must return BEFORE OAuth validation (uses <return-response> before <base />)
# - 401 responses must include resource_metadata in both header AND body
# - APIM native MCP type auto-prepends API path to resource_metadata in WWW-Authenticate header
# - Entra app must have empty identifierUris for VS Code MCP OAuth to work

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.1: Apply OAuth Authentication"
Write-Host "=========================================="
Write-Host ""

$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_NAME = azd env get-value APIM_NAME
$APIM_URL = azd env get-value APIM_GATEWAY_URL
$TENANT_ID = az account show --query tenantId -o tsv
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID

Write-Host "Applying OAuth configuration..."
Write-Host "  Tenant ID: $TENANT_ID"
Write-Host "  MCP App: $MCP_APP_CLIENT_ID"
Write-Host ""

az deployment group create `
  --resource-group $RG `
  --template-file infra/waypoints/1.1-oauth.bicep `
  --parameters apimName=$APIM_NAME `
               tenantId=$TENANT_ID `
               mcpAppClientId=$MCP_APP_CLIENT_ID `
               apimGatewayUrl=$APIM_URL `
  --output none

Write-Host ""
Write-Host "=========================================="
Write-Host "OAuth Authentication Applied"
Write-Host "=========================================="
Write-Host ""
Write-Host "Changes made:"
Write-Host "  - Added validate-azure-ad-token policy"
Write-Host "  - Created PRM metadata endpoints (RFC 9728)"
Write-Host "  - Removed subscription key requirement"
Write-Host ""
Write-Host "PRM Endpoints (both work for discovery):"
Write-Host "  RFC 9728: $APIM_URL/.well-known/oauth-protected-resource/sherpa/mcp"
Write-Host "  Suffix:   $APIM_URL/sherpa/mcp/.well-known/oauth-protected-resource"
Write-Host ""
Write-Host "Next: Validate the fix"
Write-Host "  ./scripts/1.1-validate.ps1"
Write-Host ""
