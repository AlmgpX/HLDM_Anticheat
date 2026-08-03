$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$halfLifeRoot = "E:\SteamLibrary\steamapps\common\Half-Life"
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$adminInstaller = Join-Path $packageRoot "deploy\install_admin_tools_windows.ps1"
$launcher = Join-Path $halfLifeRoot "run_hldm_anticheat_server.bat"
$serverCfg = Join-Path $halfLifeRoot "valve\hldm_anticheat_server.cfg"

foreach ($required in @($adminInstaller, $launcher, $serverCfg)) {
    if (-not (Test-Path $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

& $adminInstaller -HalfLifeRoot $halfLifeRoot

$cfgLines = @(
    Get-Content $serverCfg |
        Where-Object {
            $_ -notmatch '^\s*hostname\s+' -and
            $_ -notmatch '^\s*sv_password\s+' -and
            $_ -notmatch '^\s*sv_lan\s+'
        }
)
$cfgLines += 'hostname "AlexMerqury_DM_Server"'
$cfgLines += 'sv_password ""'
$cfgLines += 'sv_lan "0"'
if (-not ($cfgLines -match '^\s*mp_consistency\s+"?1"?\s*$')) {
    $cfgLines += 'mp_consistency "1"'
}

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($serverCfg, $cfgLines, $encoding)

Write-Host ""
Write-Host "Admin tools finished."
Write-Host "Server: AlexMerqury_DM_Server"
Write-Host "Player password: none"
Write-Host "Starting: $launcher"

Start-Process -FilePath $launcher -WorkingDirectory $halfLifeRoot
