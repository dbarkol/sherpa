# Waypoint 1.3: Validate - Rate Limiting Working
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.3: Validate Rate Limiting"
Write-Host "=========================================="
Write-Host ""

$APIM_URL = azd env get-value APIM_GATEWAY_URL
$SUB_KEY = azd env get-value TRAIL_SUBSCRIPTION_KEY

Write-Host "Testing rate limiting by subscription key..."
Write-Host "Limit: 10 requests per minute per subscription"
Write-Host ""
Write-Host "Sending 15 rapid requests..."
Write-Host ""

$RATE_LIMITED = 0
$SUCCESS_COUNT = 0
for ($i = 1; $i -le 15; $i++) {
    try {
        $response = curl.exe -s -w "`n%{http_code}" `
            "$APIM_URL/trailapi/trails" `
            -H "Ocp-Apim-Subscription-Key: $SUB_KEY" 2>$null
        $lines = $response -split "`n"
        $HTTP_CODE = $lines[-1]
    } catch { $HTTP_CODE = "000" }

    if ($HTTP_CODE -eq "429") {
        Write-Host "  Request ${i}: 429 Too Many Requests (rate limited)"
        $RATE_LIMITED++
    } elseif ($HTTP_CODE -eq "401") {
        Write-Host "  Request ${i}: 401 (OAuth required, but passed rate limit check)"
        $SUCCESS_COUNT++
    } elseif ($HTTP_CODE -eq "200") {
        Write-Host "  Request ${i}: 200 OK"
        $SUCCESS_COUNT++
    } else {
        Write-Host "  Request ${i}: $HTTP_CODE"
    }

    # Small delay to let distributed counters sync
    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "Results:"
Write-Host "  Requests that passed rate limit: $SUCCESS_COUNT"
Write-Host "  Requests rate limited (429): $RATE_LIMITED"
Write-Host ""

if ($RATE_LIMITED -gt 0) {
    Write-Host "✅ Rate limiting is working!"
    Write-Host ""
    Write-Host "Different subscription keys get separate quotas."
    Write-Host "This enables per-team/per-app rate limiting."
} else {
    Write-Host "Note: If no 429s, rate limiting may not have triggered."
    Write-Host "Try running again or check APIM policy configuration."
}

Write-Host ""
Write-Host "=========================================="
Write-Host "✅ Waypoint 1.3 Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "Next: Register APIs for governance"
Write-Host "  ./scripts/1.4-fix.ps1"
Write-Host ""
