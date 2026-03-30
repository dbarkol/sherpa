# =============================================================================
# Camp 4 - Section 2.2: Switch to Function v2 with Structured Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: HIDDEN → VISIBLE
# =============================================================================

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..\..")

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Camp 4 - Section 2.2: Enable Structured Logging" -ForegroundColor Cyan
Write-Host "  Pattern: hidden -> visible -> actionable" -ForegroundColor Cyan
Write-Host "  Transition: HIDDEN -> VISIBLE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Load environment
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP 2>$null
$APIM_NAME = azd env get-value APIM_NAME 2>$null
$FUNC_V1_URL = azd env get-value FUNCTION_APP_V1_URL 2>$null
$FUNC_V2_URL = azd env get-value FUNCTION_APP_V2_URL 2>$null

if (-not $APIM_NAME -or -not $FUNC_V2_URL) {
    Write-Host "Error: Required environment values not found. Run 'azd up' first." -ForegroundColor Red
    exit 1
}

Write-Host "Current Architecture:" -ForegroundColor Yellow
Write-Host "Both function versions are already deployed:"
Write-Host "  v1: $FUNC_V1_URL (basic logging - currently active)"
Write-Host "  v2: $FUNC_V2_URL (structured logging)"
Write-Host ""
Write-Host "What we're doing:" -ForegroundColor Yellow
Write-Host "1. Update APIM named value 'function-app-url' to point to v2"
Write-Host "2. That's it! APIM policies automatically use the new URL"
Write-Host ""

# Check current value
Write-Host "Step 1: Checking current APIM configuration..." -ForegroundColor Blue
$CURRENT_URL = az apim nv show `
    --resource-group "$RG_NAME" `
    --service-name "$APIM_NAME" `
    --named-value-id "function-app-url" `
    --query "value" -o tsv 2>$null

Write-Host "Current function-app-url: $CURRENT_URL"
Write-Host ""

