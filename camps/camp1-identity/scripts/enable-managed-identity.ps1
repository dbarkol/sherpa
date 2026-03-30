# Camp 1: Enable Managed Identity
$ErrorActionPreference = 'Stop'

Write-Host "Camp 1: Enable Managed Identity"
Write-Host "=================================="

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
if (-not $env:AZURE_MANAGED_IDENTITY_PRINCIPAL_ID) {
    Write-Host "Error: AZURE_MANAGED_IDENTITY_PRINCIPAL_ID not found in azd environment."
    Write-Host "Make sure you've run 'azd provision' first."
    exit 1
}

Write-Host "Managed Identity Principal ID: $env:AZURE_MANAGED_IDENTITY_PRINCIPAL_ID"
Write-Host ""

Write-Host "🔍 Verifying Key Vault role assignment..."
$SUBSCRIPTION_ID = az account show --query id -o tsv
az role assignment list `
    --assignee $env:AZURE_MANAGED_IDENTITY_PRINCIPAL_ID `
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$env:AZURE_RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$env:AZURE_KEY_VAULT_NAME" `
    --query "[?roleDefinitionName=='Key Vault Secrets User'].{Role:roleDefinitionName, Scope:scope}" `
    -o table

Write-Host ""
Write-Host "Managed Identity setup complete!"
Write-Host "The Container App can now access Key Vault secrets without passwords."
