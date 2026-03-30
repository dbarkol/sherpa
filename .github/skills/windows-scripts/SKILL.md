---
name: windows-scripts
description: "Convert Bash (.sh) scripts to PowerShell (.ps1) for Windows support. Use when: adding Windows support to a camp, converting shell scripts to PowerShell, creating .ps1 equivalents, translating bash to pwsh, updating azure.yaml hooks for Windows."
argument-hint: "Specify the camp folder to convert, e.g., 'camps/camp3-io-security'"
---

# Windows Script Conversion

Convert Bash scripts to idiomatic PowerShell equivalents for Windows users. Camp 2 (`camps/camp2-gateway/`) is the completed reference implementation — use it as the template for all conversions.

## When to Use

- Adding Windows support to a camp that only has `.sh` scripts
- Converting individual `.sh` files to `.ps1`
- Updating `azure.yaml` hooks to include `windows:` sections
- Translating utility libraries (e.g., `common.sh`) to PowerShell modules

## Procedure

### Step 1: Inventory Scripts

List all `.sh` files in the target camp:

```
camps/<camp>/scripts/**/*.sh
camps/<camp>/tests/**/*.sh
camps/<camp>/samples/**/*.sh
camps/<camp>/exploits/**/*.sh
```

Check which `.ps1` files already exist to avoid duplicating work. Group scripts by type:

| Type | Location | Priority |
|------|----------|----------|
| **Hook scripts** | `scripts/hooks/preprovision.sh`, `postprovision.sh` | Highest — blocks `azd provision` on Windows |
| **Utility libraries** | `scripts/common.sh` or similar | High — other scripts depend on these |
| **Waypoint scripts** | `scripts/{N}.{N}-{action}.sh` | Medium — core workshop flow |
| **Test/sample scripts** | `tests/`, `samples/` | Lower — supplementary |

### Step 2: Translate Utility Libraries First

If the camp has a shared library (e.g., `common.sh` that other scripts `source`), convert it first:

1. Read the `.sh` utility file
2. Translate functions using the [translation guide](./references/translation-guide.md)
3. Replace `source "path/common.sh"` pattern with dot-sourcing: `. "$PSScriptRoot\..\common.ps1"`
4. The PowerShell equivalent should define the same functions with the same names

### Step 3: Translate Each Script

For each `.sh` file, create a `.ps1` file in the same directory:

1. **Read the original** `.sh` script completely
2. **Apply translation rules** from the [translation guide](./references/translation-guide.md)
3. **Preserve the script's structure** — keep the same section headers, comments, and output messages
4. **Use `curl.exe`** (not PowerShell's `curl` alias) to maintain flag compatibility
5. **Keep JSON payloads** as single-line strings in `-d` arguments (avoid multi-line heredocs)
6. **Test mentally** — trace through the logic to confirm correctness

Key rules:
- Start every script with `$ErrorActionPreference = 'Stop'`
- Use `$PSScriptRoot` instead of `BASH_SOURCE` / `SCRIPT_DIR`
- Use `$env:TEMP` instead of `/tmp/`
- Use `ConvertFrom-Json` / `ConvertTo-Json` instead of `jq`
- Use `Select-String` instead of `grep`
- Use `curl.exe` instead of `curl` (PowerShell aliases `curl` to `Invoke-WebRequest`)
- Use backtick (`` ` ``) for line continuation instead of backslash (`\`)

### Step 4: Update azure.yaml Hooks

If the camp has `azure.yaml` with hooks that only reference `.sh` files, add `windows:` sections:

**Before:**
```yaml
hooks:
  preprovision:
    shell: sh
    run: ./scripts/hooks/preprovision.sh
```

**After:**
```yaml
hooks:
  preprovision:
    posix:
      shell: sh
      run: ./scripts/hooks/preprovision.sh
      continueOnError: false
    windows:
      shell: pwsh
      run: ./scripts/hooks/preprovision.ps1
      continueOnError: false
```

### Step 5: Verify

1. Confirm every `.sh` file has a corresponding `.ps1`
2. Confirm `azure.yaml` has `windows:` hook sections
3. Review for common mistakes:
   - `curl` instead of `curl.exe`
   - Missing `$ErrorActionPreference = 'Stop'`
   - Bash-style variable expansion `${VAR}` instead of `$env:VAR` or `$VAR`
   - Using `jq` instead of `ConvertFrom-Json`

## Reference Implementation

See `camps/camp2-gateway/` for the complete reference:
- 27 `.ps1` files covering hooks, waypoints, tests, samples, and a utility script
- `azure.yaml` with proper `posix:`/`windows:` hook sections
- All scripts use idiomatic PowerShell patterns

## Translation Quick Reference

See the full [translation guide](./references/translation-guide.md) for detailed patterns.

| Bash | PowerShell |
|------|------------|
| `set -e` | `$ErrorActionPreference = 'Stop'` |
| `$VAR` / `${VAR}` | `$VAR` |
| `$(command)` | `$(command)` or `$result = command` |
| `export VAR=val` | `$env:VAR = "val"` |
| `"${!v:-}"` (indirect) | `[Environment]::GetEnvironmentVariable($v)` |
| `curl -s ...` | `curl.exe -s ...` |
| `jq '.field'` | `ConvertFrom-Json` then `$obj.field` |
| `jq -n '{...}'` | `@{...} \| ConvertTo-Json` |
| `grep pattern` | `Select-String "pattern"` |
| `grep -E "a\|b"` | `Select-String "a\|b"` |
| `sed 's/a/b/'` | `.Replace("a","b")` or `-replace "a","b"` |
| `awk '{print $2}'` | `.Split()[1]` or `-split '\s+'` |
| `source file.sh` | `. .\file.ps1` |
| `BASH_SOURCE[0]` | `$PSScriptRoot` |
| `/tmp/file` | `Join-Path $env:TEMP "file"` |
| `uuidgen` | `[guid]::NewGuid().ToString()` |
| `date -u` | `(Get-Date).ToUniversalTime().ToString(...)` |
| `cat > file <<EOF` | `Set-Content -Path file -Value @"..."@` |
| `[ -z "$VAR" ]` | `-not $VAR` |
| `[ -n "$VAR" ]` | `$VAR` (truthy check) |
| `echo -e "\033[0;32m..."` | `Write-Host "..." -ForegroundColor Green` |
| `for i in {1..N}` | `for ($i = 1; $i -le $N; $i++)` |
| `cmd \|\| true` | `try { cmd } catch { }` |
| `cmd 2>/dev/null` | `cmd 2>$null` |
| `exit 1` | `exit 1` |
