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
Set-StrictMode -Version Latest

$packageRoot = Split-Path -Parent $PSScriptRoot
$root = [System.IO.Path]::GetFullPath($HalfLifeRoot)
$valveRoot = Join-Path $root "valve"
$hlds = Join-Path $root "hlds.exe"

$amxxVersion = "1.10.0.5479"
$amxxArchiveName = "amxmodx-1.10.0-git5479-base-windows.zip"
$amxxUrl = "https://github.com/alliedmodders/amxmodx/releases/download/$amxxVersion/$amxxArchiveName"
$metamodUrl = "https://github.com/Bots-United/metamod-p/releases/download/v1.21p38/metamod_i686_linux_win32-1.21p38.tar.xz"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Lines
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        return $null
    }

    $backup = "$Path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
    Copy-Item $Path $backup -Force
    return $backup
}

function Download-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Write-Host "Downloading $Uri"
    Invoke-WebRequest -Uri $Uri -OutFile $Destination

    if (-not (Test-Path $Destination -PathType Leaf) -or (Get-Item $Destination).Length -le 0) {
        throw "Download produced an empty file: $Destination"
    }
}

function Find-PackageFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativeBuildPath,

        [Parameter(Mandatory = $true)]
        [string]$RelativePackagePath
    )

    $buildPath = Join-Path $packageRoot $RelativeBuildPath
    if (Test-Path $buildPath -PathType Leaf) {
        return $buildPath
    }

    $packagePath = Join-Path $packageRoot $RelativePackagePath
    if (Test-Path $packagePath -PathType Leaf) {
        return $packagePath
    }

    throw "Package file not found: $RelativeBuildPath or $RelativePackagePath"
}

function Install-Runtime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModRoot
    )

    $temp = Join-Path $env:TEMP "hldm_anticheat_runtime_$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    try {
        $amxxArchive = Join-Path $temp $amxxArchiveName
        $amxxExtract = Join-Path $temp "amxx"
        Download-File -Uri $amxxUrl -Destination $amxxArchive
        Expand-Archive -Path $amxxArchive -DestinationPath $amxxExtract -Force

        $amxxAddons = Join-Path $amxxExtract "addons"
        if (-not (Test-Path $amxxAddons -PathType Container)) {
            throw "AMX Mod X archive has no addons folder."
        }

        New-Item -ItemType Directory -Path (Join-Path $ModRoot "addons") -Force | Out-Null
        Copy-Item (Join-Path $amxxAddons "*") (Join-Path $ModRoot "addons") -Recurse -Force

        $metamodArchive = Join-Path $temp "metamod.tar.xz"
        $metamodExtract = Join-Path $temp "metamod"
        New-Item -ItemType Directory -Path $metamodExtract -Force | Out-Null
        Download-File -Uri $metamodUrl -Destination $metamodArchive

        & tar.exe -xf $metamodArchive -C $metamodExtract
        if ($LASTEXITCODE -ne 0) {
            throw "tar.exe failed to extract Metamod-P."
        }

        $metamodDll = Get-ChildItem $metamodExtract -Recurse -Filter "metamod.dll" | Select-Object -First 1
        if ($null -eq $metamodDll) {
            throw "metamod.dll was not found in the Metamod-P archive."
        }

        $metamodDllDirectory = Join-Path $ModRoot "addons\metamod\dlls"
        New-Item -ItemType Directory -Path $metamodDllDirectory -Force | Out-Null
        Copy-Item $metamodDll.FullName (Join-Path $metamodDllDirectory "metamod.dll") -Force
    }
    finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $root -PathType Container)) {
    throw "Half-Life root does not exist: $root"
}

if (-not (Test-Path $valveRoot -PathType Container)) {
    throw "The valve folder was not found: $valveRoot"
}

if (-not (Test-Path $hlds -PathType Leaf)) {
    throw "hlds.exe was not found: $hlds. Use install_fresh_hlds_windows.ps1 for a SteamCMD installation."
}

