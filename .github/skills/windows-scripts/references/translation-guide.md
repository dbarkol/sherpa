# Bash → PowerShell Translation Guide

Comprehensive translation reference for converting Bash scripts to PowerShell. All patterns have been validated in the Camp 2 reference implementation (`camps/camp2-gateway/`).

## Error Handling

| Bash | PowerShell | Notes |
|------|------------|-------|
| `set -e` | `$ErrorActionPreference = 'Stop'` | First line of every script |
| `set -euo pipefail` | `$ErrorActionPreference = 'Stop'` | PowerShell has strict mode but `'Stop'` is sufficient |
| `cmd \|\| true` | `try { cmd } catch { }` | Suppress errors from a command |
| `cmd \|\| echo "fail"` | `try { cmd } catch { Write-Host "fail" }` | Handle errors with message |
| `trap 'cleanup' EXIT` | `try { ... } finally { cleanup }` | Cleanup on exit |

## Variables & Environment

| Bash | PowerShell | Notes |
|------|------------|-------|
| `VAR="value"` | `$VAR = "value"` | Local variable |
| `export VAR="value"` | `$env:VAR = "value"` | Environment variable |
| `${VAR}` | `$VAR` or `$($VAR)` in strings | Variable expansion |
| `${VAR:-default}` | `if (-not $VAR) { $VAR = "default" }` | Default value |
| `${VAR:=default}` | `if (-not $env:VAR) { $env:VAR = "default" }` | Set if unset |
| `${!v:-}` (indirect) | `[Environment]::GetEnvironmentVariable($v)` | Indirect variable reference |
| `$(command)` | `$(command)` or `$result = command` | Command substitution |
| `$?` | `$LASTEXITCODE` | Last command exit code |
| `"$VAR"` | `"$VAR"` | String interpolation (same!) |
| `'literal'` | `'literal'` | No interpolation (same!) |

## Command Substitution & Capture

```bash
# Bash
RESULT=$(az account show --query id -o tsv)
```

```powershell
# PowerShell
$RESULT = az account show --query id -o tsv
```

For multi-line or piped output:
```bash
# Bash
RESULT=$(azd env get-value MY_VAR 2>/dev/null || echo "")
```

```powershell
# PowerShell
$RESULT = (azd env get-value MY_VAR 2>$null) | Out-String
$RESULT = $RESULT.Trim()
```

**Important:** `azd env get-value` may return trailing whitespace/newlines. Always `.Trim()` the result.

## Conditionals

| Bash | PowerShell |
|------|------------|
| `if [ -z "$VAR" ]; then` | `if (-not $VAR) {` |
| `if [ -n "$VAR" ]; then` | `if ($VAR) {` |
| `if [ "$A" = "$B" ]; then` | `if ($A -eq $B) {` |
| `if [ "$A" != "$B" ]; then` | `if ($A -ne $B) {` |
| `if [ -f "$FILE" ]; then` | `if (Test-Path $FILE) {` |
| `if [[ "$VAR" == ey* ]]; then` | `if ($VAR.StartsWith("ey")) {` |
| `if echo "$X" \| grep -q "pat"; then` | `if ($X -match "pat") {` |
| `case $VAR in ... esac` | `switch ($VAR) { ... }` |

## Loops

```bash
# Bash - C-style for loop
for i in $(seq 1 20); do echo $i; done

# Bash - range
for i in {1..20}; do echo $i; done
```

```powershell
# PowerShell
for ($i = 1; $i -le 20; $i++) { Write-Host $i }

# Or pipeline style
1..20 | ForEach-Object { Write-Host $_ }
```

```bash
# Bash - iterate array
for item in "${array[@]}"; do echo "$item"; done
```

```powershell
# PowerShell
foreach ($item in $array) { Write-Host $item }
```

## HTTP Requests (curl)

**Critical:** Always use `curl.exe`, not `curl`. PowerShell aliases `curl` to `Invoke-WebRequest`.

| Bash | PowerShell | Notes |
|------|------------|-------|
| `curl -s` | `curl.exe -s` | Always use `.exe` suffix |
| `-H "Header: val"` | `-H "Header: val"` | Same syntax |
| `-d '{"key":"val"}'` | `-d '{"key":"val"}'` | Same syntax for JSON |
| `-D /tmp/headers.txt` | `-D $headerFile` where `$headerFile = Join-Path $env:TEMP "..."` | Temp file path |
| `\` (line continuation) | `` ` `` (backtick) | Different continuation char |

### curl with Line Continuation

```bash
# Bash
curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"key": "value"}'
```

```powershell
# PowerShell
curl.exe -s -X POST $URL `
    -H "Content-Type: application/json" `
    -H "Authorization: Bearer $TOKEN" `
    -d '{"key": "value"}'
