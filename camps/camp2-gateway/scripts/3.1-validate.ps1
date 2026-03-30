# Waypoint 3.1: Validate - IP Restrictions Working
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 3.1: Validate IP Restrictions"
Write-Host "=========================================="
Write-Host ""

$APIM_URL = azd env get-value APIM_GATEWAY_URL
$SHERPA_URL = azd env get-value SHERPA_SERVER_URL
$TRAIL_URL = azd env get-value TRAIL_API_URL

Write-Host "Test 1: Direct call to Sherpa (should be blocked)"
try {
    $HTTP_STATUS = curl.exe -s -o NUL -w "%{http_code}" --max-time 10 "$SHERPA_URL/mcp" 2>$null
} catch { $HTTP_STATUS = "000" }
Write-Host "  Direct: $HTTP_STATUS"
if ($HTTP_STATUS -eq "403" -or $HTTP_STATUS -eq "000") {
    Write-Host "  Result: Blocked"
} else {
    Write-Host "  Result: Still accessible (see note below)"
}

Write-Host ""
Write-Host "Test 2: Direct call to Trail API (should be blocked)"
try {
    $HTTP_STATUS = curl.exe -s -o NUL -w "%{http_code}" --max-time 10 "$TRAIL_URL/" 2>$null
} catch { $HTTP_STATUS = "000" }
Write-Host "  Direct: $HTTP_STATUS"
if ($HTTP_STATUS -eq "403" -or $HTTP_STATUS -eq "000") {
    Write-Host "  Result: Blocked"
} else {
    Write-Host "  Result: Still accessible (see note below)"
}

Write-Host ""
Write-Host "Test 3: Via APIM (should still work through gateway controls)"
try {
    $HTTP_STATUS = curl.exe -s -o NUL -w "%{http_code}" "$APIM_URL/trailapi/trails" 2>$null
} catch { $HTTP_STATUS = "000" }
Write-Host "  Via APIM: $HTTP_STATUS (expect 401/200 depending on auth)"

Write-Host ""
Write-Host "=========================================="
Write-Host "Workshop Limitation Note"
Write-Host "=========================================="
Write-Host ""
Write-Host "APIM Basic v2 doesn't have static IPs, so full IP-based"
Write-Host "restrictions require APIM Standard v2 with VNet integration."
Write-Host ""
Write-Host "See docs/network-concepts.md for production patterns."
Write-Host ""
Write-Host "=========================================="
Write-Host "Camp 2 Complete: Gateway Security"
Write-Host "=========================================="
Write-Host ""
Write-Host "Security controls implemented:"
Write-Host "  1.1 Sherpa MCP deployed"
Write-Host "  1.2 OAuth for MCP"
Write-Host "  1.3 Rate Limiting"
Write-Host "  1.4 API Center governance"
Write-Host "  2.1 Content Safety filtering"
Write-Host "  3.1 Network isolation (demo)"
Write-Host ""
Write-Host "For more information:"
Write-Host "  - docs/network-concepts.md"
Write-Host "  - docs/read-write-patterns.md"
Write-Host ""
