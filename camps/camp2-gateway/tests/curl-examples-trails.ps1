# ==============================================================================
# Trails MCP Server - curl Request Examples
# ==============================================================================
# This file demonstrates how to make HTTP requests to the Trails MCP server
# using curl. MCP servers use JSON-RPC 2.0 over Streamable HTTP transport.
#
# IMPORTANT: MCP's Streamable HTTP transport requires:
#   1. Initialize a session first (get mcp-session-id header)
#   2. Include mcp-session-id in all subsequent requests
#   3. Include Accept header for both application/json and text/event-stream
#
# AUTHENTICATION:
#   The Trails MCP server behind APIM requires OAuth 2.0 authentication.
#   Set the MCP_TOKEN environment variable before running this script:
#
#   Option 1: Get token via PKCE flow (interactive browser login)
#     . ./scripts/get-mcp-token.ps1 -Pkce -Export
#     ./tests/curl-examples-trails.ps1
#
#   Option 2: Set token directly
#     $env:MCP_TOKEN = "your-oauth-token"
#     ./tests/curl-examples-trails.ps1
#
# Available Tools:
#   - list-trails()                    - List all available trails
#   - get-trail(trailId)               - Get detailed trail information
#   - check-conditions(trailId)        - Check current trail conditions
#   - get-permit(permitId)             - Retrieve an existing permit
#   - request-permit(trailId, hikerName, date) - Request a new trail permit
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
$TRAIL_SUBSCRIPTION_KEY = (azd env get-value TRAIL_SUBSCRIPTION_KEY 2>$null) | Out-String
$TRAIL_SUBSCRIPTION_KEY = $TRAIL_SUBSCRIPTION_KEY.Trim()

