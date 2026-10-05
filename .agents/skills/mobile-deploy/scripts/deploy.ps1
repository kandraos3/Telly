<#
.SYNOPSIS
    Automated one-command build, installation, and execution of the Telly app on a physical phone or emulator.

.DESCRIPTION
    1. Verifies ADB and Flutter toolchain.
    2. Detects connected target device (waits if authorization is pending).
    3. Detects phone CPU architecture (arm64-v8a) for hyper-fast builds.
    4. Compiles the APK or runs interactive Flutter live session.
    5. Sideloads and launches app.telly.mobile/.MainActivity on the phone.

.PARAMETER Mode
    'install'    - Compiles APK and pushes via ADB, starts app immediately (Default).
    'release'    - Compiles production release APK with upload keystore, installs, and starts.
    'run'        - Launches interactive 'flutter run' with live hot reload (r/R).
    'build-only' - Compiles the APK without pushing to device.

.PARAMETER Device
    Specific ADB serial or Flutter device ID. Auto-detected if omitted.

.PARAMETER Clean
    Performs 'flutter clean' and 'flutter pub get' before building.

.PARAMETER Uninstall
    Uninstalls previous installation of app.telly.mobile to test fresh onboarding/database migrations.

.PARAMETER FollowLogs
    Streams live Flutter/Telly logcat output after launching.

.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -Mode release
    .\deploy.ps1 -Mode run
    .\deploy.ps1 -Clean -Uninstall
    .\deploy.ps1 -FollowLogs
#>

[CmdletBinding()]
param(
    [ValidateSet("install", "release", "run", "build-only")]
    [string]$Mode = "install",

    [string]$Device = "",

    [string]$EnvFile = "env/dev.json",

    [switch]$Clean,

    [switch]$Uninstall,

    [switch]$Quick,

    [switch]$FollowLogs
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$msg) { Write-Host "`n>>> $msg" -ForegroundColor Cyan }
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
    Write-Err "Android Debug Bridge (adb.exe) could not be located."
    exit 1
}

# Auto-detect Android Studio JBR for JAVA_HOME if not already in environment
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    $jbrCandidates = @(
        "C:\Program Files\Android\Android Studio\jbr",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr",
        "C:\Program Files\Android\Android Studio\jre"
    )
    foreach ($cand in $jbrCandidates) {
        if (Test-Path $cand) {
            $env:JAVA_HOME = $cand
            $env:PATH = "$cand\bin;$env:PATH"
            break
        }
    }
}

# Locate project root (pubspec.yaml directory)
$projectRoot = $null
$candidateRoot = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
if (Test-Path (Join-Path $candidateRoot "pubspec.yaml")) {
    $projectRoot = $candidateRoot
} else {
    $walk = (Get-Location).Path
    while ($walk) {
        if (Test-Path (Join-Path $walk "pubspec.yaml")) {
            $projectRoot = $walk
            break
        }
        $parent = Split-Path -Parent $walk
        if ($parent -eq $walk) { break }
        $walk = $parent
    }
}
if (-not $projectRoot) {
    $projectRoot = (Get-Location).Path
}
Set-Location $projectRoot
$startTime = Get-Date

Write-Host "==========================================================" -ForegroundColor DarkCyan
Write-Host "        TELLY MOBILE APPLICATION DEPLOYMENT               " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor DarkCyan
Write-Host " Project Root: $projectRoot" -ForegroundColor Gray
Write-Host " Mode:         $Mode" -ForegroundColor Gray