$metamodDllTarget = Join-Path $valveRoot "addons\metamod\dlls\metamod.dll"
$amxxDllTarget = Join-Path $valveRoot "addons\amxmodx\dlls\amxmodx_mm.dll"

if ($ForceRuntimeInstall -or -not (Test-Path $metamodDllTarget -PathType Leaf) -or -not (Test-Path $amxxDllTarget -PathType Leaf)) {
    Install-Runtime -ModRoot $valveRoot
}

foreach ($requiredRuntimeFile in @($metamodDllTarget, $amxxDllTarget)) {
    if (-not (Test-Path $requiredRuntimeFile -PathType Leaf)) {
        throw "Runtime component was not installed: $requiredRuntimeFile"
    }
}

$liblist = Join-Path $valveRoot "liblist.gam"
if (-not (Test-Path $liblist -PathType Leaf)) {
    throw "liblist.gam was not found: $liblist"
}

$liblistBackup = Backup-File -Path $liblist
$liblistText = Get-Content $liblist -Raw
$metamodGameDll = 'gamedll "addons\metamod\dlls\metamod.dll"'

if ($liblistText -match '(?im)^\s*gamedll\s+".*"\s*$') {
    $liblistText = [regex]::Replace(
        $liblistText,
        '(?im)^\s*gamedll\s+".*"\s*$',
        $metamodGameDll,
        1
    )
}
else {
    $liblistText = $liblistText.TrimEnd() + [Environment]::NewLine + $metamodGameDll + [Environment]::NewLine
}

[System.IO.File]::WriteAllText($liblist, $liblistText, (New-Object System.Text.UTF8Encoding($false)))

$metamodPlugins = Join-Path $valveRoot "addons\metamod\plugins.ini"
New-Item -ItemType Directory -Path (Split-Path $metamodPlugins -Parent) -Force | Out-Null

$metamodLines = @()
if (Test-Path $metamodPlugins -PathType Leaf) {
    $metamodLines = @(Get-Content $metamodPlugins)
}

if (-not ($metamodLines -match '^\s*win32\s+addons/amxmodx/dlls/amxmodx_mm\.dll\s*$')) {
    $metamodLines += "win32 addons/amxmodx/dlls/amxmodx_mm.dll"
}

Write-Utf8NoBom -Path $metamodPlugins -Lines $metamodLines

$amxxRoot = Join-Path $valveRoot "addons\amxmodx"
$amxxPluginsDirectory = Join-Path $amxxRoot "plugins"
$amxxConfigsDirectory = Join-Path $amxxRoot "configs\plugins"
$amxxPluginsIni = Join-Path $amxxRoot "configs\plugins.ini"

New-Item -ItemType Directory -Path $amxxPluginsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $amxxConfigsDirectory -Force | Out-Null

$trapPluginSource = Find-PackageFile -RelativeBuildPath "build\hldm_trap.amxx" -RelativePackagePath "addons\amxmodx\plugins\hldm_trap.amxx"
$detectorPluginSource = Find-PackageFile -RelativeBuildPath "build\hldm_detector.amxx" -RelativePackagePath "addons\amxmodx\plugins\hldm_detector.amxx"
$trapConfigSource = Find-PackageFile -RelativeBuildPath "configs\plugins\hldm_trap.cfg" -RelativePackagePath "addons\amxmodx\configs\plugins\hldm_trap.cfg"
$detectorConfigSource = Find-PackageFile -RelativeBuildPath "configs\plugins\hldm_detector.cfg" -RelativePackagePath "addons\amxmodx\configs\plugins\hldm_detector.cfg"

Copy-Item $trapPluginSource (Join-Path $amxxPluginsDirectory "hldm_trap.amxx") -Force
Copy-Item $detectorPluginSource (Join-Path $amxxPluginsDirectory "hldm_detector.amxx") -Force
Copy-Item $trapConfigSource (Join-Path $amxxConfigsDirectory "hldm_trap.cfg") -Force
Copy-Item $detectorConfigSource (Join-Path $amxxConfigsDirectory "hldm_detector.cfg") -Force

