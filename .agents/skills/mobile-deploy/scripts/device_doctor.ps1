<#
.SYNOPSIS
    Diagnoses, validates, and authorizes connected mobile devices for Telly app deployment.

.DESCRIPTION
    Checks ADB availability, scans connected physical and virtual devices, detects
    unauthorized USB debugging states, provides resolution steps, and inspects
    device specs (ABI, Android OS, battery, screen density, Wi-Fi IP).

.PARAMETER RestartServer
    Restarts the ADB server daemon before scanning.

.PARAMETER Wait
    Wait loop (in seconds) to allow the user to unlock their phone and accept the RSA key prompt.

.EXAMPLE
    .\device_doctor.ps1
    .\device_doctor.ps1 -Wait 30
    .\device_doctor.ps1 -RestartServer
#>

param(
    [switch]$RestartServer,
    [int]$Wait = 0
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-Success([string]$msg) {
    Write-Host "[OK]   $msg" -ForegroundColor Green
}

function Write-Warn([string]$msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-Err([string]$msg) {
    Write-Host "[ERR]  $msg" -ForegroundColor Red
}

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

function Ensure-JavaHome {
    if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
        $jbrCandidates = @(
            "C:\Program Files\Android\Android Studio\jbr",
            "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
        )
        foreach ($c in $jbrCandidates) {
            if (Test-Path $c) {
                $env:JAVA_HOME = $c
                $env:PATH = "$c\bin;$env:PATH"
                break
            }
        }
    }
}

Ensure-JavaHome

Write-Host "==========================================================" -ForegroundColor DarkCyan
Write-Host "   Telly Mobile Device Doctor (Antigravity Mobile-Deploy) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor DarkCyan

$adb = Get-AdbExecutable
if (-not $adb) {
    Write-Err "Android Debug Bridge (adb.exe) could not be found."
    Write-Warn "Please install Android Studio / Android SDK Platform-Tools or set ANDROID_HOME."
    exit 1
}

Write-Success "Found ADB: $adb"

if ($RestartServer) {
    Write-Info "Restarting ADB daemon..."
    & $adb kill-server | Out-Null
    Start-Sleep -Seconds 1
    & $adb start-server | Out-Null
    Write-Success "ADB daemon restarted."
}

function Get-AttachedDevices {
    $raw = & $adb devices -l
    $lines = $raw -split "`r?`n"
    $list = @()

    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trim) -or $trim -like "List of devices*") {
            continue
        }
        $parts = -split $trim
        if ($parts.Length -ge 2) {
            $serial = $parts[0]
            $state = $parts[1]
            $extra = ($parts[2..($parts.Length - 1)]) -join " "
            $list += [PSCustomObject]@{
                Serial = $serial
                State  = $state
                Extra  = $extra
            }
        }
    }
    return $list
}

$devices = Get-AttachedDevices

if ($Wait -gt 0 -and ($devices | Where-Object { $_.State -eq "unauthorized" })) {
    Write-Warn "Detected unauthorized device. Waiting up to $Wait seconds for user authorization on phone..."
    $deadline = (Get-Date).AddSeconds($Wait)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $devices = Get-AttachedDevices
        $unauth = $devices | Where-Object { $_.State -eq "unauthorized" }
        if (-not $unauth) {
            Write-Success "Device authorization detected!"
            break
        }
        Write-Host "." -NoNewline -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($devices.Count -eq 0) {
    Write-Warn "No attached mobile devices found."
    Write-Host "`nTroubleshooting Checklist:" -ForegroundColor White
    Write-Host "  1. Ensure your phone is connected to this PC via USB."
    Write-Host "  2. On your phone, go to Settings -> About Phone -> tap 'Build Number' 7 times to enable Developer Options."
    Write-Host "  3. In Settings -> Developer Options, turn ON 'USB Debugging'."
    Write-Host "  4. If prompted on your phone screen, select 'Transfer files' (MTP) instead of 'Charging only'."
    Write-Host "  5. Re-run: .\device_doctor.ps1 -RestartServer`n"
    exit 0
}

Write-Host "`nAttached Devices:" -ForegroundColor White
foreach ($dev in $devices) {
    if ($dev.State -eq "device") {
        Write-Host "  * [AUTHORIZED] Serial: $($dev.Serial)" -ForegroundColor Green
        
        # Query device metadata
        $model = (& $adb -s $dev.Serial shell getprop ro.product.model).Trim()
        $brand = (& $adb -s $dev.Serial shell getprop ro.product.brand).Trim()
        $androidVer = (& $adb -s $dev.Serial shell getprop ro.build.version.release).Trim()
        $apiLevel = (& $adb -s $dev.Serial shell getprop ro.build.version.sdk).Trim()
        $abi = (& $adb -s $dev.Serial shell getprop ro.product.cpu.abi).Trim()
        
        # Wi-Fi IP
        $ipInfo = ((& $adb -s $dev.Serial shell "ip -f inet addr show wlan0 2>/dev/null") -join "`n").Trim()
        $ip = "Unknown / Not on Wi-Fi"
        if ($ipInfo -match 'inet\s+([0-9.]+)') {
            $ip = $Matches[1]
        }

        # Battery
        $battRaw = ((& $adb -s $dev.Serial shell "dumpsys battery 2>/dev/null") -join "`n").Trim()
        $battLevel = "Unknown"
        if ($battRaw -match 'level:\s*(\d+)') {
            $battLevel = "$($Matches[1])%"
        }

        # App status
        $appInstalled = (& $adb -s $dev.Serial shell "pm list packages app.telly.mobile").Trim()
        $appStatus = if ($appInstalled -like "*app.telly.mobile*") { "Installed" } else { "Not Installed" }

        Write-Host "      Device:       $brand $model" -ForegroundColor Gray
        Write-Host "      Android OS:   $androidVer (API $apiLevel)" -ForegroundColor Gray
        Write-Host "      CPU ABI:      $abi" -ForegroundColor Gray
        Write-Host "      Battery:      $battLevel" -ForegroundColor Gray
        Write-Host "      Wi-Fi IP:     $ip" -ForegroundColor Gray
        Write-Host "      Telly Status: $appStatus" -ForegroundColor Gray
    }
    elseif ($dev.State -eq "unauthorized") {
        Write-Host "  * [UNAUTHORIZED] Serial: $($dev.Serial)" -ForegroundColor Yellow
        Write-Warn "    ACTION REQUIRED ON YOUR PHONE:"
        Write-Host "    1. Unlock your phone screen now." -ForegroundColor White
        Write-Host "    2. Look for the prompt: 'Allow USB debugging?'" -ForegroundColor White
        Write-Host "    3. Check the box: 'Always allow from this computer'" -ForegroundColor White
        Write-Host "    4. Tap 'Allow' or 'OK'." -ForegroundColor White
        Write-Host "    5. Run: .\device_doctor.ps1 -Wait 30" -ForegroundColor Cyan
    }
    else {
        Write-Host "  * [$($dev.State.ToUpper())] Serial: $($dev.Serial)" -ForegroundColor Red
        Write-Warn "    Device is in $($dev.State) state. Try unplugging and re-plugging USB."
    }
}

Write-Host ""

