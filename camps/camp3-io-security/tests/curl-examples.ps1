# ==============================================================================
# Trails MCP Server - curl Request Examples
# ==============================================================================
# This file demonstrates how to make HTTP requests to the Trails MCP server
# through APIM gateway using curl. MCP servers use JSON-RPC 2.0 over
# Streamable HTTP transport.
#
# IMPORTANT: MCP's Streamable HTTP transport requires:
#   1. Initialize a session first (get mcp-session-id header)
#   2. Include mcp-session-id in all subsequent requests
#   3. Include Accept header for both application/json and text/event-stream
#   4. Include OAuth Bearer token for authentication
#
# Available Tools:
#   - list-trails                   - List all available trails
#   - get-trail(trail_id)           - Get details for a specific trail
#   - check-conditions(trail_id)    - Check trail conditions and hazards
#   - get-permit(permit_id)         - Get permit details by ID
#   - request-permit(...)           - Request a new trail permit
# ==============================================================================

# Note: We don't use $ErrorActionPreference = 'Stop' because curl with SSE may
# timeout while the response data is actually received (APIM keeps connections open).

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $ScriptDir "..")

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Trails MCP Server - curl Examples" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Load from azd environment (matches other camp3 scripts)
$APIM_GATEWAY_URL = azd env get-value APIM_GATEWAY_URL
$MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID

if (-not $APIM_GATEWAY_URL) {
    Write-Host "ERROR: APIM_GATEWAY_URL not found." -ForegroundColor Red
    Write-Host "Run 'azd up' first to deploy the infrastructure."
    exit 1
}

if (-not $MCP_APP_CLIENT_ID) {
    Write-Host "ERROR: MCP_APP_CLIENT_ID not found." -ForegroundColor Red
    Write-Host "Run 'azd up' first to deploy the infrastructure."
    exit 1
}

# The trails MCP endpoint through APIM
$MCP_ENDPOINT = "$APIM_GATEWAY_URL/trails/mcp"

# Required headers for MCP Streamable HTTP transport
$ACCEPT_HEADER = "Accept: application/json, text/event-stream"
$CONTENT_TYPE = "Content-Type: application/json"

Write-Host "APIM Gateway: $APIM_GATEWAY_URL"
Write-Host "MCP Endpoint: $MCP_ENDPOINT"
Write-Host ""

# ------------------------------------------------------------------------------
# Get OAuth Token
# ------------------------------------------------------------------------------
Write-Host "Getting OAuth token..." -ForegroundColor Blue
$TOKEN = az account get-access-token --resource $MCP_APP_CLIENT_ID --query accessToken -o tsv 2>$null

if (-not $TOKEN) {
    Write-Host "ERROR: Could not get access token." -ForegroundColor Red
    Write-Host "Make sure you're logged in: az login"
    exit 1
}
Write-Host "✓ OAuth token acquired" -ForegroundColor Green
Write-Host ""

# Helper function to parse SSE response and extract JSON result
function Parse-Response {
    param([string]$Response)
    $dataLines = ($Response -split "`n") | Where-Object { $_ -match "^data:" }
    if ($dataLines) {
        $json = ($dataLines | Select-Object -First 1) -replace "^data:\s*", ""
        try {
            $parsed = $json | ConvertFrom-Json
            if ($parsed.result.content) {
                return ($parsed.result.content[0].text | ConvertFrom-Json | ConvertTo-Json -Depth 10)
            } elseif ($parsed.result) {
                return ($parsed.result | ConvertTo-Json -Depth 10)
            } else {
                return ($parsed | ConvertTo-Json -Depth 10)
            }
        } catch {
            return $json
        }
    }
    return $Response
}

# ------------------------------------------------------------------------------
# STEP 1: Create Session ID
# ------------------------------------------------------------------------------
# Trail MCP is APIM-synthesized (REST API exposed as MCP).
# APIM accepts client-provided Mcp-Session-Id for rate limiting/tracking.
# We don't need to call initialize - just generate a session ID.

