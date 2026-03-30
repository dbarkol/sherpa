# Postprovision hook for Camp 4
# Called automatically by azd after infrastructure deployment

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..\..") 

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
$CONTENT_SAFETY_ENDPOINT = azd env get-value CONTENT_SAFETY_ENDPOINT
$CONTENT_SAFETY_LOCATION = azd env get-value CONTENT_SAFETY_LOCATION
$FUNCTION_APP_NAME = azd env get-value FUNCTION_APP_NAME
$FUNCTION_APP_URL = azd env get-value FUNCTION_APP_URL
$FUNCTION_APP_V1_URL = azd env get-value FUNCTION_APP_V1_URL
$FUNCTION_APP_V2_URL = azd env get-value FUNCTION_APP_V2_URL

# Check deploy mode - "complete" deploys the fully-configured stack
$DEPLOY_MODE = azd env get-value DEPLOY_MODE 2>$null
if (-not $DEPLOY_MODE) { $DEPLOY_MODE = "" }

# In complete mode, APIM routes to v2 (structured logging) from the start
if ($DEPLOY_MODE -eq "complete") {
    $ACTIVE_FUNCTION_URL = $FUNCTION_APP_V2_URL
    $ACTIVE_LABEL = "v2 (structured logging)"
} else {
    $ACTIVE_FUNCTION_URL = $FUNCTION_APP_V1_URL
    $ACTIVE_LABEL = "v1 (basic logging)"
}
$SHERPA_SERVER_URL = azd env get-value SHERPA_SERVER_URL
$TRAIL_API_URL = azd env get-value TRAIL_API_URL

# Show region adjustments if any
if ($APIM_LOCATION -ne $LOCATION -or $CONTENT_SAFETY_LOCATION -ne $LOCATION) {
    Write-Host ""
    Write-Host "Region adjustments made for service availability:"
    if ($APIM_LOCATION -ne $LOCATION) { Write-Host "  API Management: $LOCATION -> $APIM_LOCATION" }
    if ($CONTENT_SAFETY_LOCATION -ne $LOCATION) { Write-Host "  Content Safety: $LOCATION -> $CONTENT_SAFETY_LOCATION" }
}

# Load Entra ID app IDs from environment
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID
$TENANT_ID = azd env get-value AZURE_TENANT_ID 2>$null
if (-not $TENANT_ID) { $TENANT_ID = az account show --query tenantId -o tsv }

Write-Host ""
Write-Host "Configuration:"
Write-Host "  Resource Group: $RG_NAME"
Write-Host "  ACR: $ACR_NAME"
Write-Host "  APIM: $APIM_NAME"
Write-Host "  Gateway URL: $APIM_GATEWAY_URL"
Write-Host "  Function v1: $FUNCTION_APP_V1_URL (basic logging)"
Write-Host "  Function v2: $FUNCTION_APP_V2_URL (structured logging)"
Write-Host "  Active:      $ACTIVE_LABEL"
Write-Host "  Function URL: $FUNCTION_APP_URL"
Write-Host "  Sherpa Server: $SHERPA_SERVER_URL"
Write-Host "  Trail API: $TRAIL_API_URL"
Write-Host "  Tenant ID: $TENANT_ID"
Write-Host "  MCP App Client ID: $MCP_APP_CLIENT_ID"
Write-Host ""

# Configure APIM APIs and backends with full I/O security (Layer 1 + 2)
Write-Host "Configuring APIM APIs with full security..."
az deployment group create `
    --resource-group "$RG_NAME" `
    --template-file infra/waypoints/initial-api-setup.bicep `
    --parameters `
        apimName="$APIM_NAME" `
        sherpaServerUrl="$SHERPA_SERVER_URL" `
        trailApiUrl="$TRAIL_API_URL" `
        contentSafetyEndpoint="$CONTENT_SAFETY_ENDPOINT" `
        tenantId="$TENANT_ID" `
        mcpAppClientId="$MCP_APP_CLIENT_ID" `
        functionAppUrl="$ACTIVE_FUNCTION_URL" `
        functionAppV1Url="$FUNCTION_APP_V1_URL" `
        functionAppV2Url="$FUNCTION_APP_V2_URL" `
    --output none

Write-Host "APIM APIs configured with Layer 1 + Layer 2 security"

# Update Entra ID redirect URI with actual APIM gateway URL
if ($MCP_APP_CLIENT_ID -and $APIM_GATEWAY_URL) {
    Write-Host "Updating Entra ID redirect URI..."
    try {
        az ad app update --id "$MCP_APP_CLIENT_ID" `
            --web-redirect-uris "$APIM_GATEWAY_URL/auth/callback" 2>$null
    } catch {
        Write-Host "Note: Could not update redirect URI. You may need to update it manually."
    }
}

