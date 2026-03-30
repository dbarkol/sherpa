# Verify Protected Resource Metadata (PRM) endpoint
$ErrorActionPreference = 'Stop'

Write-Host "=============================================="
Write-Host "Camp 1: Verify PRM Endpoint"
Write-Host "=============================================="
Write-Host ""

# Get secure server URL from environment
$SECURE_URL = azd env get-value SECURE_SERVER_URL 2>$null

if (-not $SECURE_URL) {
    Write-Host "❌ Error: SECURE_SERVER_URL not found"
    Write-Host "   Make sure you've deployed the secure server with 'azd deploy --service secure-server'"
    exit 1
}

Write-Host "Secure Server URL: $SECURE_URL"
Write-Host ""

# Test PRM endpoint
Write-Host "Testing PRM endpoint..."
Write-Host "GET ${SECURE_URL}/.well-known/oauth-protected-resource"
Write-Host ""

$response = curl.exe -s -w "`n%{http_code}" "${SECURE_URL}/.well-known/oauth-protected-resource"
$lines = $response -split "`n"
$HTTP_STATUS = $lines[-1]
$BODY = ($lines[0..($lines.Length - 2)]) -join "`n"

if ($HTTP_STATUS -ne "200") {
    Write-Host "❌ PRM endpoint returned HTTP $HTTP_STATUS"
    Write-Host ""
    Write-Host "Response:"
    Write-Host $BODY
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  1. Verify the secure server is deployed"
    Write-Host "  2. Check that AZURE_TENANT_ID and AZURE_CLIENT_ID are set in the Container App"
    Write-Host "  3. Redeploy with: azd deploy --service secure-server"
    exit 1
}

Write-Host "✅ PRM endpoint is working!"
Write-Host ""
Write-Host "Response:"
try {
    $BODY | ConvertFrom-Json | ConvertTo-Json -Depth 10
} catch {
    Write-Host $BODY
}

# Validate JSON structure
$prmObj = $BODY | ConvertFrom-Json
$RESOURCE = $prmObj.resource
$AUTH_SERVER = $prmObj.authorization_servers[0]
$SCOPE = $prmObj.scopes_supported[0]

Write-Host ""
Write-Host "=============================================="
Write-Host "PRM Configuration Summary"
Write-Host "=============================================="
Write-Host "Resource:           $RESOURCE"
Write-Host "Authorization Server: $AUTH_SERVER"
Write-Host "Required Scope:     $SCOPE"
Write-Host "Bearer Method:      header"
Write-Host ""

if ($AUTH_SERVER -match "login.microsoftonline.com") {
    Write-Host "✅ Authorization server is Entra ID"
} else {
    Write-Host "⚠️  Warning: Authorization server doesn't look like Entra ID"
}

if ($SCOPE -match "^api://") {
    Write-Host "✅ Scope format is correct (api://...)"
} else {
    Write-Host "⚠️  Warning: Scope format unexpected"
}

Write-Host ""
Write-Host "VS Code can now discover authentication requirements automatically!"
Write-Host ""
Write-Host "Add to .vscode/mcp.json:"
Write-Host "{"
Write-Host "  `"mcpServers`": {"
Write-Host "    `"camp1-secure`": {"
Write-Host "      `"type`": `"sse`","
Write-Host "      `"url`": `"${SECURE_URL}/mcp`""
Write-Host "    }"
Write-Host "  }"
Write-Host "}"
Write-Host ""
Write-Host "=============================================="
