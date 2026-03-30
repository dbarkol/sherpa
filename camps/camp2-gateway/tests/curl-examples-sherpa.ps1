# ==============================================================================
# Sherpa MCP Server - curl Request Examples (via APIM)
# ==============================================================================
# This file demonstrates how to make HTTP requests to the Sherpa MCP server
# through Azure API Management using curl. MCP servers use JSON-RPC 2.0 over
# Streamable HTTP transport.
#
# IMPORTANT: MCP's Streamable HTTP transport requires:
#   1. Initialize a session first (get mcp-session-id header)
#   2. Include mcp-session-id in all subsequent requests
#   3. Include Accept header for both application/json and text/event-stream
#   4. Include Authorization header with OAuth token (for APIM)
#
# Available Tools:
#   - get_weather(location)         - Get weather conditions
#   - check_trail_conditions(trail_id) - Check trail status
#   - get_gear_recommendations(condition_type) - Get gear list
# ==============================================================================

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Load from azd environment
$APIM_GATEWAY_URL = (azd env get-value APIM_GATEWAY_URL 2>$null) | Out-String
$APIM_GATEWAY_URL = $APIM_GATEWAY_URL.Trim()
$MCP_APP_CLIENT_ID = (azd env get-value MCP_APP_CLIENT_ID 2>$null) | Out-String
$MCP_APP_CLIENT_ID = $MCP_APP_CLIENT_ID.Trim()

# Validate that we have APIM URL
if (-not $APIM_GATEWAY_URL) {
    Write-Host "ERROR: APIM_GATEWAY_URL not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

$MCP_ENDPOINT = "$APIM_GATEWAY_URL/sherpa/mcp"

# Acquire OAuth token
if (-not $env:MCP_TOKEN) {
    if ($MCP_APP_CLIENT_ID) {
        Write-Host "Acquiring OAuth token via Azure CLI..."
        $TOKEN_RESULT = ""
        try {
            $TOKEN_RESULT = az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>&1
        } catch { }

        # JWT tokens start with "ey", check if we got one
        if (-not $TOKEN_RESULT -or -not $TOKEN_RESULT.StartsWith("ey")) {
            $TENANT_ID = az account show --query tenantId -o tsv 2>$null
            Write-Host ""
            Write-Host "Interactive consent required. Run these commands first:"
            Write-Host ""
            Write-Host "  az logout"
            Write-Host "  az login --tenant `"$TENANT_ID`" --scope `"$MCP_APP_CLIENT_ID/.default`""
            Write-Host ""
            Write-Host "Then run this script again."
            exit 1
        }
        $env:MCP_TOKEN = $TOKEN_RESULT
        Write-Host "OAuth token acquired"
        Write-Host ""
    } else {
        Write-Host "ERROR: MCP_APP_CLIENT_ID not found in azd environment."
        exit 1
    }
}

# Required headers for MCP Streamable HTTP transport
$ACCEPT_HEADER = "application/json, text/event-stream"
$AUTH_HEADER = "Bearer $($env:MCP_TOKEN)"

# Helper function to parse SSE response and extract JSON result
function Parse-SseResponse {
    param([string]$Response)
    $lines = $Response -split "`n" | Where-Object { $_ -match "^data:" -and $_ -notmatch "\[DONE\]" }
    if ($lines) {
        $jsonStr = ($lines | Select-Object -First 1) -replace "^data:\s*", ""
        try {
            $obj = $jsonStr | ConvertFrom-Json
            if ($obj.result.content -and $obj.result.content[0].text) {
                return $obj.result.content[0].text
            } elseif ($obj.result) {
                return ($obj.result | ConvertTo-Json -Depth 10)
            }
            return $jsonStr
        } catch {
            return $jsonStr
        }
    }
    return $Response
}

Write-Host "=========================================="
Write-Host "Sherpa MCP Server - curl Examples (via APIM)"
Write-Host "=========================================="
Write-Host "Endpoint: $MCP_ENDPOINT"
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 1: Initialize Session (REQUIRED)
# ------------------------------------------------------------------------------

Write-Host "=== Step 1: Initialize MCP Session ==="
Write-Host "Sending initialize request..."

$headerFile = Join-Path $env:TEMP "sherpa_headers_$(Get-Random).txt"

$INIT_RESPONSE = curl.exe -s -D $headerFile -X POST $MCP_ENDPOINT `
    -H "Content-Type: application/json" `
    -H "Accept: $ACCEPT_HEADER" `
    -H "Authorization: $AUTH_HEADER" `
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl-example","version":"1.0"}},"id":1}'

# Extract session ID from headers
$SESSION_ID = ""
if (Test-Path $headerFile) {
    $headerContent = Get-Content $headerFile -Raw
    if ($headerContent -match "(?i)mcp-session-id:\s*(\S+)") {
        $SESSION_ID = $Matches[1].Trim()
    }
    Remove-Item $headerFile -ErrorAction SilentlyContinue
}

if (-not $SESSION_ID) {
    Write-Host "ERROR: Failed to get session ID from server"
    Write-Host "Response:"
    Write-Host $INIT_RESPONSE
    exit 1
}

Write-Host "Session initialized!"
Write-Host "Session ID: $SESSION_ID"
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 2: List Available Tools
# ------------------------------------------------------------------------------

Write-Host "=== Step 2: List Available Tools ==="
$RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
    -H "Content-Type: application/json" `
    -H "Accept: $ACCEPT_HEADER" `
    -H "Authorization: $AUTH_HEADER" `
    -H "mcp-session-id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'

$lines = $RESPONSE -split "`n" | Where-Object { $_ -match "^data:" -and $_ -notmatch "\[DONE\]" }
foreach ($line in $lines) {
    $jsonStr = $line -replace "^data:\s*", ""
    try {
        $obj = $jsonStr | ConvertFrom-Json
        foreach ($tool in $obj.result.tools) {
            $desc = ($tool.description -split "`n")[0]
            Write-Host "  - $($tool.name): $desc"
        }
    } catch {
        Write-Host $jsonStr
    }
}
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 3: Call get_weather Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 3: Call get_weather Tool ==="
Write-Host 'Request: get_weather(location="summit")'
Write-Host "Response:"
$RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
    -H "Content-Type: application/json" `
    -H "Accept: $ACCEPT_HEADER" `
    -H "Authorization: $AUTH_HEADER" `
    -H "mcp-session-id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"summit"}},"id":3}'
Write-Host (Parse-SseResponse $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 4: Call check_trail_conditions Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 4: Call check_trail_conditions Tool ==="
Write-Host 'Request: check_trail_conditions(trail_id="summit-trail")'
Write-Host "Response:"
$RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
    -H "Content-Type: application/json" `
    -H "Accept: $ACCEPT_HEADER" `
    -H "Authorization: $AUTH_HEADER" `
    -H "mcp-session-id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check_trail_conditions","arguments":{"trail_id":"summit-trail"}},"id":4}'
Write-Host (Parse-SseResponse $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 5: Call get_gear_recommendations Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 5: Call get_gear_recommendations Tool ==="
Write-Host 'Request: get_gear_recommendations(condition_type="winter")'
Write-Host "Response:"
$RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
    -H "Content-Type: application/json" `
    -H "Accept: $ACCEPT_HEADER" `
    -H "Authorization: $AUTH_HEADER" `
    -H "mcp-session-id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_gear_recommendations","arguments":{"condition_type":"winter"}},"id":5}'
Write-Host (Parse-SseResponse $RESPONSE)
Write-Host ""
Write-Host "=========================================="
Write-Host "All examples completed!"
