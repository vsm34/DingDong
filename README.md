# DingDong — Smart Doorbell System

**SP26-41 · Rutgers University · Spring 2026**  
Varun Mantha · Vini Silva · Gian Rosario · Advisor: Dov Kruger

---

## What Is DingDong?

DingDong is a privacy-first smart doorbell system. Unlike Ring or Google Nest, DingDong stores all video **locally on a microSD card inside the device** — no cloud subscription, no monthly fees, no third-party servers ever touching your footage.

It uses **dual-sensor motion detection**: a PIR (body heat) sensor triggers first, and an mmWave radar sensor must confirm before any alert fires. This dramatically reduces false alarms from shadows, animals, or passing cars.

The system has three parts:
1. **Hardware** — Custom ESP32-S3 PCB with camera, sensors, SD card, buzzer, doorbell button
2. **Mobile App** — Flutter app (Android-first) for notifications, live view, event feed, clip playback
3. **Cloud** — Firebase for auth and push notifications only. No video ever reaches the cloud.

---

## Repository Structure

```
DingDong/
├── mobile/                    # Flutter mobile app
│   ├── lib/
│   │   ├── core/              # DDTheme, DDTypography, DDSpacing, DDColors
│   │   ├── components/        # DDButton, DDCard, DDListTile, DDTextField, etc.
│   │   ├── features/
│   │   │   ├── auth/          # Login, Signup, AccountSettings screens
│   │   │   ├── onboarding/    # 5-step SoftAP setup wizard
│   │   │   ├── events/        # Events feed, Event detail, Activity heatmap
│   │   │   ├── clips/         # Clip list, Clip player
│   │   │   ├── live_view/     # MJPEG live stream screen
│   │   │   ├── home/          # Home shell, Settings tab
│   │   │   └── settings/      # Device settings, Account settings, Remote access, Members, Privacy zones
│   │   ├── models/            # DdEvent, DdClip, DdDevice, DeviceSettings data models
│   │   ├── repositories/      # DeviceApi (Mock + Real), EventsRepo (Mock + Firestore)
│   │   ├── services/          # AiService (Claude API proxy)
│   │   ├── navigation/        # GoRouter setup, all routes, redirect logic
│   │   └── providers/         # All Riverpod providers
│   ├── assets/
│   │   ├── images/            # patio.jpg (login background)
│   │   └── lottie/            # Empty state and loading animations
│   └── pubspec.yaml
├── firmware/                  # ESP-IDF v5.x C++ firmware
│   ├── main/
│   │   ├── main.cpp           # Entry point, queue/task creation
│   │   ├── config/
│   │   │   └── dd_config.h    # All GPIO pins and system constants
│   │   ├── shared/
│   │   │   └── dd_types.h     # Shared structs, queue types, extern handles
│   │   ├── tasks/
│   │   │   ├── sensor_task.cpp    # PIR + mmWave + fusion logic
│   │   │   ├── camera_task.cpp    # OV5640 init + clip capture
│   │   │   ├── storage_task.cpp   # microSD read/write/list
│   │   │   ├── wifi_task.cpp      # Wi-Fi, SoftAP, HTTP server
│   │   │   └── stream_task.cpp    # Isolated MJPEG stream
│   │   └── api/
│   │       ├── http_server.cpp    # Route registration + CORS
│   │       ├── auth_middleware.cpp # Bearer token validation + rate limiting
│   │       ├── routes_public.cpp  # /provision endpoints (no auth)
│   │       ├── routes_protected.cpp # All protected endpoints
│   │       └── notify_client.cpp  # HMAC signing + Cloud Function POST
│   ├── CMakeLists.txt
│   └── sdkconfig.defaults
├── cloud/
│   ├── functions/
│   │   ├── index.js           # All Cloud Functions (notify, generateEventSummary, aiSupportChat, etc.)
│   │   ├── hmac.js            # HMAC verification helper
│   │   └── package.json
│   ├── firestore.rules        # Firestore security rules
│   └── .env.example
└── docs/
    ├── PRD.md                 # Full product requirements (source of truth)
    ├── API.md                 # Device API contract quick reference
    ├── SECURITY.md            # Security checklist
    ├── HANDOVER.md            # Setup, credentials, Git workflow, running the app
    ├── FIRMWARE_GUIDE.md      # Every firmware file explained, build + flash instructions
    ├── APP_GUIDE.md           # Every app screen explained with firmware connections
    └── TEST_CHECKLIST.md      # Complete test plan for hardware bring-up and validation
```

---

## Read These Docs In This Order

1. **[HANDOVER.md](docs/HANDOVER.md)** — Start here. Setup, credentials, how to run the app.
2. **[FIRMWARE_GUIDE.md](docs/FIRMWARE_GUIDE.md)** — Complete firmware explanation and flash instructions.
3. **[APP_GUIDE.md](docs/APP_GUIDE.md)** — Every app screen and how it connects to firmware.
4. **[TEST_CHECKLIST.md](docs/TEST_CHECKLIST.md)** — Complete test plan for hardware bring-up.

---

## Firebase Project

- **Project ID:** `dingdong-596c2`
- **Region:** `us-central1`
- **Android package:** `com.dingdong.app`
- **Console:** https://console.firebase.google.com/project/dingdong-596c2

---

## Test Credentials

| Field | Value |
|-------|-------|
| Email | test@dingdong.com |
| Password | testpass1 |

This account is pre-configured in Firebase. You can also create a new account from the app.

---

## Quick Links

- Firebase Console: https://console.firebase.google.com/project/dingdong-596c2
- Firestore: https://console.firebase.google.com/project/dingdong-596c2/firestore
- Firebase Auth: https://console.firebase.google.com/project/dingdong-596c2/authentication
- Cloud Functions: https://console.firebase.google.com/project/dingdong-596c2/functions
- Anthropic Console: https://console.anthropic.com
