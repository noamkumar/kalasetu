# ==============================================================================
# KalaSetu - Web Production Build Script
# Usage: .\scripts\build_web.ps1 [-ApiBaseUrl "https://<your-backend>/api/v1"]
# ==============================================================================
[CmdletBinding()]
param (
    [string]$ApiBaseUrl = "https://kalasetu-backend-s3uq.onrender.com/api/v1"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "       KalaSetu Flutter Web Production Build" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "API Base URL: $ApiBaseUrl`n" -ForegroundColor Yellow

$RepoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$FrontendDir = Join-Path $RepoRoot "frontend"

if (-not (Test-Path $FrontendDir)) {
    Write-Error "Frontend directory not found at $FrontendDir"
    exit 1
}

Push-Location $FrontendDir

try {
    Write-Host "[1/3] Resolving Flutter dependencies..." -ForegroundColor Green
    flutter pub get

    Write-Host "`n[2/3] Building Flutter Web (Release Mode)..." -ForegroundColor Green
    flutter build web --release --no-tree-shake-icons --dart-define="API_BASE_URL=$ApiBaseUrl"

    $OutputDir = Join-Path $FrontendDir "build\web"
    $IndexFile = Join-Path $OutputDir "index.html"
    $VercelConfig = Join-Path $FrontendDir "vercel.json"

    if (Test-Path $IndexFile) {
        if (Test-Path $VercelConfig) {
            Copy-Item -Path $VercelConfig -Destination (Join-Path $OutputDir "vercel.json") -Force
        }
        Write-Host "`n[3/3] Build Succeeded!" -ForegroundColor Green
        Write-Host "Output bundle: $OutputDir" -ForegroundColor White
        Write-Host "`nTo preview locally with a static server:" -ForegroundColor Cyan
        Write-Host "  npx serve -s frontend\build\web" -ForegroundColor White
        Write-Host "To deploy to Vercel:" -ForegroundColor Cyan
        Write-Host "  npx vercel deploy frontend\build\web --prod`n" -ForegroundColor White
    } else {
        Write-Error "Build output index.html not found in $OutputDir"
        exit 1
    }
}
finally {
    Pop-Location
}