```

### Capturing Response Headers

```bash
# Bash
RESPONSE=$(curl -s -D /tmp/headers.txt -X POST "$URL" ...)
SESSION_ID=$(grep -i "mcp-session-id:" /tmp/headers.txt | awk '{print $2}' | tr -d '\r')
```

```powershell
# PowerShell
$headerFile = Join-Path $env:TEMP "headers_$(Get-Random).txt"
$RESPONSE = curl.exe -s -D $headerFile -X POST $URL ...
$SESSION_ID = ""
if (Test-Path $headerFile) {
    $headerContent = Get-Content $headerFile -Raw
    if ($headerContent -match "(?i)mcp-session-id:\s*(\S+)") {
        $SESSION_ID = $Matches[1].Trim()
    }
    Remove-Item $headerFile -ErrorAction SilentlyContinue
}
```

### HTTP Status Code Extraction

```bash
# Bash
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
```

```powershell
# PowerShell
$HTTP_CODE = curl.exe -s -o NUL -w "%{http_code}" $URL
```

## JSON Processing (jq → ConvertFrom-Json)

| Bash (jq) | PowerShell | Notes |
|-----------|------------|-------|
| `echo "$json" \| jq '.field'` | `($json \| ConvertFrom-Json).field` | Access field |
| `echo "$json" \| jq -r '.field'` | `($json \| ConvertFrom-Json).field` | Raw output (default in PS) |
| `echo "$json" \| jq '.arr[0]'` | `($json \| ConvertFrom-Json).arr[0]` | Array index |
| `jq -n '{"key":"val"}'` | `@{key="val"} \| ConvertTo-Json` | Create JSON |
| `jq -n --arg k "$v" '{k: $k}'` | `@{k=$v} \| ConvertTo-Json` | Create with variables |
| `jq -r '.items[] \| .name'` | `($json \| ConvertFrom-Json).items \| ForEach-Object { $_.name }` | Iterate and extract |

### Building Complex JSON

```bash
# Bash with jq -n
BODY=$(jq -n \
    --arg url "$URL" \
    --arg name "$NAME" \
    '{properties: {url: $url, displayName: $name}}')
```

```powershell
# PowerShell
$BODY = @{
    properties = @{
        url = $URL
        displayName = $NAME
    }
} | ConvertTo-Json -Depth 5 -Compress
```

**Important:** Always use `-Depth 5` (or more) with `ConvertTo-Json` — the default depth of 2 truncates nested objects.

## Text Processing

| Bash | PowerShell | Notes |
|------|------------|-------|
| `grep "pattern" file` | `Select-String "pattern" file` | Search in file |
| `echo "$text" \| grep "pat"` | `$text \| Select-String "pat"` | Search in string |
| `grep -i "pat"` | `Select-String "pat"` | Case-insensitive (default in PS) |
| `grep -E "a\|b"` | `Select-String "a\|b"` | Extended regex |
| `grep -c "pat"` | `(Select-String "pat").Count` | Count matches |
| `grep -q "pat"` | `$text -match "pat"` | Boolean test |
| `grep -v "pat"` | `Select-String "pat" -NotMatch` | Invert match |
| `sed 's/old/new/'` | `$text -replace "old","new"` | Regex replace |
| `sed 's/old/new/g'` | `$text -replace "old","new"` | Global replace (default in PS) |
| `tr -d '\r'` | `.Trim()` or `-replace '\r',''` | Strip carriage returns |
| `cut -d'=' -f2` | `.Split('=')[1]` | Field extraction |
| `awk '{print $2}'` | `($line -split '\s+')[1]` | Column extraction |
| `wc -l` | `($text -split "`n").Count` | Line count |
| `head -n 5` | `Select-Object -First 5` | First N items |
| `tail -n 5` | `Select-Object -Last 5` | Last N items |

## File Operations

| Bash | PowerShell |
|------|------------|
| `cat file` | `Get-Content file` or `Get-Content file -Raw` |
| `cat > file <<EOF ... EOF` | `Set-Content -Path file -Value @"..."@` |
| `echo "text" > file` | `"text" \| Set-Content file` |
| `echo "text" >> file` | `"text" \| Add-Content file` |
| `rm file` | `Remove-Item file` |
| `rm -f file` | `Remove-Item file -ErrorAction SilentlyContinue` |
| `mkdir -p dir` | `New-Item -ItemType Directory -Path dir -Force` |
| `cp src dst` | `Copy-Item src dst` |
| `mv src dst` | `Move-Item src dst` |
| `test -f file` | `Test-Path file` |
| `basename "$path"` | `Split-Path $path -Leaf` |
| `dirname "$path"` | `Split-Path $path -Parent` |

### Heredocs → Here-Strings

```bash
# Bash heredoc
cat > /tmp/config.json <<EOF
{
    "key": "${VALUE}",
    "name": "test"
}
EOF
```

```powershell
# PowerShell here-string (with variable expansion)
@"
{
    "key": "$VALUE",
    "name": "test"
}
"@ | Set-Content (Join-Path $env:TEMP "config.json")
```

## Path & Script Location

| Bash | PowerShell |
|------|------------|
| `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` | `$PSScriptRoot` |
| `cd "$SCRIPT_DIR/.."` | `Set-Location "$PSScriptRoot\.."` or `Push-Location` |
| `/tmp/myfile` | `Join-Path $env:TEMP "myfile"` |
| `source ./common.sh` | `. "$PSScriptRoot\common.ps1"` |
| `dirname "${BASH_SOURCE[0]}"` | `$PSScriptRoot` |

## DNS & Network

| Bash | PowerShell |
|------|------------|
| `dig +short A hostname` | `(Resolve-DnsName hostname -Type A).IPAddress` |
| `nslookup hostname` | `Resolve-DnsName hostname` |

## Azure CLI (az)

Azure CLI commands are identical on both platforms. The only differences are in shell-specific surrounding code:

```bash
# Bash
RESULT=$(az account show --query tenantId -o tsv)
```

```powershell
# PowerShell
$RESULT = az account show --query tenantId -o tsv
```

### az rest with JSON bodies

```bash
# Bash — uses jq -n to build JSON
az rest --method PUT --uri "$URI" \
    --body "$(jq -n --arg url "$URL" '{properties: {url: $url}}')"
