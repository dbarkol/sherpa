# Waypoint 3.1: Fix - Apply IP Restrictions
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 3.1: Apply IP Restrictions"
Write-Host "=========================================="
Write-Host ""

$RG = azd env get-value AZURE_RESOURCE_GROUP
$APIM_URL = azd env get-value APIM_GATEWAY_URL

Write-Host "Note: APIM Basic v2 Limitation"
Write-Host "------------------------------"
Write-Host ""
Write-Host "APIM Basic v2 does not have static outbound IPs."
Write-Host "This demo uses the current IP, which may change."
Write-Host ""
Write-Host "For production, consider:"
Write-Host "  - APIM Standard v2 with VNet integration"
Write-Host "  - Private Endpoints for full network isolation"
Write-Host "  - Header-based validation (X-Azure-FDID)"
Write-Host ""

# Get APIM IP by resolving the gateway hostname
Write-Host "Resolving APIM gateway IP..."
$APIM_HOST = $APIM_URL -replace "https://", "" -replace "http://", "" -replace "/.*", ""
$dnsResult = Resolve-DnsName $APIM_HOST -Type A -ErrorAction SilentlyContinue
$APIM_IP = ($dnsResult | Where-Object { $_.QueryType -eq "A" } | Select-Object -First 1).IPAddress

if (-not $APIM_IP) {
    Write-Host "Error: Could not resolve APIM IP address"
    exit 1
}

Write-Host "APIM Gateway: $APIM_HOST"
Write-Host "APIM IP: $APIM_IP"
Write-Host ""

Write-Host "Applying Container Apps IP restrictions..."
Write-Host ""

# Get Container App names
$SHERPA_CA = az containerapp list `
    --resource-group $RG `
    --query "[?contains(name, 'sherpa')].name" -o tsv 2>$null | Select-Object -First 1
$TRAIL_CA = az containerapp list `
    --resource-group $RG `
    --query "[?contains(name, 'trail')].name" -o tsv 2>$null | Select-Object -First 1

if ($SHERPA_CA) {
    Write-Host "Configuring: $SHERPA_CA"

    # Allow APIM IP (everything else is implicitly denied)
    az containerapp ingress access-restriction set `
        --resource-group $RG `
        --name $SHERPA_CA `
        --rule-name "allow-apim" `
        --action "Allow" `
        --ip-address "$APIM_IP/32" `
        --description "Allow APIM gateway" `
        --output none

    Write-Host "  ✓ Allow APIM ($APIM_IP)"
    Write-Host "  ✓ All other IPs implicitly denied"
}

if ($TRAIL_CA) {
    Write-Host "Configuring: $TRAIL_CA"

    # Allow APIM IP (everything else is implicitly denied)
    az containerapp ingress access-restriction set `
        --resource-group $RG `
        --name $TRAIL_CA `
        --rule-name "allow-apim" `
        --action "Allow" `
        --ip-address "$APIM_IP/32" `
        --description "Allow APIM gateway" `
        --output none

    Write-Host "  ✓ Allow APIM ($APIM_IP)"
    Write-Host "  ✓ All other IPs implicitly denied"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "IP Restrictions Applied (Workshop Demo)"
Write-Host "=========================================="
Write-Host ""
Write-Host "For production environments, see:"
Write-Host "  docs/network-concepts.md"
Write-Host ""
Write-Host "Options for full network isolation:"
Write-Host "  1. APIM Standard v2 + VNet integration"
Write-Host "  2. Private Endpoints"
Write-Host "  3. Azure Front Door + header validation"
Write-Host ""
Write-Host "Next: Validate the fix"
Write-Host "  ./scripts/3.1-validate.ps1"
Write-Host ""
