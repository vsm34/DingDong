# DingDong — Handover Guide

**For:** Vini Silva and Gian Rosario  
**From:** Varun Mantha  
**Purpose:** Everything you need to set up your environment, run the app, and begin hardware bring-up.

---

## Table of Contents

1. [Test Credentials](#1-test-credentials)
2. [Prerequisites — What to Install](#2-prerequisites--what-to-install)
3. [Clone the Repository](#3-clone-the-repository)
4. [Running the App on Chrome (Web)](#4-running-the-app-on-chrome-web)
5. [Running the App on Android](#5-running-the-app-on-android)
6. [Firebase Setup](#6-firebase-setup)
7. [ESP-IDF Setup for Firmware](#7-esp-idf-setup-for-firmware)
8. [Git Workflow and Issue Reporting](#8-git-workflow-and-issue-reporting)
9. [Project Secrets Reference](#9-project-secrets-reference)
10. [Who to Contact for What](#10-who-to-contact-for-what)

---

## 1. Test Credentials

| Field | Value |
|-------|-------|
| App email | test@dingdong.com |
| App password | testpass1 |
| Firebase project | dingdong-596c2 |

You can also create a new account directly in the app — signup is fully working.

---

## 2. Prerequisites — What to Install

Install everything in this section before doing anything else. Do it in order.

### 2.1 Flutter and Dart

Flutter includes Dart. Install Flutter only.

1. Go to https://flutter.dev/docs/get-started/install
2. Choose **Windows**
3. Download the Flutter SDK zip and extract to `C:\flutter`
4. Add `C:\flutter\bin` to your system PATH
5. Open a new terminal and run:
   ```
   flutter doctor
   ```
6. Flutter doctor will tell you what else is missing. Fix everything it flags.

**Required Flutter version:** 3.19.0 or higher  
**Required Dart version:** 3.3.0 or higher (included with Flutter)

Verify with:
```
flutter --version
dart --version
```

### 2.2 Android Studio

Required for Android emulator and Android SDK tools.

1. Go to https://developer.android.com/studio
2. Download and install Android Studio
3. During setup, accept all SDK licenses
4. Open Android Studio → SDK Manager → install:
   - Android SDK Platform 34 (Android 14)
   - Android SDK Build-Tools 34
   - Android Emulator
   - Android SDK Platform-Tools
5. Run `flutter doctor` again — it should now show Android toolchain as OK

### 2.3 Java (JDK)

Android builds require Java.

1. Go to https://www.oracle.com/java/technologies/downloads/
2. Download JDK 17 (LTS) for Windows
3. Install and add to PATH
4. Verify: `java -version`

### 2.4 Node.js

Required for Firebase CLI and Cloud Functions.

1. Go to https://nodejs.org
2. Download LTS version (20.x or higher)
3. Install with default settings
4. Verify: `node --version` and `npm --version`

### 2.5 Firebase CLI

1. Open terminal and run:
   ```
   npm install -g firebase-tools
   ```
2. Log in:
   ```
   firebase login
   ```
3. Use the Google account that has access to the `dingdong-596c2` Firebase project
4. Verify:
   ```
   firebase projects:list
   ```
   You should see `dingdong-596c2` in the list.

### 2.6 Git

1. Go to https://git-scm.com/download/win
2. Download and install Git for Windows
3. During install, choose "Git from the command line and also from 3rd-party software"
4. Verify: `git --version`

### 2.7 ESP-IDF (for firmware only)

This is the development framework for the ESP32-S3. Only needed when working on firmware.

1. Go to https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/get-started/windows-setup.html
2. Download the **ESP-IDF Windows Installer** (offline installer recommended)
3. Run the installer — it installs everything including Python, CMake, and the toolchain
4. Choose ESP32-S3 as the target chip during setup
5. After install, a shortcut "ESP-IDF 5.x CMD" will appear on your desktop — use this terminal for all firmware commands
6. Verify by opening the ESP-IDF CMD and running:
   ```
   idf.py --version
   ```

**Important:** Before running any firmware command in this repo, always run from the repo root first:
```
. .\esp-idf-init.ps1
```
This sets up the correct environment variables for the project.

### 2.8 Visual Studio Code (Recommended Editor)

1. Go to https://code.visualstudio.com
2. Install the following extensions:
   - Flutter
   - Dart
   - ESP-IDF (from Espressif)
   - C/C++ (from Microsoft)
   - Firebase
3. The C++ red underlines in firmware files are an IntelliSense issue only — the actual build (`idf.py build`) still works. To fix IntelliSense: open Command Palette → "ESP-IDF: Add vscode Configuration Folder"

### 2.9 Summary Checklist

Before continuing, confirm all of these pass:

```
flutter doctor          # Should show no critical errors
node --version          # Should show v20.x or higher
npm --version           # Should show 10.x or higher
firebase --version      # Should show 13.x or higher
git --version           # Should show 2.x or higher
java -version           # Should show 17.x
```

---

## 3. Clone the Repository

1. Open a terminal in the folder where you want to put the project
2. Run:
   ```
   git clone https://github.com/vsm34/DingDong.git
   cd DingDong
   ```
3. Install Flutter dependencies:
   ```
   cd mobile
   flutter pub get
   cd ..
   ```
4. Install Cloud Function dependencies:
   ```
   cd cloud/functions
   npm install
   cd ../..
   ```

You should now have the full project on your machine.

---

## 4. Running the App on Chrome (Web)

Running on Chrome is useful for testing UI and auth features without a phone. Some features (live view, clips, mDNS) do not work on web because they require a real device on the same network.

1. Make sure Chrome is installed
2. Open terminal in the `mobile/` folder
3. Run:
   ```
   flutter run -d chrome
   ```
4. The app will compile and open in Chrome automatically
5. Log in with `test@dingdong.com` / `testpass1`

**What works on Chrome:**
- Login, signup, account settings
- Events feed (shows empty state — no real device yet)
- Settings tab
- Activity heatmap (empty — no events yet)
- AI Support chat
- Onboarding screens (visual only — cannot actually provision a device)

**What does NOT work on Chrome:**
- Live view (requires real MJPEG stream from device)
- Clip browsing/playback (requires device on LAN)
- Device settings loading (requires device on LAN)
- Push notifications (requires Android FCM)
- mDNS device discovery (web browsers cannot do mDNS)

---

## 5. Running the App on Android

This is the full experience. The app is designed for Android first.

### 5.1 Enable Developer Mode on the Android Phone

1. Go to **Settings → About Phone**
2. Tap **Build Number** 7 times until you see "You are now a developer"
3. Go back to **Settings → Developer Options**
4. Turn on **USB Debugging**

### 5.2 Connect Phone to Computer

1. Connect the phone via USB cable
2. On the phone, when prompted, choose **"File Transfer"** or **"MTP"** mode
3. Accept the "Allow USB debugging" dialog on the phone
4. In terminal, run:
   ```
   flutter devices
   ```
   Your phone should appear in the list with a device ID.

### 5.3 Run the App on Android

```
cd mobile
flutter run
```

If you have multiple devices connected, Flutter will ask you to choose. Select your Android phone.

The app will build and install on the phone. First build takes 2-5 minutes. Subsequent builds are faster.

### 5.4 Build a Release APK (for installing without USB)

```
cd mobile
flutter build apk --release
```

The APK file will be at: `mobile/build/app/outputs/flutter-apk/app-release.apk`

Transfer this file to the phone and install it. You may need to allow "Install from unknown sources" in Android settings.

### 5.5 What the App Looks Like on First Launch (No Device Paired)

1. Splash screen → Login screen
2. Sign in with test credentials
3. Since no device is paired, app routes to **Onboarding Welcome** screen
4. Tap **Skip for now** to go to the home screen
5. Events tab shows empty state with "Add Device" button
6. Settings tab shows the device card as offline

This is expected behavior. Once the ESP32 is provisioned, the app will connect automatically.

---

## 6. Firebase Setup

The Firebase project is already set up. You do not need to create anything. This section covers what exists and how to access it.

### 6.1 Firebase Console Access

Go to: https://console.firebase.google.com/project/dingdong-596c2

Ask Varun to add your Google account as a project member if you do not have access.

### 6.2 What's Already Set Up

| Service | Status | What It Does |
|---------|--------|-------------|
| Firebase Auth | Live | Email/password login for the app |
| Firestore | Live | Stores event metadata, device registry, user data |
| Cloud Messaging (FCM) | Live | Sends push notifications to Android devices |
| Cloud Functions | Live | notify, generateEventSummary, aiSupportChat, testNotify, provisionSecret |
| Secret Manager | Live | Stores ANTHROPIC_API_KEY securely |
| Firestore Rules | Deployed | Security rules restricting data access |

### 6.3 Deploying Updates to Cloud Functions

If you ever need to redeploy:
```
firebase deploy --only functions
```

If you only want to redeploy one function:
```
firebase deploy --only functions:notify
```

### 6.4 Viewing Cloud Function Logs

```
firebase functions:log
```

Or for a specific function:
```
firebase functions:log --only notify
```

### 6.5 Checking Firestore Data

Go to: https://console.firebase.google.com/project/dingdong-596c2/firestore

Collections you will see during testing:
- `users/` — one document per user account
- `devices/` — one document per paired device (created during onboarding)
- `deviceMembers/` — links users to devices (format: `{deviceId}_{uid}`)
- `events/` — one document per motion or doorbell event
- `nonces/` — short-lived nonce records for HMAC replay protection

---

## 7. ESP-IDF Setup for Firmware

### 7.1 First Time Setup

1. Open the **ESP-IDF 5.x CMD** shortcut (installed by the ESP-IDF Windows Installer)
2. Navigate to the repo root:
   ```
   cd C:\path\to\DingDong
   ```
3. Run the environment init script:
   ```
   . .\esp-idf-init.ps1
   ```
4. Navigate to the firmware folder:
   ```
   cd firmware
   ```

### 7.2 Set the Target Chip

Only needed once per machine:
```
idf.py set-target esp32s3
```

### 7.3 Build the Firmware

```
idf.py build
```

A successful build ends with:
```
Project build complete. To flash, run:
idf.py -p (PORT) flash
```

### 7.4 Flash the Firmware to the ESP32

1. Connect the ESP32-S3 DevKit to your computer via USB
2. Check which COM port it appears on (Device Manager → Ports)
3. Run (replace COM3 with your actual port):
   ```
   idf.py -p COM3 flash monitor
   ```
4. This flashes the firmware and opens the serial monitor
5. Expected serial output after a successful flash:
   ```
   I (xxx) main: DingDong booting...
   I (xxx) storage: SD card mounted
   I (xxx) camera: Camera ready
   I (xxx) wifi: SoftAP started: DingDong-Setup
   ```

### 7.5 Serial Monitor Only (Without Flashing)

```
idf.py -p COM3 monitor
```

Press `Ctrl+]` to exit the monitor.

### 7.6 Menuconfig (Advanced Settings)

```
idf.py menuconfig
```

This opens the ESP-IDF configuration menu. Do not change settings unless you know what you are doing. The defaults in `sdkconfig.defaults` are correct for this project.

---

## 8. Git Workflow and Issue Reporting

### 8.1 Basic Git Commands

Check what branch you are on:
```
git branch
```

Pull the latest changes from main:
```
git pull origin main
```

See what files you changed:
```
git status
```

See detailed changes:
```
git diff
```

### 8.2 Branching Strategy

**Never commit directly to `main`.** Use branches for all changes.

Create a new branch for your work:
```
git checkout -b firmware/sensor-calibration
```

Branch naming convention:
- `firmware/description` — for firmware changes
- `fix/description` — for bug fixes
- `test/description` — for test scripts

Push your branch to GitHub:
```
git push origin firmware/sensor-calibration
```

### 8.3 Making a Commit

```
git add .
git commit -m "Brief description of what changed"
git push
```

Keep commit messages clear and specific. Good examples:
- `"Tune mmWave distance threshold to 3.5m"`
- `"Fix sensor_task: PIR debounce timing off by one"`
- `"Add curl test for /health endpoint"`

### 8.4 Issue Reporting

**Rule:** If the issue is in firmware C++ code → you can fix it directly and commit.

**Rule:** If the issue is in the Flutter app or Cloud Functions → document it and notify Varun.

When you find an app or backend issue, document it like this:

```
## Issue: [Short title]

**Where:** [Screen name or Cloud Function name]
**When:** [What action triggers it]
**What happens:** [Describe the bug]
**What should happen:** [Describe correct behavior]
**Screenshot/log:** [Attach if possible]
**Severity:** Critical / High / Medium / Low
```

Send this to Varun via WhatsApp or create a GitHub Issue at:
https://github.com/vsm34/DingDong/issues

### 8.5 Running Security Checks Before Demo

From the repo root:
```
# Verify no secrets were ever committed
git log --all -- "*/google-services.json"
git log --all -- ".env"
git log --all -- "serviceAccount*"
```

All three commands should return no output. If they return anything, contact Varun immediately.

---

## 9. Project Secrets Reference

| Secret | Where It Lives | How to Access |
|--------|---------------|--------------|
| ANTHROPIC_API_KEY | Firebase Secret Manager | `firebase functions:secrets:access ANTHROPIC_API_KEY` |
| Device Bearer token | ESP32 NVS + phone's secure storage | Automatically managed during onboarding |
| device_secret (HMAC key) | Firebase Secret Manager + ESP32 NVS | Automatically provisioned during onboarding |
| Firebase config | `mobile/android/google-services.json` | Already in repo (client config, not a server key) |
| Wi-Fi password | ESP32 NVS only | Never stored in cloud or app |

**Never commit any of these to Git.** The `.gitignore` is already set up to block the most common ones.

---

## 10. Who to Contact for What

| Issue Type | Who Handles It | How to Contact |
|-----------|----------------|---------------|
| Flutter app bugs (UI, routing, auth) | Varun | Messages / Github |
| Cloud Function bugs | Varun | Messages / GitHub  |
| Firebase configuration | Varun | Messages |
| Firmware bugs (C++ code) | Vini / Gian | Fix directly, commit to branch |
| Hardware issues (PCB, sensors, power) | Vini / Gian | Handle directly |
| Anthropic API / AI features | Varun | Messages |
| GPIO pin questions | Check PRD Section 15.2 | See FIRMWARE_GUIDE.md |