Write-Host "=== Step 1: Create Session ID ===" -ForegroundColor Cyan
$SESSION_ID = "session-$(Get-Date -UFormat %s)"
Write-Host "Trail MCP uses client-generated session IDs"
Write-Host "  Session ID: $SESSION_ID"
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 2: List Available Tools
# ------------------------------------------------------------------------------
Write-Host "=== Step 2: List Available Tools ===" -ForegroundColor Cyan

$RESPONSE = curl.exe -s --max-time 5 -X POST $MCP_ENDPOINT `
    -H "Authorization: Bearer $TOKEN" `
    -H $CONTENT_TYPE `
    -H $ACCEPT_HEADER `
    -H "Mcp-Session-Id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

Write-Host "Available tools:"
$dataLines = ($RESPONSE -split "`n") | Where-Object { $_ -match "^data:" } | Select-Object -First 1
if ($dataLines) {
    $json = $dataLines -replace "^data:\s*", ""
    try {
        $parsed = $json | ConvertFrom-Json
        foreach ($tool in $parsed.result.tools) {
            $desc = ($tool.description -split "`n")[0]
            Write-Host "  - $($tool.name): $desc"
        }
    } catch {
        Write-Host $RESPONSE
    }
} else {
    Write-Host $RESPONSE
}
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 3: Call list-trails Tool
# ------------------------------------------------------------------------------
Write-Host "=== Step 3: Call list-trails Tool ===" -ForegroundColor Cyan
Write-Host "Request: list-trails"
Write-Host "Response:"

$RESPONSE = curl.exe -s --max-time 5 -X POST $MCP_ENDPOINT `
    -H "Authorization: Bearer $TOKEN" `
    -H $CONTENT_TYPE `
    -H $ACCEPT_HEADER `
    -H "Mcp-Session-Id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list-trails","arguments":{}},"id":3}'

Write-Host (Parse-Response $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 4: Call get-trail Tool
# ------------------------------------------------------------------------------
Write-Host "=== Step 4: Call get-trail Tool ===" -ForegroundColor Cyan
Write-Host "Request: get-trail(trailId=`"summit-trail`")"
Write-Host "Response:"

$RESPONSE = curl.exe -s --max-time 5 -X POST $MCP_ENDPOINT `
    -H "Authorization: Bearer $TOKEN" `
    -H $CONTENT_TYPE `
    -H $ACCEPT_HEADER `
    -H "Mcp-Session-Id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get-trail","arguments":{"trailId":"summit-trail"}},"id":4}'

Write-Host (Parse-Response $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 5: Call check-conditions Tool
# ------------------------------------------------------------------------------
Write-Host "=== Step 5: Call check-conditions Tool ===" -ForegroundColor Cyan
Write-Host "Request: check-conditions(trailId=`"summit-trail`")"
Write-Host "Response:"

$RESPONSE = curl.exe -s --max-time 5 -X POST $MCP_ENDPOINT `
    -H "Authorization: Bearer $TOKEN" `
    -H $CONTENT_TYPE `
    -H $ACCEPT_HEADER `
    -H "Mcp-Session-Id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check-conditions","arguments":{"trailId":"summit-trail"}},"id":5}'

Write-Host (Parse-Response $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 6: Call get-permit Tool
# ------------------------------------------------------------------------------
Write-Host "=== Step 6: Call get-permit Tool ===" -ForegroundColor Cyan
Write-Host "Request: get-permit(permitId=`"TRAIL-2024-001`")"
Write-Host "Response:"

$RESPONSE = curl.exe -s --max-time 5 -X POST $MCP_ENDPOINT `
    -H "Authorization: Bearer $TOKEN" `
    -H $CONTENT_TYPE `
    -H $ACCEPT_HEADER `
    -H "Mcp-Session-Id: $SESSION_ID" `
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get-permit","arguments":{"permitId":"TRAIL-2024-001"}},"id":6}'

Write-Host (Parse-Response $RESPONSE)
Write-Host ""

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  All examples completed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
