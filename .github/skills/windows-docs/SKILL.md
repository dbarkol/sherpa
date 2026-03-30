---
name: windows-docs
description: "Add OS-specific tabs to MkDocs documentation for Windows/PowerShell support. Use when: updating docs with Bash/PowerShell tabs, adding Windows instructions to workshop guides, converting documentation for cross-platform support, mkdocs content tabs for OS-specific commands."
argument-hint: "Specify the doc file or camp docs folder, e.g., 'docs/camps/camp3-io-security/'"
---

# Windows Documentation Tabs

Add `=== "Bash"` / `=== "PowerShell"` content tabs to MkDocs Material documentation so Windows users see PowerShell equivalents. Camp 2 docs (`docs/camps/camp2-gateway/`) are the completed reference — use them as the template.

## When to Use

- After converting a camp's `.sh` scripts to `.ps1` (using the `/windows-scripts` skill)
- Adding cross-platform tabs to workshop documentation
- Updating doc files that reference shell scripts or shell-specific commands

## Procedure

### Step 1: Identify Docs to Update

Find all documentation files for the target camp:

```
docs/camps/<camp>/*.md
docs/camps/<camp>/**/*.md
```

### Step 2: Find Script References

Search each doc file for bash code blocks that reference camp scripts or use shell-specific commands:

**Must be tabbed** (shell-specific):
- `./scripts/*.sh` → needs `./scripts/*.ps1` tab
- `grep` → needs `Select-String` tab  
- `azd env get-values | grep ...` → needs `| Select-String ...` tab
- Variable assignment with `$()` subshells → needs PowerShell equivalent
- `cat`, `cut`, `sed`, `awk` piped commands
- Entra ID app deletion with Bash variable capture

**Do NOT tab** (cross-platform, same syntax):
- `azd provision`, `azd up`, `azd down`, `azd deploy`
- `azd env get-value SINGLE_VAR` (no pipes)
- `az account show`, `az login`
- `git clone`, `cd`, `docker` commands
- JSON/YAML/XML code blocks
- Expected output blocks (just showing text)

### Step 3: Apply Tabs

Wrap each shell-specific code block in content tabs. See the [tab patterns reference](./references/tab-patterns.md) for exact syntax at every indentation level.

**Critical rules:**

1. **Indentation matters** — tabs inside admonitions (`???`, `!!!`, `???+`) need extra 4-space indent per nesting level
2. **Blank line required** between `=== "Bash"` and `=== "PowerShell"` blocks
3. **Code block indent** must be 4 spaces deeper than the `===` line
4. **No blank line** between `===` line and its code fence

### Step 4: Add Windows Tip

Add a tip callout on the camp's main index page (if not already present):

```markdown
!!! tip "Windows Users"
    All scripts in this camp have PowerShell equivalents (`.ps1`). When you see `./scripts/X.sh`, you can run `./scripts/X.ps1` instead.
```

Or for sections with a working directory tip:

```markdown
!!! tip "Working Directory"
    All commands in this section should be run from the `camps/<camp>` directory:
    ```bash
    cd camps/<camp>
    ```
    **Windows users:** Each `.sh` script has a `.ps1` equivalent. Use `./scripts/X.ps1` instead of `./scripts/X.sh`.
```

### Step 5: Verify

1. Check that all script references have tabs
2. Check indentation alignment (especially inside admonitions)
3. Confirm cross-platform commands (azd, az, git) are NOT tabbed
4. Optionally, run `mkdocs serve` to preview locally

## Reference Implementation

See `docs/camps/camp2-gateway/` for the complete reference:
- [index.md](docs/camps/camp2-gateway/index.md) — provisioning commands, grep→Select-String, Windows tip
- [section1-gateway-governance.md](docs/camps/camp2-gateway/section1-gateway-governance.md) — 10 tabbed script references, working directory tip
- [section2-content-safety.md](docs/camps/camp2-gateway/section2-content-safety.md) — 2 tabbed script references inside admonitions
- [section3-network-security.md](docs/camps/camp2-gateway/section3-network-security.md) — cleanup commands with variable capture
- [api-governance.md](docs/camps/camp2-gateway/api-governance.md) — single script reference tabbed

## Quick Reference

See the full [tab patterns reference](./references/tab-patterns.md) for before/after examples at every indentation level.
