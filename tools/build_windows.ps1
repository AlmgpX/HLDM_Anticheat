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

if (-not (Test-Path $compiler -PathType Leaf)) {
    throw "amxxpc.exe not found: $compiler"
}

New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
Copy-Item $source $temporarySource -Force

try {
    Push-Location $scripting
    & $compiler (Split-Path $temporarySource -Leaf)
    if ($LASTEXITCODE -ne 0) {
        throw "AMXX compiler returned exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

if (-not (Test-Path $temporaryOutput -PathType Leaf)) {
    throw "Compiler did not produce $temporaryOutput"
}

Move-Item $temporaryOutput $finalOutput -Force
Remove-Item $temporarySource -Force -ErrorAction SilentlyContinue
Write-Host "Built: $finalOutput"
