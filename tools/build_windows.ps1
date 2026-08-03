param(
    [Parameter(Mandatory = $true)]
    [string]$AmxxRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$scripting = Join-Path $AmxxRoot "addons\amxmodx\scripting"
$compiler = Join-Path $scripting "amxxpc.exe"
$sourceDirectory = Join-Path $repoRoot "src"
$buildDirectory = Join-Path $repoRoot "build"
$log = Join-Path $buildDirectory "compiler-windows.log"

foreach ($required in @($sourceDirectory, $compiler)) {
    if (-not (Test-Path $required)) {
        throw "Required path does not exist: $required"
    }
}

$sources = @(Get-ChildItem $sourceDirectory -Filter "*.sma" | Sort-Object Name)
if ($sources.Count -lt 2) {
    throw "Expected at least hldm_trap.sma and hldm_detector.sma."
}

New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
Remove-Item $log -Force -ErrorAction SilentlyContinue

foreach ($source in $sources) {
    $name = $source.BaseName
    $temporarySource = Join-Path $scripting "$name.repo_build.sma"
    $temporaryOutput = Join-Path $scripting "$name.repo_build.amxx"
    $finalOutput = Join-Path $buildDirectory "$name.amxx"

    Remove-Item $temporarySource, $temporaryOutput -Force -ErrorAction SilentlyContinue
    Copy-Item $source.FullName $temporarySource -Force

    try {
        Push-Location $scripting
        "===== $($source.Name) =====" | Tee-Object -FilePath $log -Append
        & $compiler (Split-Path $temporarySource -Leaf) "-o$(Split-Path $temporaryOutput -Leaf)" 2>&1 |
            Tee-Object -FilePath $log -Append

        if ($LASTEXITCODE -ne 0) {
            throw "AMXX compiler returned exit code $LASTEXITCODE for $($source.Name)"
        }
    }
    finally {
        Pop-Location
        Remove-Item $temporarySource -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $temporaryOutput -PathType Leaf) -or (Get-Item $temporaryOutput).Length -le 0) {
        throw "Compiler did not produce a non-empty plugin: $temporaryOutput"
    }

    Move-Item $temporaryOutput $finalOutput -Force
    Write-Host "Built: $finalOutput"
}

if (Select-String -Path $log -Pattern '\bwarning\s+\d+:' -Quiet) {
    Get-Content $log
    throw "Pawn compiler warnings are not allowed."
}
