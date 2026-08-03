$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$halfLifeRoot = "E:\SteamLibrary\steamapps\common\Half-Life"
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installer = Join-Path $packageRoot "deploy\install_admin_tools_windows.ps1"
$steamId = Read-Host "Paste your SteamID (example STEAM_0:1:12345678)"

if ($steamId -notmatch '^STEAM_[0-5]:[01]:\d+$') {
    throw "Invalid SteamID format: $steamId"
}

& $installer -HalfLifeRoot $halfLifeRoot -AdminSteamId $steamId
Write-Host "Admin added. Restart the server, then run exec hldm_admin.cfg in the game console."
