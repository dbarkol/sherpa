# Waypoint 1.2: Deploy Trail API
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.2: Deploy Trail API"
Write-Host "=========================================="
Write-Host ""

# Deploy the container service
Write-Host "Building and deploying Trail API..."
azd deploy trail-api

# Get environment values
$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_NAME = azd env get-value APIM_NAME
$APIM_URL = azd env get-value APIM_GATEWAY_URL
$TRAIL_URL = azd env get-value TRAIL_API_URL

Write-Host ""
Write-Host "Configuring APIM backend and API with subscription key..."

# Build bicep to ARM JSON (workaround for CLI issues)
$tempTrailApi = Join-Path $env:TEMP "trail-api.json"
az bicep build --file infra/waypoints/1.2-deploy-trail.bicep --outfile $tempTrailApi 2>$null

# Deploy APIM configuration
$DEPLOYMENT_OUTPUT = az deployment group create `
  --resource-group $RG `
  --template-file $tempTrailApi `
  --parameters apimName=$APIM_NAME `
               backendUrl=$TRAIL_URL `
  --query "properties.outputs" -o json

# Extract and save subscription key (for Trail Services Product)
$outputObj = $DEPLOYMENT_OUTPUT | ConvertFrom-Json
$SUB_KEY = $outputObj.subscriptionKey.value
azd env set TRAIL_SUBSCRIPTION_KEY $SUB_KEY

Write-Host ""
Write-Host "Exporting Trail API as MCP server..."

# Build and deploy MCP export layer
$tempTrailMcp = Join-Path $env:TEMP "trail-mcp.json"
az bicep build --file infra/waypoints/1.2-deploy-trail-mcp.bicep --outfile $tempTrailMcp 2>$null

$MCP_OUTPUT = az deployment group create `
  --resource-group $RG `
  --template-file $tempTrailMcp `
  --parameters apimName=$APIM_NAME `
  --query "properties.outputs" -o json

$mcpObj = $MCP_OUTPUT | ConvertFrom-Json
$MCP_ENDPOINT = $mcpObj.mcpEndpoint.value

Write-Host ""
Write-Host "=========================================="
Write-Host "Trail API Deployed as MCP Server"
Write-Host "=========================================="
Write-Host ""
Write-Host "Trail Services Product:"
Write-Host "  Subscription Key: $($SUB_KEY.Substring(0,8))...$($SUB_KEY.Substring($SUB_KEY.Length - 4))"
Write-Host ""
Write-Host "REST Endpoint: $APIM_URL/trailapi/trails"
Write-Host "MCP Endpoint:  $MCP_ENDPOINT"
Write-Host ""
Write-Host "MCP Tools available:"
Write-Host "  - list_trails: List all available hiking trails"
Write-Host "  - get_trail: Get details for a specific trail"
Write-Host "  - check_conditions: Current trail conditions and hazards"
Write-Host "  - get_permit: Retrieve a trail permit"
Write-Host "  - request_permit: Request a new trail permit"
Write-Host ""
Write-Host "Current security: Subscription key only (no authentication!)"
Write-Host ""
