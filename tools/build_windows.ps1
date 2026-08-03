param(
    [Parameter(Mandatory = $true)]
    [string]$AmxxRoot
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot "src\hldm_trap.sma"
$scripting = Join-Path $AmxxRoot "addons\amxmodx\scripting"
$compiler = Join-Path $scripting "amxxpc.exe"
$temporarySource = Join-Path $scripting "hldm_trap_repo_build.sma"
$temporaryOutput = Join-Path $scripting "hldm_trap_repo_build.amxx"
$buildDirectory = Join-Path $repoRoot "build"
$finalOutput = Join-Path $buildDirectory "hldm_trap.amxx"

foreach ($required in @($source, $compiler)) {
    if (-not (Test-Path $required -PathType Leaf)) {
        throw "Required file does not exist: $required"
    }
}

New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
Remove-Item $temporarySource, $temporaryOutput -Force -ErrorAction SilentlyContinue
Copy-Item $source $temporarySource -Force

try {
    Push-Location $scripting
    & $compiler (Split-Path $temporarySource -Leaf)
    if ($LASTEXITCODE -ne 0) {
        throw "AMXX compiler returned exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
    Remove-Item $temporarySource -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $temporaryOutput -PathType Leaf)) {
    throw "Compiler did not produce $temporaryOutput"
}

if ((Get-Item $temporaryOutput).Length -le 0) {
    throw "Compiler produced an empty plugin: $temporaryOutput"
}

Move-Item $temporaryOutput $finalOutput -Force
Write-Host "Built: $finalOutput"