```

```powershell
# PowerShell — uses ConvertTo-Json
$body = @{
    properties = @{
        url = $URL
    }
} | ConvertTo-Json -Depth 5 -Compress

az rest --method PUT --uri $URI --body $body
```

## Utility Libraries (common.sh → common.ps1)

When a camp has a shared utility file sourced by other scripts:

### Source Pattern

```bash
# Bash - scripts source the common file
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# or
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
```

```powershell
# PowerShell - dot-source the common file
. "$PSScriptRoot\common.ps1"
# or
. "$PSScriptRoot\..\common.ps1"
```

### Color Output

```bash
# Bash colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
echo -e "${GREEN}Success${NC}"
```

```powershell
# PowerShell colors (two approaches)

# Approach 1: Write-Host with -ForegroundColor
Write-Host "Success" -ForegroundColor Green
Write-Host "Error" -ForegroundColor Red
Write-Host "Warning" -ForegroundColor Yellow
Write-Host "Info" -ForegroundColor Cyan

# Approach 2: Helper functions (for utility libraries)
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
```

## SSE (Server-Sent Events) Response Parsing

MCP servers use SSE transport. The bash pattern with `grep/sed/jq` translates to:

```bash
# Bash
parse_response() {
    grep "^data:" | grep -v "\[DONE\]" | sed 's/^data: //' | jq -r '.result.content[0].text // .result // .' 2>/dev/null || cat
}
echo "$RESPONSE" | parse_response
```

```powershell
# PowerShell
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
```

## Parameter/Argument Handling

```bash
# Bash - positional args and flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pkce) USE_PKCE=true; shift ;;
        --json) OUTPUT_FORMAT="json"; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done
```

```powershell
# PowerShell - param block with switches
param(
    [switch]$Pkce,
    [switch]$Json,
    [switch]$Export,
    [switch]$Help
)
```

## Common Patterns Summary

### Required Variable Validation

```bash
# Bash
required_vars=(SUBSCRIPTION_ID RESOURCE_GROUP APIM_NAME)
for v in "${required_vars[@]}"; do
    if [[ -z "${!v:-}" ]]; then
        echo "Missing: $v"; exit 1
    fi
done
```

```powershell
# PowerShell
$requiredVars = @("SUBSCRIPTION_ID", "RESOURCE_GROUP", "APIM_NAME")
foreach ($v in $requiredVars) {
    if (-not [Environment]::GetEnvironmentVariable($v)) {
        Write-Host "Missing: $v"; exit 1
    }
}
```

### Load azd Environment Variables

```bash
# Bash
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null || echo "")
if [ -z "$APIM_GATEWAY_URL" ]; then
    echo "Error: Run 'azd up' first."
    exit 1
fi
```

```powershell
# PowerShell
$APIM_GATEWAY_URL = (azd env get-value APIM_GATEWAY_URL 2>$null) | Out-String
$APIM_GATEWAY_URL = $APIM_GATEWAY_URL.Trim()
if (-not $APIM_GATEWAY_URL) {
    Write-Host "Error: Run 'azd up' first."
    exit 1
}
```
