# Creates the team release keystore and android/key.properties (both gitignored).
# Run once, interactively, and back the keystore up somewhere safe: losing it
# means future updates can't be installed over existing builds.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\create_release_keystore.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$keystore = Join-Path $root 'android\app\resq-release.jks'
$props = Join-Path $root 'android\key.properties'

if (Test-Path $keystore) { throw "Keystore already exists at $keystore — refusing to overwrite." }

$keytool = 'keytool'
if (Test-Path 'C:\dev\jdk-17.0.20.1+1\bin\keytool.exe') { $keytool = 'C:\dev\jdk-17.0.20.1+1\bin\keytool.exe' }

$secure = Read-Host 'Keystore password (min 6 chars)' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
if ($password.Length -lt 6) { throw 'Password too short.' }

& $keytool -genkeypair -v -keystore $keystore -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 `
    -alias resq-release -storepass $password -keypass $password `
    -dname 'CN=RESQ, OU=DARUBAAZ, O=DARUBAAZ, C=IN'
if ($LASTEXITCODE -ne 0) { throw 'keytool failed' }

@"
storePassword=$password
keyPassword=$password
keyAlias=resq-release
storeFile=resq-release.jks
"@ | Set-Content -Path $props -Encoding ascii

Write-Host "Keystore: $keystore"
Write-Host "Properties: $props (gitignored)"
Write-Host 'Back up the keystore and password now.'
