# Waypoint 1.1: Validate - OAuth Working
#
# Validates that OAuth is properly configured:
# 1. Requests without token return 401
# 2. WWW-Authenticate header includes resource_metadata
# 3. Both PRM discovery paths work (RFC 9728 + suffix)
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.1: Validate OAuth"
Write-Host "=========================================="
Write-Host ""

$APIM_URL = azd env get-value APIM_GATEWAY_URL
$ALL_PASSED = $true

Write-Host "Test 1: Request without token (should return 401)"
try {
    $HTTP_STATUS = curl.exe -s -o NUL -w "%{http_code}" "$APIM_URL/sherpa/mcp" 2>$null
} catch {
    $HTTP_STATUS = "000"
}

if ($HTTP_STATUS -eq "401") {
    Write-Host "  ✅ Result: 401 Unauthorized (token required)"
} else {
    Write-Host "  ❌ Result: $HTTP_STATUS (expected 401)"
    $ALL_PASSED = $false
}

Write-Host ""
Write-Host "Test 2: Check WWW-Authenticate header has correct resource_metadata"
$headers = curl.exe -s -I "$APIM_URL/sherpa/mcp" 2>$null
$AUTH_HEADER = $headers | Select-String -Pattern "WWW-Authenticate" | Select-Object -First 1
if ($AUTH_HEADER -and $AUTH_HEADER.ToString() -match "sherpa/mcp") {
    Write-Host "  ✅ WWW-Authenticate includes /sherpa/mcp path"
} else {
    Write-Host "  ❌ WWW-Authenticate missing /sherpa/mcp path"
    Write-Host "  Header: $AUTH_HEADER"
    $ALL_PASSED = $false
}

Write-Host ""
Write-Host "Test 3: Check 401 response body has correct resource_metadata"
$BODY = curl.exe -s "$APIM_URL/sherpa/mcp" 2>$null
if ($BODY -match "sherpa/mcp") {
    Write-Host "  ✅ Response body includes /sherpa/mcp path"
} else {
    Write-Host "  ❌ Response body missing /sherpa/mcp path"
    Write-Host "  Body: $BODY"
    $ALL_PASSED = $false
}

Write-Host ""
Write-Host "Test 4: RFC 9728 path-based PRM discovery"
Write-Host "  GET $APIM_URL/.well-known/oauth-protected-resource/sherpa/mcp"
$PRM_RFC = curl.exe -s "$APIM_URL/.well-known/oauth-protected-resource/sherpa/mcp" 2>$null
try {
    $prmObj = $PRM_RFC | ConvertFrom-Json
    if ($prmObj.resource) {
        Write-Host "  ✅ RFC 9728 PRM metadata returned"
        Write-Host ($PRM_RFC | ConvertFrom-Json | ConvertTo-Json -Depth 5)
    } else {
        Write-Host "  ❌ RFC 9728 PRM not accessible"
        $ALL_PASSED = $false
    }
} catch {
    Write-Host "  ❌ RFC 9728 PRM not accessible"
    $ALL_PASSED = $false
}

Write-Host ""
Write-Host "Test 5: Suffix pattern PRM discovery"
Write-Host "  GET $APIM_URL/sherpa/mcp/.well-known/oauth-protected-resource"
$PRM_SUFFIX = curl.exe -s "$APIM_URL/sherpa/mcp/.well-known/oauth-protected-resource" 2>$null
try {
    $prmObj = $PRM_SUFFIX | ConvertFrom-Json
    if ($prmObj.resource) {
        Write-Host "  ✅ Suffix PRM metadata returned"
    } else {
        Write-Host "  ❌ Suffix PRM not accessible"
        $ALL_PASSED = $false
    }
} catch {
    Write-Host "  ❌ Suffix PRM not accessible"
    $ALL_PASSED = $false
}

Write-Host ""
if ($ALL_PASSED) {
    Write-Host "=========================================="
    Write-Host "✅ Waypoint 1.1 Complete"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "OAuth is properly configured. VS Code can now:"
    Write-Host "  1. Discover PRM at either discovery path"
    Write-Host "  2. Find the Entra ID authorization server"
    Write-Host "  3. Obtain tokens and call the MCP API"
    Write-Host ""
} else {
    Write-Host "=========================================="
    Write-Host "❌ Waypoint 1.1 Validation Failed"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Some tests failed. Review the output above."
}
Write-Host ""
