# MkDocs Material Tab Patterns

Exact syntax patterns for adding OS-specific content tabs to MkDocs Material documentation. Indentation is critical — incorrect indentation silently breaks rendering.

## Basic Tab Syntax

The `===` markers create content tabs. Each tab needs:
- `===` followed by a space and quoted tab title
- Code block indented 4 spaces from the `===` line
- Blank line between tabs

## Pattern 1: Top-Level (No Nesting)

Script references or commands at the top level of a document (not inside any admonition).

**Before:**
```markdown
Run the exploit script:

` ` ` bash
./scripts/1.3-exploit.sh
` ` `
```

**After:**
```markdown
Run the exploit script:

=== "Bash"
    ` ` ` bash
    ./scripts/1.3-exploit.sh
    ` ` `

=== "PowerShell"
    ` ` ` powershell
    ./scripts/1.3-exploit.ps1
    ` ` `
```

## Pattern 2: Inside an Admonition (4-space indent)

Script references inside `???+`, `???`, or `!!!` blocks. The tab syntax gets 4 extra spaces.

**Before:**
```markdown
???+ note "Step 1: Deploy"

    Deploy the server:

    ` ` ` bash
    ./scripts/1.1-deploy.sh
    ` ` `
```

**After:**
```markdown
???+ note "Step 1: Deploy"

    Deploy the server:

    === "Bash"
        ` ` ` bash
        ./scripts/1.1-deploy.sh
        ` ` `

    === "PowerShell"
        ` ` ` powershell
        ./scripts/1.1-deploy.ps1
        ` ` `
```

## Pattern 3: Inside a Nested Admonition (8-space indent)

When inside `???` nested within another `???`:

**After:**
```markdown
???+ note "Step 2"

    ??? info "Details"

        Run the script:

        === "Bash"
            ` ` ` bash
            ./scripts/1.1-deploy.sh
            ` ` `

        === "PowerShell"
            ` ` ` powershell
            ./scripts/1.1-deploy.ps1
            ` ` `
```

## Pattern 4: grep → Select-String

When the bash code uses `grep` for filtering (common with `azd env get-values`):

**Before:**
```markdown
` ` ` bash
azd env get-values | grep -E "APIM_GATEWAY_URL|MCP_APP_CLIENT_ID"
` ` `
```

**After:**
```markdown
=== "Bash"
    ` ` ` bash
    azd env get-values | grep -E "APIM_GATEWAY_URL|MCP_APP_CLIENT_ID"
    ` ` `

=== "PowerShell"
    ` ` ` powershell
    azd env get-values | Select-String "APIM_GATEWAY_URL|MCP_APP_CLIENT_ID"
    ` ` `
```

## Pattern 5: Variable Capture (Bash subshell → PowerShell)

When the bash code captures command output into variables:

**Before:**
```markdown
` ` ` bash
MCP_APP_ID=$(azd env get-value MCP_APP_CLIENT_ID)
APIM_APP_ID=$(azd env get-value APIM_CLIENT_APP_ID)

az ad app delete --id $MCP_APP_ID
az ad app delete --id $APIM_APP_ID
` ` `
```

**After:**
```markdown
=== "Bash"
    ` ` ` bash
    MCP_APP_ID=$(azd env get-value MCP_APP_CLIENT_ID)
    APIM_APP_ID=$(azd env get-value APIM_CLIENT_APP_ID)

    az ad app delete --id $MCP_APP_ID
    az ad app delete --id $APIM_APP_ID
    ` ` `

=== "PowerShell"
    ` ` ` powershell
    $MCP_APP_ID = azd env get-value MCP_APP_CLIENT_ID
    $APIM_APP_ID = azd env get-value APIM_CLIENT_APP_ID

    az ad app delete --id $MCP_APP_ID
    az ad app delete --id $APIM_APP_ID
    ` ` `
```

## Pattern 6: Verify Setup (chained commands)

**Before:**
```markdown
` ` ` bash
az account show && azd version && docker --version
` ` `
```

**After:**
```markdown
=== "Bash"
    ` ` ` bash
    az account show && azd version && docker --version
    ` ` `

=== "PowerShell"
    ` ` ` powershell
    az account show; azd version; docker --version
    ` ` `
```

## Pattern 7: Multi-line with Line Continuation

When bash uses `\` for continuation and PowerShell needs `` ` ``:

**Before:**
```markdown
` ` ` bash
az containerapp ingress access-restriction set \
  --name sherpa-mcp-server \
  --resource-group $RG \
  --rule-name "allow-apim" \
  --ip-address "${APIM_IP}/32" \
  --action Allow
` ` `
```

**After:**
```markdown
=== "Bash"
    ` ` ` bash
    az containerapp ingress access-restriction set \
      --name sherpa-mcp-server \
      --resource-group $RG \
      --rule-name "allow-apim" \
      --ip-address "${APIM_IP}/32" \
      --action Allow
    ` ` `

=== "PowerShell"
    ` ` ` powershell
    az containerapp ingress access-restriction set `
      --name sherpa-mcp-server `
      --resource-group $RG `
      --rule-name "allow-apim" `
      --ip-address "$APIM_IP/32" `
      --action Allow
    ` ` `
```

## Do NOT Tab These

These commands work identically on both platforms — no tabs needed:

```markdown
` ` ` bash
# Cross-platform commands (DO NOT TAB):
azd provision
azd up
azd down --force --purge
azd deploy
azd env get-value SINGLE_VAR_NAME
az account show
az login
git clone https://github.com/...
cd sherpa/camps/camp2-gateway
docker --version
```

## Indentation Summary

| Context | `===` indent | Code fence indent |
|---------|-------------|-------------------|
| Top-level | 0 spaces | 4 spaces |
| Inside `!!!`/`???`/`???+` | 4 spaces | 8 spaces |
| Inside nested admonition | 8 spaces | 12 spaces |

**Rule:** The code fence is always 4 spaces deeper than the `===` line.

## Note on Code Fence Examples

The code fences in this reference file use `` ` ` ` `` with spaces for escaping purposes. In actual documentation, use standard triple backticks with no spaces: ` ``` `.
