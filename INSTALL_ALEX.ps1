$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$halfLifeRoot = "E:\SteamLibrary\steamapps\common\Half-Life"
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$setup = Join-Path $packageRoot "deploy\setup_hldm_complete_windows.ps1"

if (-not (Test-Path $setup -PathType Leaf)) {
    throw "Installer not found: $setup"
}

if (-not (Test-Path (Join-Path $halfLifeRoot "hlds.exe") -PathType Leaf)) {
    throw "hlds.exe not found in $halfLifeRoot"
}

$rconFile = Join-Path $halfLifeRoot "RCON_PASSWORD.txt"
$rcon = [guid]::NewGuid().ToString("N")
$rcon | Set-Content -LiteralPath $rconFile -Encoding ASCII

& $setup `
    -HalfLifeRoot $halfLifeRoot `
    -RconPassword $rcon `
    -Hostname "AlexMerqury_DM_Server" `
    -Port 27015 `
    -MaxPlayers 16 `
    -OpenFirewall `
    -StartServer

Write-Host ""
Write-Host "DONE"
Write-Host "Server: AlexMerqury_DM_Server"
Write-Host "Player password: none"
Write-Host "RCON password saved to: $rconFile"
Write-Host "Join locally with: connect 127.0.0.1:27015"
