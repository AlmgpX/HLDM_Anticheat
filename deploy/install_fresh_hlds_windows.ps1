param(
    [Parameter(Mandatory = $true)]
    [string]$ServerRoot,

    [string]$SteamCmdRoot = "",

    [string]$RconPassword = "CHANGE_ME_NOW",

    [string]$Hostname = "HLDM Anticheat Trap",

    [ValidateRange(1, 64)]
    [int]$MaxPlayers = 16,

    [ValidateRange(1024, 65535)]
    [int]$Port = 27015,

    [string]$StartMap = "crossfire",

    [switch]$OpenFirewall,

    [switch]$StartServer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$serverPath = [System.IO.Path]::GetFullPath($ServerRoot)

if ([string]::IsNullOrWhiteSpace($SteamCmdRoot)) {
    $SteamCmdRoot = Join-Path (Split-Path $serverPath -Parent) "steamcmd"
}

$steamCmdPath = [System.IO.Path]::GetFullPath($SteamCmdRoot)
$steamCmdExe = Join-Path $steamCmdPath "steamcmd.exe"
$steamCmdZip = Join-Path $env:TEMP "steamcmd_hldm.zip"
$steamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

New-Item -ItemType Directory -Path $serverPath -Force | Out-Null
New-Item -ItemType Directory -Path $steamCmdPath -Force | Out-Null

if (-not (Test-Path $steamCmdExe -PathType Leaf)) {
    Write-Host "Downloading SteamCMD..."
    Invoke-WebRequest -Uri $steamCmdUrl -OutFile $steamCmdZip

    if (-not (Test-Path $steamCmdZip -PathType Leaf) -or (Get-Item $steamCmdZip).Length -le 0) {
        throw "SteamCMD download failed."
    }

    Expand-Archive -Path $steamCmdZip -DestinationPath $steamCmdPath -Force
    Remove-Item $steamCmdZip -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $steamCmdExe -PathType Leaf)) {
    throw "steamcmd.exe was not found after extraction: $steamCmdExe"
}

Write-Host "Installing or updating Half-Life Dedicated Server (AppID 90)..."
& $steamCmdExe `
    +force_install_dir $serverPath `
    +login anonymous `
    +app_set_config 90 mod valve `
    +app_update 90 validate `
    +quit

if ($LASTEXITCODE -ne 0) {
    throw "SteamCMD returned exit code $LASTEXITCODE"
}

$hlds = Join-Path $serverPath "hlds.exe"
if (-not (Test-Path $hlds -PathType Leaf)) {
    throw "SteamCMD completed but hlds.exe was not found: $hlds"
}

$setupScript = Join-Path $PSScriptRoot "setup_hldm_server_windows.ps1"
if (-not (Test-Path $setupScript -PathType Leaf)) {
    throw "Setup script was not found: $setupScript"
}

$arguments = @{
    HalfLifeRoot = $serverPath
    RconPassword = $RconPassword
    Hostname = $Hostname
    MaxPlayers = $MaxPlayers
    Port = $Port
    StartMap = $StartMap
    ForceRuntimeInstall = $true
}

if ($OpenFirewall) {
    $arguments.OpenFirewall = $true
}

if ($StartServer) {
    $arguments.StartServer = $true
}

& $setupScript @arguments
