# Waypoint 1.2: Validate - Hybrid Authentication Working
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.2: Validate Trail MCP Security"
Write-Host "=========================================="
Write-Host ""

$APIM_URL = azd env get-value APIM_GATEWAY_URL
$SUB_KEY = azd env get-value TRAIL_SUBSCRIPTION_KEY

Write-Host "Test 1: No credentials (should fail)"
try {
    $HTTP_STATUS = curl.exe -s -o NUL -w "%{http_code}" "$APIM_URL/trails/mcp" 2>$null
} catch { $HTTP_STATUS = "000" }

if ($HTTP_STATUS -eq "401") {
    Write-Host "  Result: 401 Unauthorized (needs subscription key)"
} else {
    Write-Host "  Result: $HTTP_STATUS (expected 401)"
}

Write-Host ""
Write-Host "Test 2: Subscription key only (should fail - needs OAuth)"
try {
    $HTTP_STATUS = curl.exe -s -o NUL -w "%{http_code}" "$APIM_URL/trails/mcp" `
        -H "Ocp-Apim-Subscription-Key: $SUB_KEY" 2>$null
} catch { $HTTP_STATUS = "000" }

if ($HTTP_STATUS -eq "401") {
    Write-Host "  Result: 401 Unauthorized (OAuth also required)"
} else {
    Write-Host "  Result: $HTTP_STATUS (expected 401)"
}

Write-Host ""
Write-Host "Test 3: Check WWW-Authenticate header"
$RESPONSE = curl.exe -s -D - "$APIM_URL/trails/mcp" -H "Ocp-Apim-Subscription-Key: $SUB_KEY" 2>$null
$AUTH_HEADER = $RESPONSE | Select-String -Pattern "WWW-Authenticate" | Select-Object -First 1
if ($AUTH_HEADER) {
    Write-Host "  WWW-Authenticate header present"
    Write-Host "  $AUTH_HEADER"
} else {
    Write-Host "  No WWW-Authenticate header"
}

Write-Host ""
Write-Host "Test 4: RFC 9728 PRM discovery"
Write-Host "  GET $APIM_URL/.well-known/oauth-protected-resource/trails/mcp"
$PRM_RESPONSE = curl.exe -s "$APIM_URL/.well-known/oauth-protected-resource/trails/mcp" 2>$null
if ($PRM_RESPONSE -match "authorization_servers") {
    Write-Host "  PRM metadata returned correctly"
    try {
        $formatted = $PRM_RESPONSE | ConvertFrom-Json | ConvertTo-Json -Depth 5
        $formatted -split "`n" | ForEach-Object { Write-Host "  $_" }
    } catch {
        Write-Host "  $PRM_RESPONSE"
    }
} else {
    Write-Host "  PRM endpoint not returning expected metadata"
    Write-Host "  Response: $PRM_RESPONSE"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.2 Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "Trail MCP Server now requires:"
Write-Host "  - Subscription key (for tracking/billing)"
Write-Host "  - OAuth token (for authentication)"
Write-Host ""