# -------------------------------------------------------------------------
# Step 1: Detect and Validate Target Device
# -------------------------------------------------------------------------
if ($Mode -ne "build-only") {
    Write-Step "Detecting target mobile device..."

    function Get-Devices {
        $raw = & $adb devices -l
        $list = @()
        foreach ($line in ($raw -split "`r?`n")) {
            $trim = $line.Trim()
            if ($trim -like "List of devices*" -or [string]::IsNullOrWhiteSpace($trim)) { continue }
            $parts = -split $trim
            if ($parts.Length -ge 2) {
                $list += [PSCustomObject]@{
                    Serial = $parts[0]
                    State  = $parts[1]
                }
            }
        }
        return $list
    }

    $devs = Get-Devices

    # Check for unauthorized device and wait for user interaction
    $unauth = $devs | Where-Object { $_.State -eq "unauthorized" }
    if ($unauth) {
        Write-Warn "Device $($unauth[0].Serial) is currently UNAUTHORIZED."
        Write-Host "Please unlock your phone now and tap 'Allow USB debugging' (or 'Always allow')." -ForegroundColor Yellow
        Write-Host "Waiting up to 45 seconds for your authorization..." -ForegroundColor Yellow

        $deadline = (Get-Date).AddSeconds(45)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 2
            $devs = Get-Devices
            if (-not ($devs | Where-Object { $_.State -eq "unauthorized" })) {
                Write-Success "Device authorized!"
                break
            }
            Write-Host "." -NoNewline -ForegroundColor Yellow
        }
        Write-Host ""
    }

    $authorized = $devs | Where-Object { $_.State -eq "device" }
    if ($authorized.Count -eq 0) {
        Write-Err "No authorized device detected."
        Write-Warn "Run: .agents/skills/mobile-deploy/scripts/device_doctor.ps1 to troubleshoot."
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($Device)) {
        $targetDevice = $authorized[0].Serial
    } else {
        $targetDevice = $Device
    }

    $devModel = (& $adb -s $targetDevice shell getprop ro.product.model).Trim()
    $devAbi = (& $adb -s $targetDevice shell getprop ro.product.cpu.abi).Trim()
    $devOs = (& $adb -s $targetDevice shell getprop ro.build.version.release).Trim()

    Write-Success "Target Device: $devModel ($targetDevice)"
    Write-Host "    Architecture: $devAbi | Android OS: $devOs" -ForegroundColor Gray
}

# -------------------------------------------------------------------------
# Step 2: Clean & Prep (Optional)
# -------------------------------------------------------------------------
if ($Clean) {
    Write-Step "Running flutter clean & pub get..."
    flutter clean
    flutter pub get
    Write-Success "Workspace cleaned."
}

# -------------------------------------------------------------------------
# Step 3: Uninstall Previous Build (Optional)
# -------------------------------------------------------------------------
if ($Uninstall -and $Mode -ne "build-only") {
    Write-Step "Uninstalling app.telly.mobile for a clean state..."
    & $adb -s $targetDevice uninstall app.telly.mobile | Out-Null
    Write-Success "Previous version uninstalled."
}

# -------------------------------------------------------------------------
# Step 4: Execution / Build / Deployment
$envPath = Join-Path $projectRoot $EnvFile
$defineArgs = @()
if (Test-Path $envPath) {
    Write-Info "Injecting environment variables from: $EnvFile"
    $defineArgs += "--dart-define-from-file=$envPath"
} else {
    Write-Warn "Config file $envPath not found! Build may be missing runtime values."
}

if ($Mode -eq "run") {
    Write-Step "Starting interactive Flutter run on $targetDevice..."
    Write-Host "Use 'r' for hot reload, 'R' for hot restart, 'q' to quit." -ForegroundColor Yellow
    flutter run -d $targetDevice @defineArgs
    exit 0
}

# Map target ABI for faster compilation
$targetPlatform = switch ($devAbi) {
    "arm64-v8a"   { "android-arm64" }
    "armeabi-v7a" { "android-arm" }
    "x86_64"      { "android-x64" }
    Default       { $null }
}

$buildArgs = @("build", "apk")
if ($Mode -eq "release") {
    $buildArgs += "--release"
} else {
    $buildArgs += "--debug"
}

if ($targetPlatform) {
    $buildArgs += "--target-platform=$targetPlatform"
}

