# Waypoint 1.3: No separate deploy - rate limiting will be added via fix script
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.3: Rate Limiting"
Write-Host "=========================================="
Write-Host ""
Write-Host "No separate deployment needed for this waypoint."
Write-Host "Rate limiting is a policy applied to existing APIs."
Write-Host ""
Write-Host "Next: See why rate limiting is critical"
Write-Host "  ./scripts/1.3-exploit.ps1"
Write-Host ""
