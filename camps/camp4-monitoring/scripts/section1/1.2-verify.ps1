# =============================================================================
# Camp 4 - Section 1.2: Verify APIM Diagnostic Configuration
# =============================================================================
# This script verifies that APIM diagnostic settings are properly configured.
# Diagnostic settings are deployed via Bicep infrastructure, not manually.
# =============================================================================

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..\..")

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Camp 4 - Section 1.2: Verify APIM Diagnostics" -ForegroundColor Cyan
Write-Host "  Understanding diagnostic settings configuration" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Load environment
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP 2>$null
$APIM_NAME = azd env get-value APIM_NAME 2>$null
$WORKSPACE_ID = azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>$null
$WORKSPACE_NAME = azd env get-value LOG_ANALYTICS_WORKSPACE_NAME 2>$null

if (-not $APIM_NAME -or -not $WORKSPACE_ID) {
    Write-Host "Error: Missing required environment values. Run 'azd up' first." -ForegroundColor Red
    exit 1
}

# Get the full resource ID for APIM
$APIM_RESOURCE_ID = az apim show `
    --name "$APIM_NAME" `
    --resource-group "$RG_NAME" `
    --query id -o tsv

Write-Host "Checking APIM diagnostic settings..." -ForegroundColor Blue
Write-Host ""

# Get diagnostic settings details
$DIAG_JSON = $null
try {
    $DIAG_JSON = az monitor diagnostic-settings list `
        --resource "$APIM_RESOURCE_ID" `
        -o json 2>$null | ConvertFrom-Json
} catch { $DIAG_JSON = @() }

if (-not $DIAG_JSON) { $DIAG_JSON = @() }
$DIAG_COUNT = @($DIAG_JSON).Count

if ($DIAG_COUNT -eq 0) {
    Write-Host "✗ No diagnostic settings found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  This is unexpected - diagnostic settings should be deployed via Bicep."
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. Bicep deployment didn't complete successfully"
    Write-Host "  2. Diagnostic settings were manually deleted"
    Write-Host "  3. Using an older version of the workshop that doesn't pre-configure diagnostics"
    Write-Host ""
    Write-Host "To fix:" -ForegroundColor Yellow
    Write-Host "  Run 'azd up' to redeploy infrastructure"
    Write-Host ""
    exit 1
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Diagnostic Settings Configuration" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Parse and display each diagnostic setting
foreach ($setting in $DIAG_JSON) {
    Write-Host "Setting: $($setting.name)" -ForegroundColor Green
}
Write-Host ""

# Get the first diagnostic setting details
$firstSetting = $DIAG_JSON[0]
$SETTING_NAME = $firstSetting.name
$DEST_TYPE = if ($firstSetting.logAnalyticsDestinationType) { $firstSetting.logAnalyticsDestinationType } else { "AzureDiagnostics" }
$WORKSPACE = ($firstSetting.workspaceId -split "/")[-1]
$ENABLED_LOGS = @($firstSetting.logs | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.category })
$ENABLED_METRICS = @($firstSetting.metrics | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.category })

Write-Host "Destination Type: $DEST_TYPE" -ForegroundColor Yellow
if ($DEST_TYPE -eq "Dedicated") {
    Write-Host "  ✓ Using resource-specific tables (recommended)" -ForegroundColor Green
    Write-Host "    Logs go to: ApiManagementGatewayLogs, ApiManagementGatewayLlmLog"
} else {
    Write-Host "  ⚠ Using legacy AzureDiagnostics table" -ForegroundColor Yellow
    Write-Host "    Consider migrating to Dedicated mode for better query performance"
}
Write-Host ""

Write-Host "Log Analytics Workspace: $WORKSPACE" -ForegroundColor Yellow
Write-Host ""

Write-Host "Enabled Log Categories:" -ForegroundColor Yellow
foreach ($cat in $ENABLED_LOGS) {
    if ($cat) { Write-Host "  ✓ $cat" -ForegroundColor Green }
}
Write-Host ""

Write-Host "Enabled Metrics:" -ForegroundColor Yellow
foreach ($met in $ENABLED_METRICS) {
    if ($met) { Write-Host "  ✓ $met" -ForegroundColor Green }
}
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  APIM Internal Diagnostics" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking APIM azuremonitor logger..." -ForegroundColor Blue
$LOGGER_EXISTS = $null
try {
    $LOGGER_EXISTS = az rest --method GET `
        --uri "${APIM_RESOURCE_ID}/loggers/azuremonitor?api-version=2022-08-01" `
        --query "properties.loggerType" -o tsv 2>$null
} catch { }

if ($LOGGER_EXISTS -eq "azureMonitor") {
    Write-Host "  ✓ azuremonitor logger configured" -ForegroundColor Green
} else {
    Write-Host "  ⚠ azuremonitor logger not found (may affect log flow)" -ForegroundColor Yellow
}

Write-Host "Checking APIM azuremonitor diagnostic..." -ForegroundColor Blue
$DIAG_SAMPLING = $null
$DIAG_CLIENT_IP = $null
try {
    $DIAG_SAMPLING = az rest --method GET `
        --uri "${APIM_RESOURCE_ID}/diagnostics/azuremonitor?api-version=2022-08-01" `
        --query "properties.sampling.percentage" -o tsv 2>$null
    $DIAG_CLIENT_IP = az rest --method GET `
        --uri "${APIM_RESOURCE_ID}/diagnostics/azuremonitor?api-version=2022-08-01" `
        --query "properties.logClientIp" -o tsv 2>$null
} catch { }

if ($DIAG_SAMPLING) {
    Write-Host "  ✓ azuremonitor diagnostic configured" -ForegroundColor Green
    Write-Host "    Sampling: ${DIAG_SAMPLING}%"
    Write-Host "    Log Client IP: ${DIAG_CLIENT_IP}"
} else {
    Write-Host "  ⚠ azuremonitor diagnostic not found" -ForegroundColor Yellow
    Write-Host "    This may cause logs to not flow to ApiManagementGatewayLogs"
}
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Log Tables Available" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. ApiManagementGatewayLogs (HTTP request details)" -ForegroundColor Yellow
Write-Host "   - CallerIpAddress   - Who made the request"
Write-Host "   - ResponseCode      - HTTP response code"
Write-Host "   - CorrelationId     - For cross-service tracing"
Write-Host "   - Url, Method       - Request path and HTTP method"
Write-Host "   - ApiId             - API identifier for filtering"
Write-Host ""
Write-Host "2. ApiManagementGatewayLlmLog (AI/LLM gateway)" -ForegroundColor Yellow
Write-Host "   - PromptTokens      - Input token count"
Write-Host "   - CompletionTokens  - Output token count"
Write-Host "   - ModelName         - LLM model used"
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  How to Verify in Azure Portal" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Go to your APIM resource in Azure Portal"
Write-Host "2. Navigate to: Monitoring -> Diagnostic settings"
Write-Host "3. You should see: mcp-security-logs"
Write-Host "4. Click to view enabled categories and destination"
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Sample KQL Query" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run this in Log Analytics to see recent traffic:"
Write-Host ""
Write-Host "  ApiManagementGatewayLogs" -ForegroundColor Yellow
Write-Host "  | where TimeGenerated > ago(1h)" -ForegroundColor Yellow
Write-Host "  | where ApiId contains 'mcp' or ApiId contains 'sherpa'" -ForegroundColor Yellow
Write-Host "  | project TimeGenerated, CallerIpAddress, Method, ResponseCode, ApiId" -ForegroundColor Yellow
Write-Host "  | order by TimeGenerated desc" -ForegroundColor Yellow
Write-Host "  | limit 20" -ForegroundColor Yellow
Write-Host ""

Write-Host "Diagnostic settings verification complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note on Log Ingestion Delay:" -ForegroundColor Yellow
Write-Host "  Azure Monitor logs have a 2-5 minute ingestion delay."
Write-Host "  For new deployments, the first logs may take 5-10 minutes."
Write-Host ""
Write-Host "Next: Run ./scripts/section1/1.3-validate.ps1 to query logs" -ForegroundColor Green
