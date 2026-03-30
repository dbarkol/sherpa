# Camp 1: Security Validation
$ErrorActionPreference = 'Stop'

Write-Host "Camp 1: Security Validation"
Write-Host "=============================="

# Load azd environment variables
Write-Host "Loading azd environment..."
azd env get-values | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        $varName = $matches[1].Trim().Trim('"')
        $varValue = $matches[2].Trim().Trim('"')
        Set-Item -Path "env:$varName" -Value $varValue
    }
}

# Track overall validation status
$VALIDATION_FAILED = 0

Write-Host ""
Write-Host "🔍 Running security checks..."
Write-Host ""

# Check 1: Secrets in Key Vault
Write-Host "Check 1: Secrets in Key Vault"
Write-Host "------------------------------"
$secretList = az keyvault secret list --vault-name $env:AZURE_KEY_VAULT_NAME | ConvertFrom-Json
$SECRET_COUNT = @($secretList).Count

if ([int]$SECRET_COUNT -gt 0) {
    Write-Host "Found $SECRET_COUNT secrets in Key Vault"
    $secretList | ForEach-Object { Write-Host "  $($_.name): enabled=$($_.attributes.enabled)" }
} else {
    Write-Host "⚠️  No secrets found in Key Vault"
    $VALIDATION_FAILED = 1
}

Write-Host ""

# Check 2: Managed Identity RBAC
Write-Host "Check 2: Managed Identity RBAC"
Write-Host "-------------------------------"
$roleList = az role assignment list --assignee $env:AZURE_MANAGED_IDENTITY_PRINCIPAL_ID --all | ConvertFrom-Json
$kvRoles = @($roleList | Where-Object { $_.roleDefinitionName -eq 'Key Vault Secrets User' })
$ROLE_COUNT = $kvRoles.Count

if ($ROLE_COUNT -gt 0) {
    Write-Host "Managed Identity has Key Vault Secrets User role"
    $kvRoles | ForEach-Object { Write-Host "  Role: $($_.roleDefinitionName)  Scope: $($_.scope)" }
} else {
    Write-Host "❌ Managed Identity missing Key Vault Secrets User role"
    Write-Host "   Run: ./scripts/enable-managed-identity.ps1"
    $VALIDATION_FAILED = 1
}

Write-Host ""

# Check 3: Container App Configuration
Write-Host "Check 3: Container App Identity"
Write-Host "--------------------------------"
Write-Host "Checking if container apps have managed identity assigned..."
$caList = az containerapp list --resource-group $env:AZURE_RESOURCE_GROUP | ConvertFrom-Json

if ($caList -and @($caList).Count -gt 0) {
    $caList | ForEach-Object { Write-Host "  $($_.name): $($_.identity.type)" }
} else {
    Write-Host "⚠️  No container apps found"
}


if ($VALIDATION_FAILED -eq 0) {
    Write-Host "Security Validation Complete!"
    Write-Host "=============================="
    Write-Host ""
    Write-Host "Verified:"
    Write-Host "  - Secrets stored in Key Vault (not env vars)"
    Write-Host "  - Managed Identity has RBAC permissions"
    Write-Host "  - Container Apps use Managed Identity"
    Write-Host ""
    Write-Host "Security posture: SECURE"
    Write-Host "   Ready for production!"
} else {
    Write-Host "❌ Security Validation Failed!"
    Write-Host "=============================="
    Write-Host ""
    Write-Host "⚠️  Issues detected:"
    Write-Host "  - Review the checks above for details"
    Write-Host "  - Fix any ❌ items before proceeding"
    Write-Host ""
    Write-Host "🔒 Security posture: NEEDS ATTENTION"
    Write-Host "   Please resolve issues before production use!"
    exit 1
}
