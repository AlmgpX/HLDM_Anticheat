param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$valveRoot = Join-Path $HalfLifeRoot "valve"
$amxxRoot = Join-Path $valveRoot "addons\amxmodx"
$pluginSource = Join-Path $repoRoot "build\hldm_trap.amxx"
$configSource = Join-Path $repoRoot "configs\plugins\hldm_trap.cfg"
$pluginTarget = Join-Path $amxxRoot "plugins\hldm_trap.amxx"
$configDirectory = Join-Path $amxxRoot "configs\plugins"
$configTarget = Join-Path $configDirectory "hldm_trap.cfg"
$pluginsIni = Join-Path $amxxRoot "configs\plugins.ini"

foreach ($required in @($valveRoot, $amxxRoot, $pluginSource, $configSource, $pluginsIni)) {
    if (-not (Test-Path $required)) {
        throw "Required path does not exist: $required"
    }
}

New-Item -ItemType Directory -Path (Split-Path $pluginTarget -Parent) -Force | Out-Null
New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null

$backup = "$pluginsIni.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $pluginsIni $backup -Force
Copy-Item $pluginSource $pluginTarget -Force
Copy-Item $configSource $configTarget -Force

$lines = [System.Collections.Generic.List[string]](Get-Content $pluginsIni)
if (-not ($lines -match '^\s*hldm_trap\.amxx(?:\s+debug)?\s*$')) {
    $lines.Add("hldm_trap.amxx")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($pluginsIni, $lines, $utf8NoBom)
}

Write-Host "Installed plugin: $pluginTarget"
Write-Host "Installed AutoExecConfig file: $configTarget"
Write-Host "Backup: $backup"
Write-Host "Restart the server or change the map, then run: amxx plugins"
