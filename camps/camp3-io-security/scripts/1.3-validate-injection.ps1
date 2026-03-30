# Waypoint 1.3: Validate - Technical Injection Blocked
# Confirms that technical injection patterns are now blocked by Layer 2
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $ScriptDir "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.3: Validate Technical Injection Blocking"
Write-Host "=========================================="
Write-Host ""

$APIM_URL = azd env get-value APIM_GATEWAY_URL
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID

Write-Host "Getting OAuth token..."
$TOKEN = az account get-access-token --resource $MCP_APP_CLIENT_ID --query accessToken -o tsv 2>$null

if (-not $TOKEN) {
    Write-Host "Failed to get OAuth token. Make sure you're logged in with: az login"
    exit 1
}

Write-Host "Token acquired successfully"
Write-Host ""

Write-Host "Testing Technical Injection Blocking (Layer 2)"
Write-Host "==============================================="
Write-Host ""

# Initialize MCP session first (required by MCP protocol)
Write-Host "Initializing MCP session..."
$INIT_RESPONSE = curl.exe -s -i --max-time 10 -X POST "$APIM_URL/sherpa/mcp" `
    -H "Authorization: Bearer $TOKEN" `
    -H "Content-Type: application/json" `
    -H "Accept: application/json, text/event-stream" `
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":0}'
$SESSION_ID = ($INIT_RESPONSE -split "`n" | Select-String -Pattern "mcp-session-id" | Select-Object -First 1).ToString() -replace '.*:\s*', '' | ForEach-Object { $_.Trim() }
Write-Host "Session: $SESSION_ID"
Write-Host ""

$TESTS_PASSED = 0
$TESTS_FAILED = 0

Write-Host "Test 1: Shell Injection (command separator)"
Write-Host "-------------------------------------------"
Write-Host "Payload: 'summit; cat /etc/passwd'"
Write-Host ""

try {
    $response = curl.exe -s -w "`n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" `
        -H "Authorization: Bearer $TOKEN" `
        -H "Content-Type: application/json" `
        -H "Accept: application/json, text/event-stream" `
        -H "Mcp-Session-Id: $SESSION_ID" `
        -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_weather","arguments":{"location":"summit; cat /etc/passwd"}}}' 2>$null
    $lines = $response -split "`n"
    $HTTP_CODE = $lines[-1]
    $BODY = ($lines[0..($lines.Length - 2)]) -join "`n"
} catch {
    $HTTP_CODE = "000"
    $BODY = ""
}

Write-Host "  Status: $HTTP_CODE"
if ($HTTP_CODE -eq "400") {
    Write-Host "  Result: BLOCKED - Shell injection detected!"
    Write-Host "  Response: $BODY"
    $TESTS_PASSED++
} else {
    Write-Host "  Result: NOT BLOCKED - Test failed"
    Write-Host "  Response: $BODY"
    $TESTS_FAILED++
}
Write-Host ""

Write-Host "Test 2: Path Traversal"
Write-Host "----------------------"
Write-Host "Payload: '../../etc/passwd'"
Write-Host ""

try {
    $response = curl.exe -s -w "`n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" `
        -H "Authorization: Bearer $TOKEN" `
        -H "Content-Type: application/json" `
        -H "Accept: application/json, text/event-stream" `
        -H "Mcp-Session-Id: $SESSION_ID" `
        -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"check_trail_conditions","arguments":{"trail_id":"../../etc/passwd"}}}' 2>$null
    $lines = $response -split "`n"
    $HTTP_CODE = $lines[-1]
    $BODY = ($lines[0..($lines.Length - 2)]) -join "`n"
} catch {
    $HTTP_CODE = "000"
    $BODY = ""
}

Write-Host "  Status: $HTTP_CODE"
if ($HTTP_CODE -eq "400") {
    Write-Host "  Result: BLOCKED - Path traversal detected!"
    Write-Host "  Response: $BODY"
    $TESTS_PASSED++
} else {
    Write-Host "  Result: NOT BLOCKED - Test failed"
    Write-Host "  Response: $BODY"
    $TESTS_FAILED++
}
Write-Host ""

Write-Host "Test 3: SQL Injection"
Write-Host "---------------------"
Write-Host "Payload: `"' OR '1'='1`""
Write-Host ""

try {
    $response = curl.exe -s -w "`n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" `
        -H "Authorization: Bearer $TOKEN" `
        -H "Content-Type: application/json" `
        -H "Accept: application/json, text/event-stream" `
        -H "Mcp-Session-Id: $SESSION_ID" `
        -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_weather","arguments":{"location":"Denver'' OR ''1''=''1"}}}' 2>$null
    $lines = $response -split "`n"
    $HTTP_CODE = $lines[-1]
    $BODY = ($lines[0..($lines.Length - 2)]) -join "`n"
} catch {
    $HTTP_CODE = "000"
    $BODY = ""
}

Write-Host "  Status: $HTTP_CODE"
if ($HTTP_CODE -eq "400") {
    Write-Host "  Result: BLOCKED - SQL injection detected!"
    Write-Host "  Response: $BODY"
    $TESTS_PASSED++
} else {
    Write-Host "  Result: NOT BLOCKED - Test failed"
    Write-Host "  Response: $BODY"
    $TESTS_FAILED++
}
Write-Host ""

Write-Host "Test 4: Safe Request (should pass)"
Write-Host "-----------------------------------"
Write-Host "Payload: 'Denver, Colorado'"
Write-Host ""

try {
    $response = curl.exe -s -w "`n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" `
        -H "Authorization: Bearer $TOKEN" `
        -H "Content-Type: application/json" `
        -H "Accept: application/json, text/event-stream" `
        -H "Mcp-Session-Id: $SESSION_ID" `
        -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"get_weather","arguments":{"location":"Denver, Colorado"}}}' 2>$null
    $lines = $response -split "`n"
    $HTTP_CODE = $lines[-1]
    $BODY = ($lines[0..($lines.Length - 2)]) -join "`n"
} catch {
    $HTTP_CODE = "000"
    $BODY = ""
}

Write-Host "  Status: $HTTP_CODE"
if ($HTTP_CODE -eq "200") {
    Write-Host "  Result: PASSED - Safe request allowed"
    $TESTS_PASSED++
} else {
    Write-Host "  Result: BLOCKED - Test failed (false positive)"
    Write-Host "  Response: $BODY"
    $TESTS_FAILED++
}
Write-Host ""

Write-Host "=========================================="
Write-Host "Test Results"
Write-Host "=========================================="
Write-Host ""
Write-Host "  Passed: $TESTS_PASSED"
Write-Host "  Failed: $TESTS_FAILED"
Write-Host ""

if ($TESTS_FAILED -eq 0) {
    Write-Host "All technical injection tests passed!"
    Write-Host ""
    Write-Host "Layer 2 (input_check function) is successfully:"
    Write-Host "  - Detecting shell injection patterns"
    Write-Host "  - Detecting path traversal attempts"
    Write-Host "  - Detecting SQL injection patterns"
    Write-Host "  - Allowing legitimate requests"
} else {
    Write-Host "Some tests failed. Check the security function logs."
}

Write-Host ""
Write-Host "Next: Validate PII redaction"
Write-Host "  ./scripts/1.3-validate-pii.ps1"
Write-Host ""
