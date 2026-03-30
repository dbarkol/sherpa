# =============================================================================
# Camp 4 - Section 2.3: Validate Structured Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Current state: VISIBLE (verifying structured logs)
# =============================================================================

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..\..")

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
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Camp 4 - Section 2.3: Validate Structured Logging" -ForegroundColor Cyan
Write-Host "  Pattern: hidden -> visible -> actionable" -ForegroundColor Cyan
Write-Host "  Current State: VISIBLE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Load environment
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP 2>$null

# Get workspace GUID
$WORKSPACE_ID = az monitor log-analytics workspace list -g "$RG_NAME" --query "[0].customerId" -o tsv 2>$null

if (-not $WORKSPACE_ID) {
    Write-Host "Error: Could not find Log Analytics workspace. Run 'azd up' first." -ForegroundColor Red
    exit 1
}

Write-Host "Note: Log Analytics has a 2-5 minute ingestion delay." -ForegroundColor Yellow
Write-Host "This script queries for structured logs sent by 2.2-fix.ps1." -ForegroundColor Yellow
Write-Host ""

Write-Host "Querying for structured security events..." -ForegroundColor Blue
Write-Host ""

# Query for structured security events
$QUERY_RAW = @'
AppTraces
| where TimeGenerated > ago(24h)
| where tostring(Properties) contains 'event_type'
| extend EventType=tostring(parse_json(Properties).event_type),
         InjectionType=tostring(parse_json(Properties).injection_type),
         CorrelationId=tostring(parse_json(Properties).correlation_id),
         ToolName=tostring(parse_json(Properties).tool_name)
| where EventType == 'INJECTION_BLOCKED'
| project TimeGenerated, EventType, InjectionType, ToolName, CorrelationId
| order by TimeGenerated desc
| limit 20
'@
$QUERY = $QUERY_RAW -replace '\r?\n\s*', ' '

$RESULT = $null
$kqlJob = Start-Job -ScriptBlock {
    param($workspace, $query)
    az monitor log-analytics query --workspace $workspace --analytics-query $query --output json 2>$null
} -ArgumentList $WORKSPACE_ID, $QUERY
if (Wait-Job $kqlJob -Timeout 30) {
    try { $RESULT = (Receive-Job $kqlJob) | ConvertFrom-Json } catch { $RESULT = @() }
}
Remove-Job $kqlJob -Force

if (-not $RESULT) { $RESULT = @() }

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Structured Log Results" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$COUNT = @($RESULT).Count

if ($COUNT -gt 0) {
    Write-Host "✓ Structured logs are flowing!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Recent security events:"
    Write-Host ""
    $RESULT | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.TimeGenerated) | $($_.EventType) | $($_.InjectionType) | Tool: $($_.ToolName)"
    }
    Write-Host ""

    # Count by injection type
    Write-Host ""
    Write-Host "Summary by injection type:" -ForegroundColor Blue

    $SUMMARY_QUERY_RAW = @'
AppTraces
| where TimeGenerated > ago(24h)
| where tostring(Properties) contains 'event_type'
| extend EventType=tostring(parse_json(Properties).event_type),
         InjectionType=tostring(parse_json(Properties).injection_type)
| where EventType == 'INJECTION_BLOCKED'
| summarize Count=count() by InjectionType
| order by Count desc
'@
    $SUMMARY_QUERY = $SUMMARY_QUERY_RAW -replace '\r?\n\s*', ' '

    $SUMMARY = $null
    $summaryJob = Start-Job -ScriptBlock {
        param($workspace, $query)
        az monitor log-analytics query --workspace $workspace --analytics-query $query --output json 2>$null
    } -ArgumentList $WORKSPACE_ID, $SUMMARY_QUERY
    if (Wait-Job $summaryJob -Timeout 30) {
        try { $SUMMARY = (Receive-Job $summaryJob) | ConvertFrom-Json } catch { $SUMMARY = @() }
    }
    Remove-Job $summaryJob -Force

    if ($SUMMARY) {
        foreach ($row in $SUMMARY) {
            Write-Host "  $($row.InjectionType): $($row.Count) attacks"
        }
    } else {
        Write-Host "  (No summary available)"
    }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  Section 2 Complete: Function Logs are VISIBLE" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "✓ APIM logs show HTTP requests with caller IPs"
    Write-Host "✓ Function logs show security events with custom dimensions"
    Write-Host "✓ You can correlate across services using correlation_id"
    Write-Host "✓ You can query by injection type, tool name, etc."
    Write-Host ""
    Write-Host "But security is still not ACTIONABLE:"
    Write-Host "  No dashboard to visualize attack patterns"
    Write-Host "  No alerts to notify you of attacks in real-time"
    Write-Host "  You have to manually run KQL queries to see what's happening"
    Write-Host ""
    Write-Host "Next: Run ./scripts/section3/3.1-deploy-workbook.ps1 to create a dashboard" -ForegroundColor Green
} else {
    Write-Host "No structured logs found yet" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This could mean:"
    Write-Host "  1. Logs haven't ingested yet (wait 2-5 minutes and try again)"
    Write-Host "  2. APIM isn't pointing to v2 (run ./scripts/section2/2.2-fix.ps1)"
    Write-Host ""
    Write-Host "Try again in a few minutes."
}

Write-Host ""