if (-not (Test-Path $amxxPluginsIni -PathType Leaf)) {
    throw "AMX Mod X plugins.ini was not found: $amxxPluginsIni"
}

$pluginsIniBackup = Backup-File -Path $amxxPluginsIni
$pluginLines = @(
    Get-Content $amxxPluginsIni |
        Where-Object {
            $_ -notmatch '^\s*hldm_trap\.amxx(?:\s+debug)?\s*$' -and
            $_ -notmatch '^\s*hldm_detector\.amxx(?:\s+debug)?\s*$'
        }
)

$pluginLines += ""
$pluginLines += "; HLDM Anticheat: trap must load before detector"
$pluginLines += "hldm_trap.amxx"
$pluginLines += "hldm_detector.amxx"
Write-Utf8NoBom -Path $amxxPluginsIni -Lines $pluginLines

$safeHostname = $Hostname.Replace('"', "'")
$safeRconPassword = $RconPassword.Replace('"', "")
$safeMap = $StartMap -replace '[^A-Za-z0-9_]', ''
if ([string]::IsNullOrWhiteSpace($safeMap)) {
    $safeMap = "crossfire"
}

$serverOverlay = Join-Path $valveRoot "hldm_anticheat_server.cfg"
$serverOverlayLines = @(
    "// Generated by HLDM Anticheat setup"
    "hostname `"$safeHostname`""
    "rcon_password `"$safeRconPassword`""
    "sv_lan `"0`""
    "sv_cheats `"0`""
    "sv_allowupload `"0`""
    "sv_allowdownload `"1`""
    "sv_voiceenable `"1`""
    "mp_timelimit `"30`""
    "mp_fraglimit `"0`""
)
Write-Utf8NoBom -Path $serverOverlay -Lines $serverOverlayLines

$serverCfg = Join-Path $valveRoot "server.cfg"
$serverCfgLines = @()
if (Test-Path $serverCfg -PathType Leaf) {
    $serverCfgLines = @(Get-Content $serverCfg)
}

if (-not ($serverCfgLines -match '^\s*exec\s+hldm_anticheat_server\.cfg\s*$')) {
    $serverCfgLines += ""
    $serverCfgLines += "exec hldm_anticheat_server.cfg"
}

Write-Utf8NoBom -Path $serverCfg -Lines $serverCfgLines

$launcher = Join-Path $root "run_hldm_anticheat_server.bat"
$launcherLines = @(
    "@echo off"
    "cd /d `"%~dp0`""
    "hlds.exe -console -game valve -dll addons\metamod\dlls\metamod.dll -port $Port +maxplayers $MaxPlayers +map $safeMap +exec hldm_anticheat_server.cfg"
    "pause"
)
[System.IO.File]::WriteAllLines($launcher, $launcherLines, [System.Text.Encoding]::ASCII)

if ($OpenFirewall) {
    $ruleName = "HLDM Anticheat UDP $Port"
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($null -eq $existingRule) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol UDP -LocalPort $Port | Out-Null
    }
}

Write-Host ""
Write-Host "HLDM Anticheat server installation completed."
Write-Host "Root: $root"
Write-Host "Launcher: $launcher"
Write-Host "Metamod plugins: $metamodPlugins"
Write-Host "AMXX plugins: $amxxPluginsIni"
Write-Host "liblist backup: $liblistBackup"
Write-Host "plugins.ini backup: $pluginsIniBackup"
Write-Host ""
Write-Host "After launch, verify: meta list; amxx plugins; amx_ac_status; amx_trap_list"

if ($RconPassword -eq "CHANGE_ME_NOW") {
    Write-Warning "Change the generated rcon_password before exposing the server to the internet."
}

if ($StartServer) {
    Start-Process -FilePath $launcher -WorkingDirectory $root
}
