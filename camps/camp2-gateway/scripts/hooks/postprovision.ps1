# Postprovision hook for Camp 2
# Called automatically by azd after infrastructure deployment

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "=========================================="
Write-Host "Post-provision Configuration"
Write-Host "=========================================="
Write-Host ""

# Get deployment outputs from azd
Write-Host "Loading deployment outputs..."
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP
$LOCATION = azd env get-value AZURE_LOCATION
$ACR_NAME = azd env get-value AZURE_CONTAINER_REGISTRY_NAME
$APIM_NAME = azd env get-value APIM_NAME
$APIM_GATEWAY_URL = azd env get-value APIM_GATEWAY_URL
$APIM_LOCATION = azd env get-value APIM_LOCATION
$API_CENTER_NAME = azd env get-value API_CENTER_NAME
$API_CENTER_LOCATION = azd env get-value API_CENTER_LOCATION
$CONTENT_SAFETY_LOCATION = azd env get-value CONTENT_SAFETY_LOCATION

# Show region adjustments if any
if ($APIM_LOCATION -ne $LOCATION -or $API_CENTER_LOCATION -ne $LOCATION -or $CONTENT_SAFETY_LOCATION -ne $LOCATION) {
    Write-Host ""
    Write-Host "Region adjustments made for service availability:"
    if ($APIM_LOCATION -ne $LOCATION) { Write-Host "  API Management: $LOCATION -> $APIM_LOCATION" }
    if ($API_CENTER_LOCATION -ne $LOCATION) { Write-Host "  API Center: $LOCATION -> $API_CENTER_LOCATION" }
    if ($CONTENT_SAFETY_LOCATION -ne $LOCATION) { Write-Host "  Content Safety: $LOCATION -> $CONTENT_SAFETY_LOCATION" }
}

Write-Host ""
Write-Host "Configuration:"
Write-Host "  Resource Group: $RG_NAME"
Write-Host "  ACR: $ACR_NAME"
Write-Host "  APIM: $APIM_NAME"
Write-Host "  Gateway URL: $APIM_GATEWAY_URL"
Write-Host ""

Write-Host "=========================================="
Write-Host "Post-provision Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "Infrastructure deployed successfully!"
Write-Host ""
Write-Host "APIM Gateway URL: $APIM_GATEWAY_URL"
Write-Host ""
Write-Host "Next steps:"
Write-Host ""
Write-Host "  1. Deploy Sherpa MCP Server:"
Write-Host "     ./scripts/1.1-deploy.ps1"
Write-Host ""
Write-Host "  2. Follow the waypoint scripts to:"
Write-Host "     - See vulnerabilities (exploit scripts)"
Write-Host "     - Apply fixes (fix scripts)"
Write-Host "     - Validate security (validate scripts)"
Write-Host ""
