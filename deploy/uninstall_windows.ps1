param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot
)

$ErrorActionPreference = "Stop"
$amxxRoot = Join-Path $HalfLifeRoot "valve\addons\amxmodx"
$pluginTarget = Join-Path $amxxRoot "plugins\hldm_trap.amxx"
$configTarget = Join-Path $amxxRoot "configs\hldm_trap.cfg"
$pluginsIni = Join-Path $amxxRoot "configs\plugins.ini"

if (Test-Path $pluginsIni) {
    $backup = "$pluginsIni.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
    Copy-Item $pluginsIni $backup -Force
    $filtered = Get-Content $pluginsIni | Where-Object { $_ -notmatch '^\s*hldm_trap\.amxx\s*$' }
    Set-Content -Path $pluginsIni -Value $filtered -Encoding ASCII
    Write-Host "Backup: $backup"
}

Remove-Item $pluginTarget -Force -ErrorAction SilentlyContinue
Remove-Item $configTarget -Force -ErrorAction SilentlyContinue
Write-Host "HLDM Trap removed. Restart the server or change the map."