if ($defineArgs) {
    $buildArgs += $defineArgs
}

$apkDir = "$projectRoot\build\app\outputs\flutter-apk"
$existingApk = if ($Mode -eq "release") {
    Get-ChildItem -Path $apkDir -Filter "*release*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
} else {
    Get-ChildItem -Path $apkDir -Filter "*debug*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

if ($Quick -and $existingApk -and (Test-Path $existingApk)) {
    Write-Info "Quick mode enabled: skipping recompilation, using existing APK."
    $apkFile = $existingApk
} else {
    # Clean stale intermediate & generated build files to prevent Windows Gradle locking issue
    $staleDirs = @(
        "$projectRoot\build\app\intermediates",
        "$projectRoot\build\app\generated"
    )
    foreach ($d in $staleDirs) {
        if (Test-Path $d) {
            Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
        }
    }

    Write-Step "Compiling APK (flutter $($buildArgs -join ' '))..."
    & flutter @buildArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Build failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }

    $apkFile = if ($Mode -eq "release") {
        Get-ChildItem -Path $apkDir -Filter "*release*.apk" | Select-Object -First 1 -ExpandProperty FullName
    } else {
        Get-ChildItem -Path $apkDir -Filter "*debug*.apk" | Select-Object -First 1 -ExpandProperty FullName
    }
}

if (-not $apkFile -or -not (Test-Path $apkFile)) {
    Write-Err "Could not find generated APK in $apkDir"
    exit 1
}

$apkSizeMb = [math]::Round(((Get-Item $apkFile).Length / 1MB), 2)
Write-Success "APK ready: $(Split-Path -Leaf $apkFile) ($apkSizeMb MB)"

if ($Mode -eq "build-only") {
    Write-Success "Build completed in $((Get-Date) - $startTime)."
    Write-Host "Output: $apkFile" -ForegroundColor Cyan
    exit 0
}

# -------------------------------------------------------------------------
# Step 5: Sideload & Launch
# -------------------------------------------------------------------------
Write-Step "Sideloading APK to $targetDevice..."
$installRaw = (& $adb -s $targetDevice install -r -d $apkFile 2>&1)
$installStr = ($installRaw -join "`n")

if ($installStr -notlike "*Success*") {
    if ($installStr -like "*INSTALL_FAILED_UPDATE_INCOMPATIBLE*") {
        Write-Warn "Signature mismatch detected (old installation had different signing certificate)."
        Write-Info "Automatically uninstalling previous build and retrying..."
        & $adb -s $targetDevice uninstall app.telly.mobile | Out-Null
        $installRaw = (& $adb -s $targetDevice install -r -d $apkFile 2>&1)
        $installStr = ($installRaw -join "`n")
    }
}

if ($installStr -notlike "*Success*") {
    Write-Err "ADB install failed: $installStr"
    exit 1
}
Write-Success "APK installed successfully."

Write-Step "Launching app.telly.mobile on phone screen..."
& $adb -s $targetDevice shell am force-stop app.telly.mobile | Out-Null
& $adb -s $targetDevice shell am start -n app.telly.mobile/.MainActivity | Out-Null

Start-Sleep -Seconds 1
$rawPid = (& $adb -s $targetDevice shell pidof app.telly.mobile)
$pidRes = if ($rawPid) { "$rawPid".Trim() } else { "Running" }

$totalElapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  TELLY IS NOW RUNNING ON YOUR PHONE!                    " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Device:       $devModel ($targetDevice)" -ForegroundColor White
Write-Host "  Package:      app.telly.mobile" -ForegroundColor White
Write-Host "  Process PID:  $pidRes" -ForegroundColor White
Write-Host "  Total Time:   $totalElapsed seconds" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""

if ($FollowLogs) {
    Write-Step "Streaming live logs (press Ctrl+C to stop)..."
    & $adb -s $targetDevice logcat -v time -s flutter:V telly:V *:E
}

