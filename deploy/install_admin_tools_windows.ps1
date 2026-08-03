param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot,

    [string]$AdminSteamId = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$packageRoot = Split-Path -Parent $PSScriptRoot
$root = [System.IO.Path]::GetFullPath($HalfLifeRoot)
$valveRoot = Join-Path $root "valve"
$amxxRoot = Join-Path $valveRoot "addons\amxmodx"
$pluginsDirectory = Join-Path $amxxRoot "plugins"
$configsDirectory = Join-Path $amxxRoot "configs\plugins"
$pluginsIni = Join-Path $amxxRoot "configs\plugins.ini"
$usersIni = Join-Path $amxxRoot "configs\users.ini"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
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

function Find-PackageFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildPath,

        [Parameter(Mandatory = $true)]
        [string]$PackagePath
    )

    $buildCandidate = Join-Path $packageRoot $BuildPath
    if (Test-Path $buildCandidate -PathType Leaf) {
        return $buildCandidate
    }

    $packageCandidate = Join-Path $packageRoot $PackagePath
    if (Test-Path $packageCandidate -PathType Leaf) {
        return $packageCandidate
    }

    throw "File not found in build or package: $BuildPath / $PackagePath"
}

foreach ($required in @($root, $valveRoot, $amxxRoot, $pluginsIni, $usersIni)) {
    if (-not (Test-Path $required)) {
        throw "Required path does not exist: $required"
    }
}

$pluginSource = Find-PackageFile `
    -BuildPath "build\hldm_admin_tools.amxx" `
    -PackagePath "addons\amxmodx\plugins\hldm_admin_tools.amxx"

$configSource = Find-PackageFile `
    -BuildPath "configs\plugins\hldm_admin_tools.cfg" `
    -PackagePath "addons\amxmodx\configs\plugins\hldm_admin_tools.cfg"

New-Item -ItemType Directory -Path $pluginsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $configsDirectory -Force | Out-Null

Copy-Item $pluginSource (Join-Path $pluginsDirectory "hldm_admin_tools.amxx") -Force
Copy-Item $configSource (Join-Path $configsDirectory "hldm_admin_tools.cfg") -Force

$pluginsBackup = Backup-File -Path $pluginsIni
$pluginLines = @(
    Get-Content $pluginsIni |
        Where-Object { $_ -notmatch '^\s*hldm_admin_tools\.amxx(?:\s+debug)?\s*$' }
)
$pluginLines += ""
$pluginLines += "; HLDM local admin overlay"
$pluginLines += "hldm_admin_tools.amxx"
Write-Utf8NoBom -Path $pluginsIni -Lines $pluginLines

$adminAdded = $false
if (-not [string]::IsNullOrWhiteSpace($AdminSteamId)) {
    $normalizedSteamId = $AdminSteamId.Trim().ToUpperInvariant()
    if ($normalizedSteamId -notmatch '^(STEAM|VALVE)_[0-9]+:[0-9]+:[0-9]+$') {
        throw "Invalid AdminSteamId: $AdminSteamId. Run status in the game/server console and copy the STEAM_... value."
    }

    $usersBackup = Backup-File -Path $usersIni
    $usersLines = @(Get-Content $usersIni)
    $escapedSteamId = [regex]::Escape($normalizedSteamId)

    if (-not ($usersLines -match "^\s*`"$escapedSteamId`"")) {
        $usersLines += ""
        $usersLines += "; HLDM Anticheat local administrator"
        $usersLines += "`"$normalizedSteamId`" `"`" `"abcdefghijklmnopqrstu`" `"ce`""
        Write-Utf8NoBom -Path $usersIni -Lines $usersLines
        $adminAdded = $true
    }

    Write-Host "users.ini backup: $usersBackup"
}

$bindCfg = Join-Path $valveRoot "hldm_admin.cfg"
$bindLines = @(
    "// HLDM Anticheat local admin binds"
    "// Restore GoldSrc menu slots. Without these binds AMXX options 7, 8, 9 and 0 cannot be selected."
    "bind `"7`" `"slot7`""
    "bind `"8`" `"slot8`""
    "bind `"9`" `"slot9`""
    "bind `"0`" `"slot10`""
    "bind `"F5`" `"amx_ac_noclip`""
    "bind `"F6`" `"amx_ac_esp`""
    "bind `"F7`" `"amx_ac_esp_mode`""
    "bind `"F8`" `"amx_ac_menu`""
    "bind `"F9`" `"amx_ac_aim trap`""
    "bind `"F10`" `"amx_ac_aim untrap`""
    "bind `"F11`" `"amx_ac_status`""
    "bind `"F12`" `"amx_trap_list`""
    "echo HLDM admin binds loaded: menu slots 7-0 restored; F5 noclip, F6 ESP, F7 mode, F8 player menu"
)
Write-Utf8NoBom -Path $bindCfg -Lines $bindLines

$userConfig = Join-Path $valveRoot "userconfig.cfg"
$userConfigLines = @()
if (Test-Path $userConfig -PathType Leaf) {
    $userConfigLines = @(Get-Content $userConfig)
}

if (-not ($userConfigLines -match '^\s*exec\s+hldm_admin\.cfg\s*$')) {
    $userConfigLines += ""
    $userConfigLines += "exec hldm_admin.cfg"
}
Write-Utf8NoBom -Path $userConfig -Lines $userConfigLines

Write-Host ""
Write-Host "HLDM Admin Tools installed."
Write-Host "Plugin: $(Join-Path $pluginsDirectory 'hldm_admin_tools.amxx')"
Write-Host "Config: $(Join-Path $configsDirectory 'hldm_admin_tools.cfg')"
Write-Host "Binds: $bindCfg"
Write-Host "plugins.ini backup: $pluginsBackup"

if ($adminAdded) {
    Write-Host "Admin SteamID added: $AdminSteamId"
}
elseif ([string]::IsNullOrWhiteSpace($AdminSteamId)) {
    Write-Warning "AdminSteamId was not provided. The overlay commands require ADMIN_RCON. Run status, then rerun this script with -AdminSteamId STEAM_..."
}
else {
    Write-Host "Admin SteamID was already present in users.ini."
}

Write-Host "Restart HLDS or change the map, then verify: amxx plugins"
Write-Host "In the client console run once if needed: exec hldm_admin.cfg"
