$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    Write-Host "ADB not found at $adb" -ForegroundColor Red
    Write-Host "Please ensure Android SDK is installed." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$Host.UI.RawUI.WindowTitle = "PickleO - Live Device Logs (Xiaomi)"
Clear-Host
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           PickleO - Live API & Flutter Log Streamer            " -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Connected Device: Xiaomi (uk8lijxk75qg8pfe)" -ForegroundColor White
Write-Host "Listening for [API-REQ], [API-RES], and Flutter logs...`n" -ForegroundColor Green

# Clear previous backlog for clean view
& $adb -s uk8lijxk75qg8pfe logcat -c

# Stream flutter logs
& $adb -s uk8lijxk75qg8pfe logcat -v tag flutter:V *:S
