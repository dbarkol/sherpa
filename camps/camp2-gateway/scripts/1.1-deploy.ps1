# Waypoint 1.1: Deploy Sherpa MCP Server
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.1: Deploy Sherpa MCP Server"
Write-Host "=========================================="
Write-Host ""

# Deploy the container service
Write-Host "Building and deploying Sherpa MCP Server..."
azd deploy sherpa-mcp-server

# Get environment values
$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_NAME = azd env get-value APIM_NAME
$SHERPA_URL = azd env get-value SHERPA_SERVER_URL

Write-Host ""
Write-Host "Configuring APIM backend and API..."

# Deploy APIM configuration via Bicep
az deployment group create `
  --resource-group $RG `
  --template-file infra/waypoints/1.1-deploy-sherpa.bicep `
  --parameters apimName=$APIM_NAME `
               backendUrl="$SHERPA_URL/mcp" `
  --output none

$APIM_URL = azd env get-value APIM_GATEWAY_URL

Write-Host ""
Write-Host "=========================================="
Write-Host "Sherpa MCP Server Deployed"
Write-Host "=========================================="
Write-Host ""
Write-Host "Endpoint: $APIM_URL/sherpa/mcp"
Write-Host ""
Write-Host "Current security: NONE (completely open)"
Write-Host ""
Write-Host "Next: Test the vulnerability from VS Code"
Write-Host "  1. Add the endpoint to .vscode/mcp.json"
Write-Host "  2. Connect without any authentication"
Write-Host "  3. Then run: ./scripts/1.1-fix.ps1"
Write-Host ""
