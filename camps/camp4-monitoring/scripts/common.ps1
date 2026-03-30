# =============================================================================
# Camp 4 - Common Functions and Environment Setup
# =============================================================================
# Dot-source this file in other scripts:
#   . "$PSScriptRoot\common.ps1"
# =============================================================================

$ErrorActionPreference = 'Stop'

# Ensure the correct azd environment is active based on local .azure/config.json.
# Fixes session bleed-over when AZURE_ENV_NAME env var is inherited from another camp.
function Resolve-AzdEnvironment {
    $configFile = Join-Path (Get-Location) ".azure\config.json"
    if (Test-Path $configFile) {
        $localDefault = (Get-Content $configFile | ConvertFrom-Json).defaultEnvironment
        if ($localDefault -and $env:AZURE_ENV_NAME -ne $localDefault) {
            if ($env:AZURE_ENV_NAME) {
                Write-Host "Note: Overriding AZURE_ENV_NAME '$($env:AZURE_ENV_NAME)' with local default '$localDefault'" -ForegroundColor DarkYellow
            }
            $env:AZURE_ENV_NAME = $localDefault
        }
        Write-Host "Using azd environment: $localDefault" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Load environment variables from azd
function Load-Env {
    Resolve-AzdEnvironment

    $script:APIM_GATEWAY_URL = azd env get-value APIM_GATEWAY_URL 2>$null
    $script:WORKSPACE_ID = azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>$null
    $script:RG_NAME = azd env get-value AZURE_RESOURCE_GROUP 2>$null
    $script:APIM_NAME = azd env get-value APIM_NAME 2>$null
    $script:FUNCTION_APP_NAME = azd env get-value FUNCTION_APP_NAME 2>$null
    $script:MCP_APP_CLIENT_ID = azd env get-value MCP_APP_CLIENT_ID 2>$null

    if (-not $script:APIM_GATEWAY_URL -or $script:APIM_GATEWAY_URL -like "ERROR:*") {
        Write-Host "Error: APIM_GATEWAY_URL not found. Run 'azd up' first." -ForegroundColor Red
        return $false
    }
    return $true
}

# Get OAuth token for MCP API calls
function Get-OAuthToken {
    if (-not $script:MCP_APP_CLIENT_ID) {
        Write-Host "Error: MCP_APP_CLIENT_ID not found. Run 'azd up' first." -ForegroundColor Red
        return $false
    }

    $script:TOKEN = az account get-access-token --resource "$script:MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>$null
    if (-not $script:TOKEN) {
        Write-Host "Error: Could not get access token. Check Azure CLI login." -ForegroundColor Red
        return $false
    }
    Write-Host "✓ OAuth token acquired" -ForegroundColor Green
    return $true
}

# Initialize MCP session and get session ID
function Initialize-McpSession {
    $headersFile = Join-Path $env:TEMP "mcp-headers.txt"

    try {
        curl.exe -s -D $headersFile --max-time 10 -X POST "$script:APIM_GATEWAY_URL/sherpa/mcp" `
            -H "Authorization: Bearer $script:TOKEN" `
            -H "Content-Type: application/json" `
            -H "Accept: application/json, text/event-stream" `
            -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"camp4-test","version":"1.0"}},"id":1}' 2>$null | Out-Null
    } catch { }

    $script:SESSION_ID = $null
    if (Test-Path $headersFile) {
        $headerLine = Get-Content $headersFile | Select-String -Pattern "mcp-session-id" -CaseSensitive:$false | Select-Object -First 1
        if ($headerLine) {
            $script:SESSION_ID = ($headerLine.ToString() -replace '.*:\s*', '').Trim()
        }
    }
    if (-not $script:SESSION_ID) {
        $script:SESSION_ID = "session-$(Get-Date -UFormat %s)"
    }
}

# Send MCP tool call through APIM
# Usage: Send-McpCall -ToolName <name> -Arguments <json> [-RequestId <id>]
function Send-McpCall {
    param(
        [string]$ToolName,
        [string]$Arguments,
        [int]$RequestId = 1
    )

    $response = curl.exe -s -w "`n%{http_code}" --max-time 15 -X POST "$script:APIM_GATEWAY_URL/sherpa/mcp" `
        -H "Authorization: Bearer $script:TOKEN" `
        -H "Content-Type: application/json" `
        -H "Accept: application/json, text/event-stream" `
        -H "Mcp-Session-Id: $script:SESSION_ID" `
        -d "{`"jsonrpc`":`"2.0`",`"method`":`"tools/call`",`"params`":{`"name`":`"$ToolName`",`"arguments`":$Arguments},`"id`":$RequestId}"

    return ($response -split "`n")[-1]
}

# Send attack payload (simplified for testing)
# Usage: Send-AttackPayload -ToolName <name> -ArgName <arg> -Payload <payload>
function Send-AttackPayload {
    param(
        [string]$ToolName,
        [string]$ArgName,
        [string]$Payload
    )

    # Escape the payload for JSON
    $escapedPayload = $Payload -replace '\\', '\\\\' -replace '"', '\"'

    Send-McpCall -ToolName $ToolName -Arguments "{`"$ArgName`":`"$escapedPayload`"}"
}