if ($CURRENT_URL -like "*funcv2*") {
    Write-Host "Already pointing to v2! No change needed." -ForegroundColor Yellow
} else {
    Write-Host "Step 2: Switching APIM to use v2..." -ForegroundColor Blue

    az apim nv update `
        --resource-group "$RG_NAME" `
        --service-name "$APIM_NAME" `
        --named-value-id "function-app-url" `
        --value "$FUNC_V2_URL" `
        --output none

    Write-Host ""
    Write-Host "✓ APIM now points to v2!" -ForegroundColor Green

    Write-Host ""
    Write-Host "Waiting 10 seconds for APIM to propagate the change..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  What Changed: v1 vs v2" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "v1 (basic logging):"
Write-Host "  logging.warning(f'Injection blocked: {category}')" -ForegroundColor Red
Write-Host ""
Write-Host "v2 (structured logging):"
Write-Host "  log_injection_blocked(" -ForegroundColor Green
Write-Host "      injection_type=result.category," -ForegroundColor Green
Write-Host "      reason=result.reason," -ForegroundColor Green
Write-Host "      correlation_id=correlation_id," -ForegroundColor Green
Write-Host "      tool_name=tool_name" -ForegroundColor Green
Write-Host "  )" -ForegroundColor Green
Write-Host ""
Write-Host "This creates structured log entries with custom dimensions:"
Write-Host ""
Write-Host '  {"event_type": "INJECTION_BLOCKED",'
Write-Host '   "injection_type": "sql_injection",'
Write-Host '   "correlation_id": "abc-123",'
Write-Host '   "tool_name": "search",'
Write-Host '   "severity": "WARNING"}'
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  KQL Queries Now Possible" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Count attacks by type:" -ForegroundColor Yellow
Write-Host "  AppTraces"
Write-Host "  | where Properties.event_type == 'INJECTION_BLOCKED'"
Write-Host "  | summarize Count=count() by tostring(Properties.injection_type)"
Write-Host "  | order by Count desc"
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Generating Test Events (for 2.3-validate.ps1)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now that v2 is active, we'll send a few attacks to generate"
Write-Host "structured log entries for validation..."
Write-Host ""

# Get OAuth token and send test attacks
# Guard against session bleed-over from other camps
$configFile = Join-Path (Get-Location) ".azure\config.json"
if (Test-Path $configFile) {
    $localDefault = (Get-Content $configFile | ConvertFrom-Json).defaultEnvironment
    if ($localDefault -and $env:AZURE_ENV_NAME -ne $localDefault) { $env:AZURE_ENV_NAME = $localDefault }
}
$APIM_GATEWAY_URL = azd env get-value APIM_GATEWAY_URL 2>$null
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID 2>$null
if ($APIM_GATEWAY_URL -like "ERROR:*") { $APIM_GATEWAY_URL = $null }
if ($MCP_APP_CLIENT_ID -like "ERROR:*") { $MCP_APP_CLIENT_ID = $null }

if ($APIM_GATEWAY_URL -and $MCP_APP_CLIENT_ID) {
    $TOKEN = $null
    try { $TOKEN = az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>$null } catch { }

    if ($TOKEN) {
        $headersFile = Join-Path $env:TEMP "mcp-headers.txt"

        # Initialize MCP session
        try {
            curl.exe -s -D $headersFile --max-time 10 -X POST "$APIM_GATEWAY_URL/sherpa/mcp" `
                -H "Authorization: Bearer $TOKEN" `
                -H "Content-Type: application/json" `
                -H "Accept: application/json, text/event-stream" `
                -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"camp4-v2-test","version":"1.0"}},"id":1}' 2>$null | Out-Null
        } catch { }

        $SESSION_ID = $null
        if (Test-Path $headersFile) {
            $headerLine = Get-Content $headersFile | Select-String -Pattern "mcp-session-id" -CaseSensitive:$false | Select-Object -First 1
            if ($headerLine) { $SESSION_ID = ($headerLine.ToString() -replace '.*:\s*', '').Trim() }
        }
        if (-not $SESSION_ID) { $SESSION_ID = "session-$(Get-Date -UFormat %s)" }

        Write-Host "Sending SQL injection..." -ForegroundColor Blue
        $HTTP_CODE = "error"
        try {
            $HTTP_CODE = curl.exe -s -w "%{http_code}" -o NUL --max-time 10 -X POST "$APIM_GATEWAY_URL/sherpa/mcp" `
                -H "Authorization: Bearer $TOKEN" `
                -H "Content-Type: application/json" `
                -H "Accept: application/json, text/event-stream" `
                -H "Mcp-Session-Id: $SESSION_ID" `
                -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"''; DROP TABLE users; --"}},"id":2}'
        } catch { }
        Write-Host "  Status: $HTTP_CODE (expected: 400)"

        Write-Host "Sending path traversal..." -ForegroundColor Blue
        $HTTP_CODE = "error"
        try {
            $HTTP_CODE = curl.exe -s -w "%{http_code}" -o NUL --max-time 10 -X POST "$APIM_GATEWAY_URL/sherpa/mcp" `
                -H "Authorization: Bearer $TOKEN" `
                -H "Content-Type: application/json" `
                -H "Accept: application/json, text/event-stream" `
                -H "Mcp-Session-Id: $SESSION_ID" `
                -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check_trail_conditions","arguments":{"trail_id":"../../../etc/passwd"}},"id":3}'
        } catch { }
        Write-Host "  Status: $HTTP_CODE (expected: 400)"

        Write-Host "Sending shell injection..." -ForegroundColor Blue
        $HTTP_CODE = "error"
        try {
            $HTTP_CODE = curl.exe -s -w "%{http_code}" -o NUL --max-time 10 -X POST "$APIM_GATEWAY_URL/sherpa/mcp" `
                -H "Authorization: Bearer $TOKEN" `
                -H "Content-Type: application/json" `
                -H "Accept: application/json, text/event-stream" `
                -H "Mcp-Session-Id: $SESSION_ID" `
                -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"summit; cat /etc/passwd"}},"id":4}'
        } catch { }
        Write-Host "  Status: $HTTP_CODE (expected: 400)"

        Write-Host ""
        Write-Host "✓ Test attacks sent! These will appear as structured events." -ForegroundColor Green
    } else {
        Write-Host "Warning: Could not get access token. Skipping test events." -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: Missing APIM URL or client ID. Skipping test events." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Note: Log Ingestion Delay" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Azure Monitor logs have a 2-5 minute ingestion delay."
Write-Host "Run 2.3-validate.ps1 after a few minutes to verify structured logs appear."
Write-Host ""
Write-Host "Next: Wait 2-5 minutes, then run ./scripts/section2/2.3-validate.ps1" -ForegroundColor Green
Write-Host ""
