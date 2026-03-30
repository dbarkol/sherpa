# =============================================================================
# Camp 4 - Section 3.1: Deploy Security Workbook (Dashboard)
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: VISIBLE → ACTIONABLE (part 1: visibility)
# =============================================================================

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..\..")

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Camp 4 - Section 3.1: Deploy Security Workbook" -ForegroundColor Cyan
Write-Host "  Pattern: hidden -> visible -> actionable" -ForegroundColor Cyan
Write-Host "  Transition: VISIBLE -> ACTIONABLE" -ForegroundColor Cyan
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

Write-Host "What we're creating:" -ForegroundColor Yellow
Write-Host "An Azure Workbook with pre-built visualizations for MCP security:"
Write-Host ""
Write-Host "  - Request volume over time"
Write-Host "  - Attack attempts by injection type"
Write-Host "  - Top targeted MCP tools"
Write-Host "  - Caller IP analysis"
Write-Host "  - Security event timeline"
Write-Host ""

$WORKBOOK_DISPLAY = "MCP Security Dashboard"

# Generate a deterministic GUID for the workbook (so re-runs update instead of creating duplicates)
$md5 = [System.Security.Cryptography.MD5]::Create()
$inputBytes = [System.Text.Encoding]::UTF8.GetBytes("$RG_NAME-mcp-security-dashboard")
$hashBytes = $md5.ComputeHash($inputBytes)
$hashHex = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ''
$WORKBOOK_GUID = "$($hashHex.Substring(0,8))-$($hashHex.Substring(8,4))-$($hashHex.Substring(12,4))-$($hashHex.Substring(16,4))-$($hashHex.Substring(20,12))"

Write-Host "Creating workbook (ID: $WORKBOOK_GUID)..." -ForegroundColor Blue

# Create ARM template using Python helper script for proper JSON escaping
$outputFile = Join-Path $env:TEMP "mcp-workbook-template.json"
$env:WORKSPACE_ID = $WORKSPACE_ID
$env:WORKBOOK_GUID = $WORKBOOK_GUID
$env:LOCATION = $LOCATION
$env:OUTPUT_FILE = $outputFile
python "$PSScriptRoot\create-workbook-template.py"

# Deploy the workbook via ARM template
az deployment group create `
    --resource-group "$RG_NAME" `
    --template-file $outputFile `
    --output none

Write-Host ""
Write-Host "✓ Security workbook created!" -ForegroundColor Green
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Access Your Dashboard" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Open the Azure Portal and navigate to:"
Write-Host ""
Write-Host "  1. Go to your Log Analytics workspace"
Write-Host "  2. Click 'Workbooks' in the left menu"
Write-Host "  3. Select '$WORKBOOK_DISPLAY' from the list"
Write-Host ""

# Get workspace name for the URL
$WORKSPACE_NAME = az monitor log-analytics workspace show --ids "$WORKSPACE_ID" --query name -o tsv 2>$null
$SUB_ID = az account show --query id -o tsv
Write-Host "Direct link to workbooks:"
Write-Host "  https://portal.azure.com/#@/resource/subscriptions/$SUB_ID/resourceGroups/$RG_NAME/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME/workbooks"
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Dashboard Panels" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [✓] MCP Request Volume - Shows traffic patterns over 24h"
Write-Host "  [✓] Attacks by Type - Pie chart of injection types"
Write-Host "  [✓] Top Targeted Tools - Which MCP tools attackers target"
Write-Host "  [✓] Error Sources - IPs generating the most errors"
Write-Host "  [✓] Recent Events - Live feed of security events"
Write-Host ""
Write-Host "The dashboard updates in near-real-time as logs are ingested."
Write-Host ""
Write-Host "Tip: If the dashboard appears empty, do a hard refresh (Ctrl+Shift+R)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next: Run ./scripts/section3/3.2-create-alerts.ps1 to set up alerting" -ForegroundColor Green
Write-Host ""
