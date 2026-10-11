# KalaSetu Development Environment Startup Script
# Automatically configures network, backend, ADB reverse proxy, and launches Flutter.

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         KalaSetu End-to-End Dev Runner                   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Identify Real Wi-Fi IPv4 (ignoring virtual adapters like vEthernet, WSL, VMware, VirtualBox)
Write-Host "`n[Step 1/4] Detecting real Wi-Fi IPv4 address..." -ForegroundColor Yellow

$wifiAdapter = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "*Wi-Fi*" -ErrorAction SilentlyContinue |
    Where-Object { 
        $_.IPAddress -notlike "169.254.*" -and 
        $_.IPAddress -ne "127.0.0.1" -and
        $_.InterfaceAlias -notmatch "vEthernet|WSL|VMware|VirtualBox|Loopback|pseudo"
    } |
    Select-Object -First 1

if (-not $wifiAdapter) {
    # Fallback to the active interface associated with the default route
    $defaultRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($defaultRoute) {
        $wifiAdapter = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $defaultRoute.InterfaceIndex -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.IPAddress -notlike "169.254.*" -and 
                $_.IPAddress -ne "127.0.0.1" -and
                $_.InterfaceAlias -notmatch "vEthernet|WSL|VMware|VirtualBox"
            } |
            Select-Object -First 1
    }
}

$wifiIp = if ($wifiAdapter) { $wifiAdapter.IPAddress } else { "127.0.0.1" }
Write-Host "Detected Real Wi-Fi IPv4: $wifiIp (Interface: $(if ($wifiAdapter) { $wifiAdapter.InterfaceAlias } else { 'Loopback' }))" -ForegroundColor Green

# 2. Check and start backend on 0.0.0.0:8000
Write-Host "`n[Step 2/4] Checking backend server on port 8000..." -ForegroundColor Yellow
$backendRunning = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue

$rootDir = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $rootDir "backend"
$frontendDir = Join-Path $rootDir "frontend"
$venvPython = Join-Path $backendDir ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    $venvPython = "python"
}

if (-not $backendRunning) {
    Write-Host "Backend is NOT running. Starting uvicorn on 0.0.0.0:8000..." -ForegroundColor Cyan
    Start-Process -FilePath $venvPython -ArgumentList "-m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload" -WorkingDirectory $backendDir
    Start-Sleep -Seconds 3
    Write-Host "Backend started." -ForegroundColor Green
} else {
    Write-Host "Backend is already listening on 0.0.0.0:8000." -ForegroundColor Green
}

# 3. Check for connected Android device via ADB and configure reverse proxy
Write-Host "`n[Step 3/4] Checking connected ADB devices..." -ForegroundColor Yellow
$adbDevicesRaw = adb devices 2>$null
$attachedDevices = @()
if ($adbDevicesRaw) {
    foreach ($line in $adbDevicesRaw) {
        if ($line -match "^\s*([^\s]+)\s+device$") {
            $attachedDevices += $Matches[1]
        }
    }
}

$adbReverseSuccess = $false
$targetDeviceId = $null

if ($attachedDevices.Count -gt 0) {
    $targetDeviceId = $attachedDevices[0]
    Write-Host "Connected Android phone detected: $targetDeviceId" -ForegroundColor Green
    
    Write-Host "Running: adb -s $targetDeviceId reverse tcp:8000 tcp:8000" -ForegroundColor Cyan
    $reverseOut = & adb -s $targetDeviceId reverse tcp:8000 tcp:8000 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "ADB reverse succeeded! Phone can access backend via 127.0.0.1:8000." -ForegroundColor Green
        $adbReverseSuccess = $true
    } else {
        Write-Warning "ADB reverse returned error ($reverseOut). Falling back to Wi-Fi IP ($wifiIp)."
    }
} else {
    Write-Host "No connected Android USB/ADB device found. The phone will connect wirelessly via Wi-Fi IP ($wifiIp)." -ForegroundColor Yellow
}

# 4. Resolve API_BASE_URL and start Flutter
Write-Host "`n[Step 4/4] Starting Flutter app with API_BASE_URL..." -ForegroundColor Yellow
if ($adbReverseSuccess) {
    $apiBaseUrl = "http://127.0.0.1:8000/api/v1"
} else {
    $apiBaseUrl = "http://${wifiIp}:8000/api/v1"
}

Write-Host "Active API Base URL: $apiBaseUrl" -ForegroundColor Cyan

$flutterArgs = @("run", "--dart-define=API_BASE_URL=$apiBaseUrl")
if ($targetDeviceId) {
    $flutterArgs += @("-d", $targetDeviceId)
}

Write-Host "Command: flutter $($flutterArgs -join ' ')" -ForegroundColor DarkGray
Push-Location $frontendDir
try {
    & flutter @flutterArgs
} finally {
    Pop-Location
}
