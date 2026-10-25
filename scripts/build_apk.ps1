# Phase-gate build: analyze -> test -> build APK(s) -> copy to dist/ with checksums.
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1                 # debug, universal
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -Release        # release, universal
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -Release -SplitPerAbi
#   add -SkipChecks to build without analyze/test (never for a phase gate)
param([switch]$Release, [switch]$SplitPerAbi, [switch]$SkipChecks)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Step([string]$name, [scriptblock]$cmd) {
    Write-Host "==> $name"
    & $cmd
    if ($LASTEXITCODE -ne 0) { throw "$name failed with exit code $LASTEXITCODE" }
}

Invoke-Step 'flutter pub get' { flutter pub get }
if (-not $SkipChecks) {
    Invoke-Step 'flutter analyze' { flutter analyze }
    Invoke-Step 'flutter test' { flutter test }
}

$mode = if ($Release) { 'release' } else { 'debug' }
if ($Release -and -not (Test-Path 'android\key.properties')) {
    Write-Warning 'android/key.properties missing: release APK will be DEBUG-signed (not distributable). Run scripts\create_release_keystore.ps1.'
}
$buildArgs = @('build', 'apk', "--$mode")
if ($SplitPerAbi) { $buildArgs += '--split-per-abi' }
Invoke-Step "flutter $($buildArgs -join ' ')" { flutter @buildArgs }

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value.Replace('+', '-b')
New-Item -ItemType Directory -Force dist | Out-Null
$outputs = Get-ChildItem "build\app\outputs\flutter-apk\*$mode.apk"
foreach ($apk in $outputs) {
    $suffix = $apk.BaseName.Replace('app-', '')
    $dest = "dist\resq-$version-$suffix.apk"
    Copy-Item $apk.FullName $dest -Force
    $hash = (Get-FileHash $dest -Algorithm SHA256).Hash.ToLower()
    $sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
    Write-Host "APK: $dest ($sizeMb MB)  SHA256: $hash"
}
