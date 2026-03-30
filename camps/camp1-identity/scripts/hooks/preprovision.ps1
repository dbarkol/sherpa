# Preprovision hook for Camp 1
# Generates a unique resource suffix to avoid soft-delete conflicts

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "=========================================="
Write-Host "Camp 1: Pre-provision Setup"
Write-Host "=========================================="
Write-Host ""

# ============================================
# Generate unique resource suffix
# ============================================
# This suffix is generated once per environment and stored.
# - Re-running azd up uses the same suffix (idempotent)
# - Deleting .azure/ folder and starting fresh generates a new suffix
#   (avoids soft-delete conflicts with Key Vault and other services)
if (-not $env:RESOURCE_SUFFIX) {
    # Generate a 5-character alphanumeric suffix
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    $RESOURCE_SUFFIX = -join (1..5 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    Write-Host "Generated new resource suffix: $RESOURCE_SUFFIX"
    azd env set RESOURCE_SUFFIX $RESOURCE_SUFFIX
} else {
    $RESOURCE_SUFFIX = $env:RESOURCE_SUFFIX
    Write-Host "Using existing resource suffix: $RESOURCE_SUFFIX"
}

# Sync AZURE_LOCATION with resource group location if RG already exists
# This ensures Bicep uses the same location as the resource group
if ($env:AZURE_RESOURCE_GROUP) {
    $RG_LOCATION = az group show -n $env:AZURE_RESOURCE_GROUP --query location -o tsv 2>$null
    if ($RG_LOCATION -and $RG_LOCATION -ne $env:AZURE_LOCATION) {
        Write-Host "Syncing AZURE_LOCATION to resource group location: $RG_LOCATION"
        azd env set AZURE_LOCATION $RG_LOCATION
        $env:AZURE_LOCATION = $RG_LOCATION
    }
}

Write-Host ""
Write-Host "Pre-provision complete. Resource suffix: $RESOURCE_SUFFIX"
Write-Host ""
