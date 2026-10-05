---
name: mobile-deploy
description: Automated workflow and CLI toolchain to detect, authorize, build, install, and live-run the Telly mobile application on connected physical smartphones (Android via USB/Wireless ADB, iOS) and emulators.
---

# Mobile Deploy Skill: Telly Smartphone Deployment & Run Guide

This skill standardizes how agents and developers build, sideload, and execute the Telly Flutter application on physical smartphones and local emulators.

---

## 🛠️ Toolchain & Scripts Directory

All deployment scripts reside in [`.agents/skills/mobile-deploy/scripts/`](file:///c:/Users/karla/Desktop/SeriesBeli/.agents/skills/mobile-deploy/scripts):

| Script | Purpose | Common Command |
|---|---|---|
| [`deploy.ps1`](file:///c:/Users/karla/Desktop/SeriesBeli/.agents/skills/mobile-deploy/scripts/deploy.ps1) | **Master deployment script**. Auto-detects device ABI, compiles APK, sideloads, and launches `app.telly.mobile`. | `powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/deploy.ps1` |
| [`device_doctor.ps1`](file:///c:/Users/karla/Desktop/SeriesBeli/.agents/skills/mobile-deploy/scripts/device_doctor.ps1) | **Device diagnostics**. Inspects ADB, scans connected devices, resolves `unauthorized` prompt, checks battery, Wi-Fi IP, and specs. | `powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/device_doctor.ps1 -Wait 30` |
| [`wireless_adb.ps1`](file:///c:/Users/karla/Desktop/SeriesBeli/.agents/skills/mobile-deploy/scripts/wireless_adb.ps1) | **Wireless setup**. Enables ADB over TCP/IP (port 5555) on local Wi-Fi so you can unplug the USB cable and deploy over the air. | `powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/wireless_adb.ps1` |

---

## 📱 Physical Phone Prerequisites

### Android Setup (USB)
1. **Enable Developer Options**:
   - Go to **Settings** > **About Phone**.
   - Tap **Build Number** 7 times rapidly until "You are now a developer!" appears.
2. **Enable USB Debugging**:
   - Go to **Settings** > **System** (or **Additional Settings**) > **Developer Options**.
   - Toggle **USB Debugging** to **ON**.
   - (Recommended) Toggle **Install via USB** to **ON** (especially on Xiaomi / MIUI / HyperOS / Oppo / Vivo devices).
3. **Connect & Authorize**:
   - Connect the phone to your PC via a USB data cable.
   - Set USB mode to **File Transfer / MTP** (not "Charging Only").
   - Look at your phone screen: a popup will ask **"Allow USB debugging?"**.
   - Check the box: **"Always allow from this computer"** and tap **Allow / OK**.

---

## 🚀 Execution Workflows

### 1. Fast Deploy to Phone (Recommended)
Builds a targeted debug APK for your phone's architecture (e.g. `arm64-v8a`), sideloads it, and launches the app directly on your phone:
```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/deploy.ps1
```

### 2. Live Interactive Development (Hot Reload / DevTools)
Connects directly to the Flutter engine with live hot-reload (`r`), hot-restart (`R`), and DevTools URL:
```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/deploy.ps1 -Mode run
```

### 3. Production Release Build & Install
Compiles with R8 tree-shaking and the project release keystore (`upload-keystore.jks`) to verify production performance and smoothness:
```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/deploy.ps1 -Mode release
```

### 4. Cable-Free Wireless Deployment (Wi-Fi)
1. Plug phone via USB once.
2. Run wireless bridge:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/wireless_adb.ps1
   ```
3. Once connected, **unplug the USB cable**!
4. Subsequent calls to `deploy.ps1` deploy directly over your local Wi-Fi network.

### 5. Clean Reinstall (Reset Local Database & Auth State)
If testing database migrations, onboarding seeds, or fresh auth states:
```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/deploy.ps1 -Clean -Uninstall
```

### 6. Streaming Logs
View real-time application logs (Flutter print statements, exceptions, Drift SQL logs):
```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/deploy.ps1 -FollowLogs
```

---

## 🩺 Troubleshooting Guide

### Issue: "Device `<serial>` is unauthorized"
- **Cause**: The phone has not yet accepted the PC's RSA debugging key.
- **Fix**: Run:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/device_doctor.ps1 -Wait 30
  ```
  Unlock your phone, tap **Allow** on the dialog. The doctor script will automatically detect authorization.

### Issue: "INSTALL_FAILED_USER_RESTRICTED"
- **Cause**: Common on Xiaomi / Redmi / POCO / Realme devices. The OS requires an explicit setting to allow installing APKs via USB.
- **Fix**: In Developer Options, enable **Install via USB** (requires Mi/vendor account login).

### Issue: "adb.exe is not recognized"
- **Cause**: Android SDK platform-tools is not in the system `PATH`.
- **Fix**: The scripts automatically fall back to `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe` and `$env:ANDROID_HOME`. You can also add that directory to your Windows User PATH.

### Issue: ADB Daemon Hang / Freeze
- **Fix**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .agents/skills/mobile-deploy/scripts/device_doctor.ps1 -RestartServer
  ```

---

## 🍎 iOS Notes
For deploying to an iPhone:
- Requires a macOS host with Xcode installed and CocoaPods configured, or a CI/CD build artifact (e.g. TestFlight / Ad-Hoc `.ipa`).
- Under Windows, developers can test locally via Android device or Chrome/Edge web inspection (`flutter run -d chrome`).

