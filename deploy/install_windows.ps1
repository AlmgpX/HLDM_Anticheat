param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot,

    [string]$RconPassword = "CHANGE_ME_NOW",

    [string]$Hostname = "HLDM Anticheat Trap",

    [ValidateRange(1, 64)]
    [int]$MaxPlayers = 16,

    [ValidateRange(1024, 65535)]
    [int]$Port = 27015,

    [string]$StartMap = "crossfire",

    [switch]$ForceRuntimeInstall,

    [switch]$OpenFirewall,

    [switch]$StartServer
)

$ErrorActionPreference = "Stop"

$setup = Join-Path $PSScriptRoot "setup_hldm_server_windows.ps1"
if (-not (Test-Path $setup -PathType Leaf)) {
    throw "Setup script was not found: $setup"
}

$arguments = @{
    HalfLifeRoot = $HalfLifeRoot
    RconPassword = $RconPassword
    Hostname = $Hostname
    MaxPlayers = $MaxPlayers
    Port = $Port
    StartMap = $StartMap
}

if ($ForceRuntimeInstall) {
    $arguments.ForceRuntimeInstall = $true
}

if ($OpenFirewall) {
    $arguments.OpenFirewall = $true
}

if ($StartServer) {
    $arguments.StartServer = $true
}

& $setup @arguments
