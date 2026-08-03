param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot,

    [switch]$RemoveVault,

    [switch]$RemoveLogs,

    [switch]$RemoveLauncher
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($HalfLifeRoot)
$amxxRoot = Join-Path $root "valve\addons\amxmodx"
$pluginsIni = Join-Path $amxxRoot "configs\plugins.ini"

$targets = @(
    (Join-Path $amxxRoot "plugins\hldm_trap.amxx"),
    (Join-Path $amxxRoot "plugins\hldm_detector.amxx"),
    (Join-Path $amxxRoot "configs\plugins\hldm_trap.cfg"),
    (Join-Path $amxxRoot "configs\plugins\hldm_detector.cfg")
)

if (Test-Path $pluginsIni -PathType Leaf) {
    $backup = "$pluginsIni.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
    Copy-Item $pluginsIni $backup -Force

    $filtered = @(
        Get-Content $pluginsIni |
            Where-Object {
                $_ -notmatch '^\s*hldm_trap\.amxx(?:\s+debug)?\s*$' -and
                $_ -notmatch '^\s*hldm_detector\.amxx(?:\s+debug)?\s*$' -and
                $_ -notmatch '^\s*;\s*HLDM Anticheat:'
            }
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($pluginsIni, $filtered, $utf8NoBom)
    Write-Host "plugins.ini backup: $backup"
}

foreach ($target in $targets) {
    Remove-Item $target -Force -ErrorAction SilentlyContinue
}

if ($RemoveVault) {
    $vaultDirectory = Join-Path $amxxRoot "data\vault"
    Get-ChildItem $vaultDirectory -Filter "hldm_trap_targets*" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "Persistent trap vault removed."
}

if ($RemoveLogs) {
    $logDirectory = Join-Path $amxxRoot "logs"
    Get-ChildItem $logDirectory -Filter "hldm_anticheat_events.log*" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "Detector logs removed."
}

if ($RemoveLauncher) {
    Remove-Item (Join-Path $root "run_hldm_anticheat_server.bat") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $root "valve\hldm_anticheat_server.cfg") -Force -ErrorAction SilentlyContinue
}

Write-Host "HLDM Anticheat plugins removed. Metamod and AMX Mod X were left installed."
Write-Host "Restart the server or change the map."
