param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$valveRoot = Join-Path $HalfLifeRoot "valve"
$amxxRoot = Join-Path $valveRoot "addons\amxmodx"
$pluginSource = Join-Path $repoRoot "build\hldm_trap.amxx"
$configSource = Join-Path $repoRoot "configs\hldm_trap.cfg"
$pluginTarget = Join-Path $amxxRoot "plugins\hldm_trap.amxx"
$configTarget = Join-Path $amxxRoot "configs\hldm_trap.cfg"
$pluginsIni = Join-Path $amxxRoot "configs\plugins.ini"

foreach ($required in @($amxxRoot, $pluginSource, $configSource, $pluginsIni)) {
    if (-not (Test-Path $required)) {
        throw "Required path does not exist: $required"
    }
}

$backup = "$pluginsIni.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $pluginsIni $backup -Force
Copy-Item $pluginSource $pluginTarget -Force
Copy-Item $configSource $configTarget -Force

$lines = Get-Content $pluginsIni
if (-not ($lines -match '^\s*hldm_trap\.amxx\s*$')) {
    Add-Content -Path $pluginsIni -Value "`nhldm_trap.amxx"
}

Write-Host "Installed plugin: $pluginTarget"
Write-Host "Installed config: $configTarget"
Write-Host "Backup: $backup"
Write-Host "Restart the server or change the map."
