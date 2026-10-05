<#
.SYNOPSIS
    Enables wireless ADB debugging on your phone so you can deploy Telly over Wi-Fi without a cable.

.DESCRIPTION
    1. Detects your USB-connected authorized phone.
    2. Queries the phone's internal Wi-Fi IP address (or allows manual IP input).
    3. Puts the ADB daemon on the phone into TCP/IP mode on port 5555.
    4. Connects to the phone wirelessly via 'adb connect <IP>:5555'.
    5. Confirms that you can now unplug the USB cable.

.PARAMETER Ip
    Optional manual IP address of the phone on your local Wi-Fi network.

.PARAMETER Port
    TCP port for ADB. Defaults to 5555.

.EXAMPLE
    .\wireless_adb.ps1
    .\wireless_adb.ps1 -Ip 192.168.1.150
#>

param(
    [string]$Ip = "",
    [int]$Port = 5555
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success([string]$msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg) { Write-Host "[ERR]  $msg" -ForegroundColor Red }

function Get-AdbExecutable {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ANDROID_HOME\platform-tools\adb.exe",
        "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe",
        "C:\Android\Sdk\platform-tools\adb.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) { return $cand }
    }
    return $null
}

$adb = Get-AdbExecutable
if (-not $adb) {
    Write-Err "adb.exe not found."
    exit 1
}

Write-Host "==========================================================" -ForegroundColor DarkCyan
Write-Host "   Telly Wireless ADB Setup                               " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor DarkCyan

# Step 1: Detect authorized device
$raw = & $adb devices -l
$authorizedDevices = @()
foreach ($line in ($raw -split "`r?`n")) {
    $trim = $line.Trim()
    if ($trim -like "List of devices*" -or [string]::IsNullOrWhiteSpace($trim)) { continue }
    $parts = -split $trim
    if ($parts.Length -ge 2 -and $parts[1] -eq "device") {
        $authorizedDevices += $parts[0]
    }
}

if ($authorizedDevices.Count -eq 0) {
    Write-Err "No authorized device connected via USB."
    Write-Warn "Please connect your phone via USB first, unlock it, and accept USB debugging."
    Write-Warn "Run .\device_doctor.ps1 to verify authorization."
    exit 1
}

$serial = $authorizedDevices[0]
Write-Success "Found authorized device: $serial"

# Step 2: Determine IP
if ([string]::IsNullOrWhiteSpace($Ip)) {
    Write-Info "Detecting phone's Wi-Fi IP address..."
    $ipInfo = (& $adb -s $serial shell "ip -f inet addr show wlan0 2>/dev/null").Trim()
    if ($ipInfo -match 'inet\s+([0-9.]+)') {
        $Ip = $matches[1]
    } else {
        # Fallback to route table
        $routeInfo = (& $adb -s $serial shell "ip route 2>/dev/null").Trim()
        if ($routeInfo -match 'src\s+([0-9.]+)') {
            $Ip = $matches[1]
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Ip)) {
    Write-Err "Could not automatically determine phone's Wi-Fi IP address."
    Write-Warn "Ensure your phone is connected to the same Wi-Fi network as this PC."
    Write-Warn "Find your IP on your phone in Settings -> About Phone -> Status -> IP Address,"
    Write-Warn "then run: .\wireless_adb.ps1 -Ip <your-phone-ip>"
    exit 1
}

Write-Success "Target Phone Wi-Fi IP: $Ip"

# Step 3: Switch ADB to TCP/IP mode
Write-Info "Enabling ADB TCP/IP mode on port $Port..."
& $adb -s $serial tcpip $Port | Out-Null
Start-Sleep -Seconds 2

# Step 4: Connect
Write-Info "Connecting to $Ip`:$Port..."
$connectRes = & $adb connect "$Ip`:$Port"
Write-Host $connectRes -ForegroundColor Green

if ($connectRes -like "*connected to*") {
    Write-Success "=========================================================="
    Write-Success " Wireless ADB connection established!"
    Write-Success " You can now UNPLUG your USB cable and deploy wirelessly!"
    Write-Success " Target address: $Ip`:$Port"
    Write-Success "=========================================================="
} else {
    Write-Warn "Could not connect wirelessly: $connectRes"
    Write-Warn "Ensure your PC and phone are on the exact same Wi-Fi network with client isolation disabled."
}