Write-Host ""
Write-Host "========================================="
Write-Host "Post-provision Complete"
Write-Host "========================================="
Write-Host ""
Write-Host "Infrastructure deployed successfully!"
Write-Host ""
Write-Host "Camp 4: Monitoring & Telemetry"
Write-Host "=============================="
Write-Host ""

if ($DEPLOY_MODE -eq "complete") {
    Write-Host "Deploy Mode: COMPLETE"
    Write-Host "  All monitoring resources are deployed and configured."
    Write-Host ""
    Write-Host "What's deployed:"
    Write-Host "  - APIM with full I/O security (Layer 1 + Layer 2)"
    Write-Host "  - Sherpa MCP Server (Container App)"
    Write-Host "  - Trail API with PII endpoint (Container App)"
    Write-Host "  - Security Function v2 (structured logging - ACTIVE)"
    Write-Host "  - Log Analytics workspace with APIM diagnostic logs"
    Write-Host "  - Application Insights (shared telemetry)"
    Write-Host "  - Security Monitoring Workbook (dashboard)"
    Write-Host "  - Action Group + Alert Rules (4 security alerts)"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host ""
    Write-Host "  1. Generate sample attack data:"
    Write-Host "     ./scripts/section4/4.1-simulate-attack.ps1"
    Write-Host ""
    Write-Host "  2. View the security dashboard in the Azure Portal:"
    Write-Host "     Open the Workbook under your resource group"
    Write-Host ""
} else {
    Write-Host "Deploy Mode: WORKSHOP (default)"
    Write-Host ""
    Write-Host "What's deployed:"
    Write-Host "  - APIM with full I/O security (Layer 1 + Layer 2)"
    Write-Host "  - Sherpa MCP Server (Container App)"
    Write-Host "  - Trail API with PII endpoint (Container App)"
    Write-Host "  - Security Function v1 (basic logging - ACTIVE)"
    Write-Host "  - Security Function v2 (structured logging - deployed, not active)"
    Write-Host "  - Log Analytics workspace (not yet connected to APIM)"
    Write-Host ""
    Write-Host "Security layers enabled:"
    Write-Host "  - Layer 1: OAuth + Content Safety (on MCP APIs)"
    Write-Host "  - Layer 2: Security Function v1 (input validation + output sanitization)"
    Write-Host ""
    Write-Host "The monitoring gap:"
    Write-Host "  - APIM diagnostic settings are NOT configured"
    Write-Host "  - Security Function v1 uses basic logging (can't be queried)"
    Write-Host "  - Security events are happening but NOT visible"
    Write-Host ""
    Write-Host "Workshop flow:"
    Write-Host "  Section 1: Enable APIM diagnostics (gateway logs)"
    Write-Host "  Section 2: Switch to Function v2 (structured application logs)"
    Write-Host "  Section 3: Create dashboard (visualize)"
    Write-Host "  Section 4: Set up alerts (actionable)"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host ""
    Write-Host "  1. Demonstrate the monitoring gap:"
    Write-Host "     ./scripts/section1/1.1-exploit.ps1"
    Write-Host ""
    Write-Host "  2. Enable APIM diagnostics:"
    Write-Host "     ./scripts/section1/1.2-fix.ps1"
    Write-Host ""
    Write-Host "  3. Validate logging is working:"
    Write-Host "     ./scripts/section1/1.3-validate.ps1"
    Write-Host ""
}
