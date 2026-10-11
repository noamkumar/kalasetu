# ==============================================================================
# KalaSetu - Android Release APK Build Script
# Usage: .\scripts\build_release.ps1 [-ApiBaseUrl "https://<your-backend>/api/v1"]
# ==============================================================================
[CmdletBinding()]
param (
    [string]$ApiBaseUrl = "https://kalasetu-backend.onrender.com/api/v1"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "       KalaSetu Android Release APK Build" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "API Base URL: $ApiBaseUrl" -ForegroundColor Yellow
Write-Host "Package Name: com.kalasetu.app`n" -ForegroundColor Yellow

$RepoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$FrontendDir = Join-Path $RepoRoot "frontend"
$KeyProps = Join-Path $FrontendDir "android\key.properties"

if (-not (Test-Path $KeyProps)) {
    Write-Warning "key.properties not found at $KeyProps. Build will fall back to debug signing."
}

Push-Location $FrontendDir

try {
    Write-Host "[1/3] Resolving Flutter dependencies..." -ForegroundColor Green
    flutter pub get

    Write-Host "`n[2/3] Compiling signed release APK..." -ForegroundColor Green
    flutter build apk --release --no-tree-shake-icons --dart-define="API_BASE_URL=$ApiBaseUrl"

    $ApkPath = Join-Path $FrontendDir "build\app\outputs\flutter-apk\app-release.apk"

    if (Test-Path $ApkPath) {
        $Hash = (Get-FileHash -Path $ApkPath -Algorithm SHA256).Hash
        $SizeMb = [math]::Round(((Get-Item $ApkPath).Length / 1MB), 2)

        Write-Host "`n[3/3] Build Succeeded!" -ForegroundColor Green
        Write-Host "Artifact: $ApkPath" -ForegroundColor White
        Write-Host "Size:     $SizeMb MB" -ForegroundColor White
        Write-Host "SHA256:   $Hash`n" -ForegroundColor White

        # Optionally copy to repo root for GitHub Releases convenience
        $DestApk = Join-Path $RepoRoot "KalaSetu-release.apk"
        Copy-Item -Path $ApkPath -Destination $DestApk -Force
        Write-Host "Copied to: $DestApk for GitHub Releases.`n" -ForegroundColor Cyan
    } else {
        Write-Error "Release APK not found at $ApkPath"
        exit 1
    }
}
finally {
    Pop-Location
}
