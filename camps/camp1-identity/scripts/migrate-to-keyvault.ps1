# Camp 1: Migrate Secrets to Key Vault
$ErrorActionPreference = 'Stop'

Write-Host "Camp 1: Migrate Secrets to Key Vault"
Write-Host "======================================="

# Load azd environment variables
Write-Host "Loading azd environment..."
azd env get-values | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        $varName = $matches[1].Trim().Trim('"')
        $varValue = $matches[2].Trim().Trim('"')
        Set-Item -Path "env:$varName" -Value $varValue
    }
}

# Verify we have the necessary variables
if (-not $env:AZURE_KEY_VAULT_NAME) {
    Write-Host "Error: AZURE_KEY_VAULT_NAME not found in azd environment."
    Write-Host "Make sure you've run 'azd provision' first."
    exit 1
}

Write-Host "Creating demo secrets in Key Vault: $env:AZURE_KEY_VAULT_NAME"
Write-Host ""

# Get current user's object ID
$USER_OBJECT_ID = az ad signed-in-user show --query id -o tsv

# Grant current user Key Vault Secrets Officer role to create secrets
Write-Host "Granting you Key Vault Secrets Officer role..."
$SUBSCRIPTION_ID = az account show --query id -o tsv
az role assignment create `
    --role "Key Vault Secrets Officer" `
    --assignee $USER_OBJECT_ID `
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$env:AZURE_RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$env:AZURE_KEY_VAULT_NAME" `
    --output none 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "   (Role assignment already exists)" }

Write-Host "   Waiting for RBAC propagation (10 seconds)..."
Start-Sleep -Seconds 10

# Generate random hex strings for demo secrets
function New-RandomHex {
    param([int]$Length = 8)
    $bytes = [byte[]]::new($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''
}

# Create sample secrets
Write-Host ""
Write-Host "Creating demo-api-key..."
az keyvault secret set `
    --vault-name $env:AZURE_KEY_VAULT_NAME `
    --name "demo-api-key" `
    --value "sk-secure-$(New-RandomHex 8)" `
    --output none

Write-Host "Creating external-service-secret..."
az keyvault secret set `
    --vault-name $env:AZURE_KEY_VAULT_NAME `
    --name "external-service-secret" `
    --value "secret-$(New-RandomHex 8)" `
    --output none

Write-Host ""
Write-Host "Secrets created in Key Vault!"
Write-Host ""
Write-Host "Current secrets:"
az keyvault secret list `
    --vault-name $env:AZURE_KEY_VAULT_NAME `
    --query "[].{Name:name, Enabled:attributes.enabled}" `
    -o table

Write-Host ""
Write-Host "These secrets are now accessible by the secure server via Managed Identity!"