# Validate that we have required values
if (-not $APIM_GATEWAY_URL) {
    Write-Host "ERROR: APIM_GATEWAY_URL not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

if (-not $TRAIL_SUBSCRIPTION_KEY) {
    Write-Host "ERROR: TRAIL_SUBSCRIPTION_KEY not found in azd environment."
    Write-Host "Make sure you've run 'azd up' first."
    exit 1
}

$MCP_ENDPOINT = "$APIM_GATEWAY_URL/trails/mcp"

# Acquire OAuth token
if (-not $env:MCP_TOKEN) {
    if ($MCP_APP_CLIENT_ID) {
        Write-Host "Acquiring OAuth token via Azure CLI..."
        $TENANT_ID = az account show --query tenantId -o tsv 2>$null
        $TOKEN_RESULT = ""
        try {
            $TOKEN_RESULT = az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>&1
        } catch { }

        # JWT tokens start with "ey", check if we got one
        if (-not $TOKEN_RESULT -or -not $TOKEN_RESULT.StartsWith("ey")) {
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
$APIM_KEY_HEADER = $TRAIL_SUBSCRIPTION_KEY

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
Write-Host "Trails MCP Server - curl Examples"
Write-Host "=========================================="
Write-Host "Endpoint: $MCP_ENDPOINT"
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 1: Initialize Session (Optional for APIM-native MCP)
# ------------------------------------------------------------------------------

Write-Host "=== Step 1: Initialize MCP Session ==="
Write-Host "Sending initialize request..."

$INIT_RESPONSE = ""
try {
    $INIT_RESPONSE = curl.exe -s -D - -X POST $MCP_ENDPOINT `
        --max-time 5 `
        -H "Content-Type: application/json" `
        -H "Accept: $ACCEPT_HEADER" `
        -H "Ocp-Apim-Subscription-Key: $APIM_KEY_HEADER" `
        -H "Authorization: $AUTH_HEADER" `
        -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl-example","version":"1.0"}},"id":1}' 2>$null
} catch { }

# Extract session ID from headers (may be empty for APIM native MCP)
$SESSION_ID = ""
if ($INIT_RESPONSE -match "(?i)mcp-session-id:\s*(\S+)") {
    $SESSION_ID = $Matches[1].Trim()
}

if ($SESSION_ID) {
    Write-Host "Session initialized!"
    Write-Host "Session ID: $SESSION_ID"
} else {
    Write-Host "Initialized (stateless mode - no session ID required)"
}

# Check if initialization succeeded
if ($INIT_RESPONSE -match "protocolVersion") {
    Write-Host "Server: Azure API Management MCP"
} else {
    Write-Host "WARNING: Unexpected initialize response"
    $INIT_RESPONSE -split "`n" | Select-Object -Last 5 | ForEach-Object { Write-Host $_ }
}
Write-Host ""

# Build session header args for curl
$sessionArgs = @()
if ($SESSION_ID) {
    $sessionArgs = @("-H", "mcp-session-id: $SESSION_ID")
}

# ------------------------------------------------------------------------------
# STEP 2: List Available Tools
# ------------------------------------------------------------------------------

Write-Host "=== Step 2: List Available Tools ==="
$RESPONSE = ""
try {
    $RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
        --max-time 5 `
        -H "Content-Type: application/json" `
        -H "Accept: $ACCEPT_HEADER" `
        -H "Ocp-Apim-Subscription-Key: $APIM_KEY_HEADER" `
        -H "Authorization: $AUTH_HEADER" `
        @sessionArgs `
        -d '{"jsonrpc":"2.0","method":"tools/list","id":2}' 2>$null
} catch { }

$lines = $RESPONSE -split "`n" | Where-Object { $_ -match "^data:" }
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
# STEP 3: Call list-trails Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 3: Call list-trails Tool ==="
Write-Host "Request: list-trails()"
Write-Host "Response:"
$RESPONSE = ""
try {
    $RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
        --max-time 5 `
        -H "Content-Type: application/json" `
        -H "Accept: $ACCEPT_HEADER" `
        -H "Ocp-Apim-Subscription-Key: $APIM_KEY_HEADER" `
        -H "Authorization: $AUTH_HEADER" `
        @sessionArgs `
        -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list-trails","arguments":{}},"id":3}' 2>$null
} catch { }
Write-Host (Parse-SseResponse $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 4: Call get-trail Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 4: Call get-trail Tool ==="
Write-Host 'Request: get-trail(trailId="summit-trail")'
Write-Host "Response:"
$RESPONSE = ""
try {
    $RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
        --max-time 5 `
        -H "Content-Type: application/json" `
        -H "Accept: $ACCEPT_HEADER" `
        -H "Ocp-Apim-Subscription-Key: $APIM_KEY_HEADER" `
        -H "Authorization: $AUTH_HEADER" `
        @sessionArgs `
        -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get-trail","arguments":{"trailId":"summit-trail"}},"id":4}' 2>$null
} catch { }
Write-Host (Parse-SseResponse $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 5: Call check-conditions Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 5: Call check-conditions Tool ==="
Write-Host 'Request: check-conditions(trailId="summit-trail")'
Write-Host "Response:"
$RESPONSE = ""
try {
    $RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
        --max-time 5 `
        -H "Content-Type: application/json" `
        -H "Accept: $ACCEPT_HEADER" `
        -H "Ocp-Apim-Subscription-Key: $APIM_KEY_HEADER" `
        -H "Authorization: $AUTH_HEADER" `
        @sessionArgs `
        -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check-conditions","arguments":{"trailId":"summit-trail"}},"id":5}' 2>$null
} catch { }
Write-Host (Parse-SseResponse $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 6: Call request-permit Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 6: Call request-permit Tool ==="
Write-Host "(Note: APIM MCP POST body handling has limitations - see REST API for full functionality)"
Write-Host 'Request: request-permit(body={"trail_id":"summit-trail",...})'
Write-Host "Response:"
$RESPONSE = ""
try {
    $RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
        --max-time 5 `
        -H "Content-Type: application/json" `
        -H "Accept: $ACCEPT_HEADER" `
        -H "Ocp-Apim-Subscription-Key: $APIM_KEY_HEADER" `
        -H "Authorization: $AUTH_HEADER" `
        @sessionArgs `
        -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"request-permit","arguments":{"body":"{\"trail_id\":\"summit-trail\",\"hiker_name\":\"John Doe\",\"hiker_email\":\"john@example.com\",\"planned_date\":\"2026-03-15\"}"}},"id":6}' 2>$null
} catch { }

$PERMIT_RESPONSE = Parse-SseResponse $RESPONSE
if ($PERMIT_RESPONSE -match "detail") {
    Write-Host "(Expected: APIM MCP body parameter limitation)"
} else {
    Write-Host $PERMIT_RESPONSE
}
Write-Host ""

# Try to extract permit ID for the next step
$PERMIT_ID = ""
try {
    $permitObj = $PERMIT_RESPONSE | ConvertFrom-Json
    if ($permitObj.permit.id) {
        $PERMIT_ID = $permitObj.permit.id
    }
} catch { }

# ------------------------------------------------------------------------------
# STEP 7: Call get-permit Tool
# ------------------------------------------------------------------------------

Write-Host "=== Step 7: Call get-permit Tool ==="
if (-not $PERMIT_ID) {
    $PERMIT_ID = "PRM-2025-0001"
    Write-Host "(Using existing demo permit)"
}
Write-Host "Request: get-permit(permitId=`"$PERMIT_ID`")"
Write-Host "Response:"

$body = @{
    jsonrpc = "2.0"
    method = "tools/call"
    params = @{
        name = "get-permit"
        arguments = @{
            permitId = $PERMIT_ID
        }
    }
    id = 7
} | ConvertTo-Json -Depth 5 -Compress

$RESPONSE = ""
try {
    $RESPONSE = curl.exe -s -X POST $MCP_ENDPOINT `
        --max-time 5 `
        -H "Content-Type: application/json" `
        -H "Accept: $ACCEPT_HEADER" `
        -H "Ocp-Apim-Subscription-Key: $APIM_KEY_HEADER" `
        -H "Authorization: $AUTH_HEADER" `
        @sessionArgs `
        -d $body 2>$null
} catch { }
Write-Host (Parse-SseResponse $RESPONSE)
Write-Host ""

Write-Host "=========================================="
Write-Host "All examples completed!"
Write-Host "=========================================="

# ------------------------------------------------------------------------------
# QUICK REFERENCE: One-liner Examples
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "=== Quick Reference: Copy-Paste Commands ==="
Write-Host @"

# NOTE: Replace `$env:MCP_TOKEN with your actual OAuth token
# Get a token first: . ./scripts/get-mcp-token.ps1 -Pkce -Export
# APIM native MCP is stateless - no session ID required

# Initialize (optional for APIM native MCP):
curl.exe -s -X POST "$MCP_ENDPOINT" --max-time 5 ``
  -H "Content-Type: application/json" ``
  -H "Accept: application/json, text/event-stream" ``
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" ``
  -H "Authorization: Bearer `$env:MCP_TOKEN" ``
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}},"id":1}'

# List all trails:
curl.exe -s -X POST "$MCP_ENDPOINT" --max-time 5 ``
  -H "Content-Type: application/json" ``
  -H "Accept: application/json, text/event-stream" ``
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" ``
  -H "Authorization: Bearer `$env:MCP_TOKEN" ``
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list-trails","arguments":{}},"id":2}'

# Get trail details:
curl.exe -s -X POST "$MCP_ENDPOINT" --max-time 5 ``
  -H "Content-Type: application/json" ``
  -H "Accept: application/json, text/event-stream" ``
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" ``
  -H "Authorization: Bearer `$env:MCP_TOKEN" ``
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get-trail","arguments":{"trailId":"summit-trail"}},"id":3}'

# Check trail conditions:
curl.exe -s -X POST "$MCP_ENDPOINT" --max-time 5 ``
  -H "Content-Type: application/json" ``
  -H "Accept: application/json, text/event-stream" ``
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" ``
  -H "Authorization: Bearer `$env:MCP_TOKEN" ``
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check-conditions","arguments":{"trailId":"summit-trail"}},"id":4}'

# Request a permit:
curl.exe -s -X POST "$MCP_ENDPOINT" --max-time 5 ``
  -H "Content-Type: application/json" ``
  -H "Accept: application/json, text/event-stream" ``
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" ``
  -H "Authorization: Bearer `$env:MCP_TOKEN" ``
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"request-permit","arguments":{"body":"{\"trail_id\":\"summit-trail\",\"hiker_name\":\"John Doe\",\"hiker_email\":\"john@example.com\",\"planned_date\":\"2026-03-15\"}"}},"id":5}'

# Get permit by ID (existing permits: PRM-2025-0001, PRM-2025-0002):
curl.exe -s -X POST "$MCP_ENDPOINT" --max-time 5 ``
  -H "Content-Type: application/json" ``
  -H "Accept: application/json, text/event-stream" ``
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" ``
  -H "Authorization: Bearer `$env:MCP_TOKEN" ``
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get-permit","arguments":{"permitId":"PRM-2025-0001"}},"id":6}'
"@
