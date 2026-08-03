param(
    [Parameter(Mandatory = $true)]
    [string]$HalfLifeRoot,

    [string]$AdminSteamId = "",

    [string]$RconPassword = "CHANGE_ME_NOW",

    [string]$Hostname = "AlexMerqury_DM_Server",

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

$setupScript = Join-Path $PSScriptRoot "setup_hldm_server_windows.ps1"
$adminScript = Join-Path $PSScriptRoot "install_admin_tools_windows.ps1"

foreach ($required in @($setupScript, $adminScript)) {
    if (-not (Test-Path $required -PathType Leaf)) {
        throw "Required setup script was not found: $required"
    }
}

# Older 1.1 packages rejected arrays containing blank lines in plugins.ini/server.cfg.
# Patch the helper in place before invoking it so rerunning the installer is idempotent.
$setupText = Get-Content $setupScript -Raw
if ($setupText -notmatch '\[AllowEmptyString\(\)\]') {
    $pattern = '(?m)(\[Parameter\(Mandatory = \$true\)\]\r?\n\s*)(\[string\[\]\]\$Lines)'
    $replacement = '${1}[AllowEmptyString()]' + [Environment]::NewLine + '        [AllowEmptyCollection()]' + [Environment]::NewLine + '        ${2}'
    $patchedText = [regex]::Replace($setupText, $pattern, $replacement, 1)

    if ($patchedText -eq $setupText) {
        throw "Could not patch Write-Utf8NoBom Lines parameter in $setupScript"
    }

    [System.IO.File]::WriteAllText(
        $setupScript,
        $patchedText,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

$setupParameters = @{
    HalfLifeRoot = $HalfLifeRoot
    RconPassword = $RconPassword
    Hostname = $Hostname
    MaxPlayers = $MaxPlayers
    Port = $Port
    StartMap = $StartMap
}

if ($ForceRuntimeInstall) {
    $setupParameters["ForceRuntimeInstall"] = $true
}

if ($OpenFirewall) {
    $setupParameters["OpenFirewall"] = $true
}

& $setupScript @setupParameters

$root = [System.IO.Path]::GetFullPath($HalfLifeRoot)
$serverOverlay = Join-Path $root "valve\hldm_anticheat_server.cfg"
if (-not (Test-Path $serverOverlay -PathType Leaf)) {
    throw "Generated server overlay was not found: $serverOverlay"
}

$overlayLines = @(
    Get-Content $serverOverlay |
        Where-Object {
            $_ -notmatch '^\s*hostname\s+' -and
            $_ -notmatch '^\s*sv_password\s+' -and
            $_ -notmatch '^\s*sv_lan\s+'
        }
)

$overlayLines += "hostname `"$($Hostname.Replace('"', "'"))`""
$overlayLines += 'sv_password ""'
$overlayLines += 'sv_lan "0"'

if (-not ($overlayLines -match '^\s*mp_consistency\s+"?1"?\s*$')) {
    $overlayLines += 'mp_consistency "1"'
}

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($serverOverlay, $overlayLines, $encoding)

& $adminScript -HalfLifeRoot $HalfLifeRoot -AdminSteamId $AdminSteamId

Write-Host ""
Write-Host "Complete HLDM Anticheat setup finished."
Write-Host "Server name: $Hostname"
Write-Host "Public listing: sv_lan 0"
Write-Host "Player password: disabled"
Write-Host "Standard-model guard and mp_consistency are enabled."
Write-Host "Client keys: F6 ESP, F7 mode, F8 inspect, F9 trap, F10 untrap."

if ($StartServer) {
    $launcher = Join-Path $root "run_hldm_anticheat_server.bat"

    if (-not (Test-Path $launcher -PathType Leaf)) {
        throw "Server launcher was not generated: $launcher"
    }

    Start-Process -FilePath $launcher -WorkingDirectory $root
}
