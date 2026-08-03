param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot,

    [switch]$RemoveVault
)

$ErrorActionPreference = "Stop"
$amxxRoot = Join-Path $HalfLifeRoot "valve\addons\amxmodx"
$pluginTarget = Join-Path $amxxRoot "plugins\hldm_trap.amxx"
$configTarget = Join-Path $amxxRoot "configs\plugins\hldm_trap.cfg"
$pluginsIni = Join-Path $amxxRoot "configs\plugins.ini"
$vaultTarget = Join-Path $amxxRoot "data\vault\hldm_trap_targets.vault"

if (Test-Path $pluginsIni) {
    $backup = "$pluginsIni.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
    Copy-Item $pluginsIni $backup -Force

    $filtered = @(Get-Content $pluginsIni | Where-Object { $_ -notmatch '^\s*hldm_trap\.amxx(?:\s+debug)?\s*$' })
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($pluginsIni, $filtered, $utf8NoBom)
    Write-Host "Backup: $backup"
}

Remove-Item $pluginTarget -Force -ErrorAction SilentlyContinue
Remove-Item $configTarget -Force -ErrorAction SilentlyContinue

if ($RemoveVault) {
    Remove-Item $vaultTarget -Force -ErrorAction SilentlyContinue
    Write-Host "Removed persistent target vault: $vaultTarget"
}

Write-Host "HLDM Trap removed. Restart the server or change the map."
