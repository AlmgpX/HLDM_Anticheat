param(
    [string]$ServerRoot = "E:\HLDS_AlexMerqury",
    [int]$Port = 27016,
    [switch]$StartServer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-SteamRoot {
    $steamProcess = Get-Process steam -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $steamProcess -and -not [string]::IsNullOrWhiteSpace($steamProcess.Path)) {
        return Split-Path -Parent $steamProcess.Path
    }

    $registryCandidates = @(
        @{ Path = "HKCU:\Software\Valve\Steam"; Name = "SteamPath" },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"; Name = "InstallPath" },
        @{ Path = "HKLM:\SOFTWARE\Valve\Steam"; Name = "InstallPath" }
    )

    foreach ($candidate in $registryCandidates) {
        try {
            $value = (Get-ItemProperty -Path $candidate.Path -Name $candidate.Name -ErrorAction Stop).($candidate.Name)
            if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path $value -PathType Container)) {
                return [System.IO.Path]::GetFullPath($value)
            }
        }
        catch {
        }
    }

    throw "Steam installation root was not found. Start Steam and rerun this script."
}

$server = [System.IO.Path]::GetFullPath($ServerRoot)
if (-not (Test-Path $server -PathType Container)) {
    throw "Server root does not exist: $server"
}

$hlds = Join-Path $server "hlds.exe"
if (-not (Test-Path $hlds -PathType Leaf)) {
    throw "hlds.exe was not found: $hlds"
}

$steamRoot = Resolve-SteamRoot
$requiredFiles = @(
    "SDL3.dll",
    "steamclient.dll",
    "tier0_s.dll",
    "vstdlib_s.dll"
)
$optionalFiles = @(
    "crashhandler.dll"
)

Get-Process hlds -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

foreach ($fileName in $requiredFiles) {
    $source = Join-Path $steamRoot $fileName
    if (-not (Test-Path $source -PathType Leaf)) {
        throw "Required Steam runtime file not found: $source"
    }

    Copy-Item -LiteralPath $source -Destination (Join-Path $server $fileName) -Force
    Write-Host "Copied: $fileName"
}

foreach ($fileName in $optionalFiles) {
    $source = Join-Path $steamRoot $fileName
    if (Test-Path $source -PathType Leaf) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $server $fileName) -Force
        Write-Host "Copied: $fileName"
    }
}

Write-Host ""
Write-Host "Steam runtime repaired from: $steamRoot"
Write-Host "Server root: $server"

if ($StartServer) {
    $launcher = Join-Path $server "START_AlexMerqury_DM_Server.bat"
    if (-not (Test-Path $launcher -PathType Leaf)) {
        throw "Server launcher was not found: $launcher"
    }

    Start-Process -FilePath $launcher -WorkingDirectory $server
    Start-Sleep -Seconds 5

    $process = Get-Process hlds -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        throw "HLDS exited during startup. Inspect the server console output."
    }

    $endpoint = Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue
    if ($null -eq $endpoint) {
        throw "HLDS is running but UDP port $Port is not listening."
    }

    Write-Host "HLDS is running on UDP $Port."
}
