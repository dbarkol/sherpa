# =============================================================================
# Camp 4 - Section 3.2: Create Alert Rules
# =============================================================================
# Pattern: hidden -> visible -> actionable
# Transition: VISIBLE -> ACTIONABLE (part 2: automated response)
# =============================================================================

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..\..")

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Camp 4 - Section 3.2: Create Alert Rules" -ForegroundColor Cyan
Write-Host "  Pattern: hidden -> visible -> actionable" -ForegroundColor Cyan
Write-Host "  Making Security ACTIONABLE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Load environment
$RG_NAME = azd env get-value AZURE_RESOURCE_GROUP 2>$null
$WORKSPACE_ID = azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>$null
$LOCATION = azd env get-value AZURE_LOCATION 2>$null

if (-not $RG_NAME -or -not $WORKSPACE_ID) {
    Write-Host "Error: Missing environment values. Run 'azd up' first." -ForegroundColor Red
    exit 1
}

# Prompt for email (optional)
Write-Host "Alert notifications (optional):" -ForegroundColor Yellow
$ALERT_EMAIL = Read-Host "Enter an email address to receive alerts (or press Enter to skip)"

Write-Host ""
Write-Host "What we're creating:" -ForegroundColor Yellow
Write-Host "  - Action Group - Defines how to notify (email, webhook)"
Write-Host "  - Alert 1 - High attack volume (>10 attacks in 5 min)"
Write-Host "  - Alert 2 - Credential exposure detected"
Write-Host ""

# Create Action Group
$ACTION_GROUP_NAME = "mcp-security-alerts"

Write-Host "Step 1: Creating action group..." -ForegroundColor Blue

if ($ALERT_EMAIL) {
    az monitor action-group create `
        --name "$ACTION_GROUP_NAME" `
        --resource-group "$RG_NAME" `
        --short-name "MCPSecAlrt" `
        --action email "security-team" "$ALERT_EMAIL" `
        --output none 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "  (Action group may already exist)" }
} else {
    az monitor action-group create `
        --name "$ACTION_GROUP_NAME" `
        --resource-group "$RG_NAME" `
        --short-name "MCPSecAlrt" `
        --output none 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "  (Action group may already exist)" }
}

$ACTION_GROUP_ID = az monitor action-group show `
    --name "$ACTION_GROUP_NAME" `
    --resource-group "$RG_NAME" `
    --query id -o tsv 2>$null

if (-not $ACTION_GROUP_ID) {
    Write-Host "Error: Failed to get action group ID" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Action group ready" -ForegroundColor Green
Write-Host ""

# Deploy alert rules using ARM template via Python helper
Write-Host "Step 2: Deploying alert rules via ARM template..." -ForegroundColor Blue
Write-Host ""

# Generate and deploy using Python helper
$TEMPLATE_FILE = [System.IO.Path]::GetTempFileName()
python "$PSScriptRoot\create-alert-template.py" "$WORKSPACE_ID" "$ACTION_GROUP_ID" "$LOCATION" > $TEMPLATE_FILE

if (-not (Test-Path $TEMPLATE_FILE) -or (Get-Item $TEMPLATE_FILE).Length -eq 0) {
    Write-Host "Error: Failed to generate ARM template" -ForegroundColor Red
    Remove-Item -Path $TEMPLATE_FILE -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "  Deploying ARM template..."
$DEPLOY_OUTPUT = az deployment group create `
    --resource-group "$RG_NAME" `
    --template-file "$TEMPLATE_FILE" `
    --name "mcp-alert-rules" `
    --output json 2>&1

$DEPLOY_STATE = "Unknown"
try {
    $parsed = $DEPLOY_OUTPUT | ConvertFrom-Json
    $DEPLOY_STATE = $parsed.properties.provisioningState
} catch { }

Remove-Item -Path $TEMPLATE_FILE -Force -ErrorAction SilentlyContinue

if ($DEPLOY_STATE -eq "Succeeded") {
    Write-Host "[OK] Alert rules deployed successfully" -ForegroundColor Green
} else {
    Write-Host "[!] Deployment result: $DEPLOY_STATE" -ForegroundColor Yellow
    Write-Host "    (Rules may have been updated or already existed)"
}

Write-Host ""

# Verify alerts were created
Write-Host "Step 3: Verifying alert rules..." -ForegroundColor Blue

$ALERT_COUNT = az resource list `
    --resource-group "$RG_NAME" `
    --resource-type "Microsoft.Insights/scheduledQueryRules" `
    --query "length([?contains(name, 'mcp-')])" `
    -o tsv 2>$null

if ([int]$ALERT_COUNT -ge 2) {
    Write-Host "[OK] Found $ALERT_COUNT MCP alert rules" -ForegroundColor Green
} else {
    Write-Host "[!] Found $ALERT_COUNT alert rules (expected 2)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Alert Rules Ready" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Alert Rules Created:"
Write-Host "  [!] mcp-high-attack-volume (Severity 2)"
Write-Host "      Triggers when >10 attacks in 5 minutes"
Write-Host ""
Write-Host "  [!] mcp-credential-exposure (Severity 1 - Critical)"
Write-Host "      Triggers on ANY credential detection"
Write-Host ""
if ($ALERT_EMAIL) {
    Write-Host "  Notifications will be sent to: $ALERT_EMAIL"
} else {
    Write-Host "  No email configured (alerts visible in Azure Portal)"
}
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Section 3 Complete: Security is ACTIONABLE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[OK] Dashboard shows real-time security visibility"
Write-Host "[OK] Alerts notify you when attacks exceed thresholds"
Write-Host "[OK] Action groups can trigger automated responses"
Write-Host ""
Write-Host "The 'hidden -> visible -> actionable' pattern is complete:"
Write-Host ""
Write-Host "  [OK] HIDDEN:     APIM + Function had basic/no logging"
Write-Host "  [OK] VISIBLE:    Diagnostic settings + structured logging"
Write-Host "  [OK] ACTIONABLE: Dashboard + alerts for automated response"
Write-Host ""
Write-Host "Next: Run ./scripts/section4/4.1-simulate-attack.ps1 to test the full system" -ForegroundColor Green
Write-Host ""
