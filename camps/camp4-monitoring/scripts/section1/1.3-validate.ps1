# =============================================================================
# Camp 4 - Section 1.3: Validate APIM Logging
# =============================================================================
# This script queries Log Analytics to verify that APIM diagnostic logs
# configured via Bicep infrastructure are capturing traffic correctly.
# =============================================================================

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..\..")

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Camp 4 - Section 1.3: Validate APIM Logging" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Ensure correct azd environment (fixes session bleed-over from other camps)
$configFile = Join-Path (Get-Location) ".azure\config.json"
if (Test-Path $configFile) {
    $localDefault = (Get-Content $configFile | ConvertFrom-Json).defaultEnvironment
    if ($localDefault -and $env:AZURE_ENV_NAME -ne $localDefault) {
        if ($env:AZURE_ENV_NAME) {
            Write-Host "Note: Overriding AZURE_ENV_NAME '$($env:AZURE_ENV_NAME)' with local default '$localDefault'" -ForegroundColor DarkYellow
        }
        $env:AZURE_ENV_NAME = $localDefault
    }
    Write-Host "Using azd environment: $localDefault" -ForegroundColor DarkGray
    Write-Host ""
}

# Load environment
$APIM_GATEWAY_URL = azd env get-value APIM_GATEWAY_URL 2>$null
$WORKSPACE_RESOURCE_ID = azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>$null
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP 2>$null
$APIM_NAME = azd env get-value APIM_NAME 2>$null
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID 2>$null
$WORKSPACE_NAME = azd env get-value LOG_ANALYTICS_WORKSPACE_NAME 2>$null

if (-not $APIM_GATEWAY_URL -or $APIM_GATEWAY_URL -like "ERROR:*" -or -not $WORKSPACE_RESOURCE_ID) {
    Write-Host "Error: Missing environment values. Run 'azd up' first." -ForegroundColor Red
    exit 1
}

# Get workspace GUID (customerId) - required for az monitor log-analytics query
$WORKSPACE_ID = az monitor log-analytics workspace show `
    --ids "$WORKSPACE_RESOURCE_ID" `
    --query customerId -o tsv 2>$null

if (-not $WORKSPACE_ID) {
    Write-Host "Error: Could not get workspace GUID." -ForegroundColor Red
    exit 1
}

Write-Host "Note: Log Analytics has a 2-5 minute ingestion delay." -ForegroundColor Yellow
Write-Host "This script queries the logs captured by Bicep-deployed diagnostics." -ForegroundColor Yellow
Write-Host ""

Write-Host "Step 1: Verifying diagnostic settings..." -ForegroundColor Blue

# Check diagnostic settings
$APIM_ID = az apim show -n "$APIM_NAME" -g "$RG_NAME" --query id -o tsv 2>$null
$DIAG_SETTINGS = $null
try {
    $DIAG_SETTINGS = az monitor diagnostic-settings list `
        --resource "$APIM_ID" `
        --query "[].{name:name, logs:logs[].category}" -o json 2>$null
} catch { $DIAG_SETTINGS = "[]" }

if ($DIAG_SETTINGS -and $DIAG_SETTINGS -ne "[]") {
    Write-Host "✓ Diagnostic settings configured" -ForegroundColor Green
} else {
    Write-Host "✗ No diagnostic settings found" -ForegroundColor Red
    Write-Host "  Run 'azd up' to deploy infrastructure with diagnostics"
    exit 1
}

Write-Host ""
Write-Host "Step 2: Querying Log Analytics..." -ForegroundColor Blue

# Query for recent MCP traffic (HTTP level)
$QUERY_HTTP_RAW = @'
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where ApiId contains 'mcp' or ApiId contains 'sherpa'
| project TimeGenerated, CallerIpAddress, Method, Url, ResponseCode, ApiId
| order by TimeGenerated desc
| limit 10
'@
$QUERY_HTTP = $QUERY_HTTP_RAW -replace '\r?\n\s*', ' '

Write-Host ""
Write-Host "Running KQL query..."
Write-Host ""

$RESULT_HTTP = $null
$kqlJob = Start-Job -ScriptBlock {
    param($workspace, $query)
    az monitor log-analytics query --workspace $workspace --analytics-query $query --output json 2>$null
} -ArgumentList $WORKSPACE_ID, $QUERY_HTTP
if (Wait-Job $kqlJob -Timeout 30) {
    try { $RESULT_HTTP = (Receive-Job $kqlJob) | ConvertFrom-Json } catch { $RESULT_HTTP = @() }
}
Remove-Job $kqlJob -Force

if (-not $RESULT_HTTP) { $RESULT_HTTP = @() }
$COUNT_HTTP = @($RESULT_HTTP).Count

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Results" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "ApiManagementGatewayLogs (HTTP traffic):" -ForegroundColor Yellow
if ($COUNT_HTTP -gt 0) {
    Write-Host "✓ HTTP logs are flowing to Log Analytics!" -ForegroundColor Green
    Write-Host ""
    foreach ($row in $RESULT_HTTP) {
        Write-Host "  $($row.TimeGenerated) | $($row.Method) $($row.ApiId) | HTTP $($row.ResponseCode) | $($row.CallerIpAddress)"
    }
} else {
    Write-Host "No HTTP logs found yet (2-5 min ingestion delay)" -ForegroundColor Yellow
}

Write-Host ""
if ($COUNT_HTTP -gt 0) {
    Write-Host "Section 1 Complete: APIM traffic is now VISIBLE" -ForegroundColor Green
} else {
    Write-Host "No logs found yet (this is normal if you just enabled diagnostics)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Logs take 2-5 minutes to appear. Try again in a few minutes."
    Write-Host ""
    Write-Host "You can also check manually in the Azure Portal:"
    Write-Host "1. Go to your Log Analytics workspace"
    Write-Host "2. Click 'Logs'"
    Write-Host "3. Run: ApiManagementGatewayLogs | where ApiId contains 'mcp' | limit 10"
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  What You've Accomplished" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ APIM is now logging all MCP requests to Log Analytics"
Write-Host "✓ ApiManagementGatewayLogs captures: Caller IPs, response codes, timing, URLs"
Write-Host "✓ You can query and analyze MCP traffic patterns using ApiId filtering"
Write-Host ""
Write-Host "But we still have a gap:"
Write-Host "  The security function logs are still BASIC (unstructured)"
Write-Host "  We can't correlate APIM logs with function logs"
Write-Host "  We can't see detailed security events (injection type, PII entities)"
Write-Host ""
Write-Host "Next: Run ./scripts/section2/2.1-exploit.ps1 to see the function logging gap" -ForegroundColor Green
Write-Host ""
