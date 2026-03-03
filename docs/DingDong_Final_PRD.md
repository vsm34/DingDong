

DingDong

Smart Doorbell System



FINAL PRODUCT REQUIREMENTS DOCUMENT

SP26-41 — Rutgers University

Gian Rosario · Vini Silva · Varun Mantha

Advisor: Dov Kruger

Version 2.0 — March 2026



# 1. Project Summary

DingDong is a privacy-focused smart doorbell system that eliminates cloud video subscription dependency by storing footage locally on a microSD card, while reducing false motion alerts using dual-sensor validation (PIR + mmWave). The system delivers real-time push notifications, live video view on LAN, clip browsing and playback, and full device management — all without paying for cloud storage.



## 1.1 Core Concept

Detect candidate motion via PIR interrupt → validate with mmWave fusion → record buffered clip → save to microSD → push notification to user → app provides event feed, live view, and LAN clip access.

Doorbell button press = separate event type with its own notification and event entry.

All video stays on device. No video ever uploaded to cloud.



## 1.2 Must-Deliver Goals

Local event-based video capture and microSD storage.

Dual-sensor (PIR + mmWave) validation to reduce false triggers.

Doorbell button press detection as a distinct event type.

Live MJPEG video stream accessible on LAN.

Wi-Fi connectivity for push notifications and LAN clip/stream access.

Flutter mobile app: onboarding, live view, notifications, event feed, clip playback, device settings.

Android-first. iOS is a nice-to-have after demo is stable.



## 1.3 Explicit Out of Scope

Cloud video storage or remote video access (outside home network) — MVP is LAN only. Architecture is prepared for Cloudflare Tunnel post-demo.

Face recognition, package detection, or advanced computer vision.

Battery-powered operation (wired 5V USB-C input assumed).

iOS APNs push configuration (Android FCM only for demo).

Commercial hardening (IP certification, full regulatory compliance).



## 1.4 Nice-to-Have Freeze Date

HARD RULE: No nice-to-have work begins before March 28. This protects integration testing and demo prep. Live view, while MVP-targeted, is architecturally isolated so it cannot block the rest of demo readiness if it slips.



# 2. System Architecture

DingDong is organized into three layers: Hardware, Firmware, and Mobile App — plus a minimal cloud relay for push notifications.



## 2.1 Hardware Layer

MCU: ESP32-S3 DevKit — dual-core, Wi-Fi, FreeRTOS support

Camera: OV5640 — connected via DVP interface, 5MP, used at 720p/15fps for clips and lower resolution for live stream

Motion Sensor 1: PIR (HC-SR501) — thermal presence detection, configured as interrupt source

Motion Sensor 2: mmWave Radar (DFRobot SEN0395) — motion + distance confirmation, separate power path

Storage: microSD via SPI — all video clips stored locally

Power: 5V USB-C input → TPS54331 buck converter → 3.3V regulated rail → LDO for camera sub-rails (2.8V, 1.8V)

PCB: 4-layer custom board, 70mm x 45mm, housed in Polycase HD-36F NEMA 4X enclosure

Buzzer: piezo buzzer for local audio feedback on doorbell press



## 2.2 Firmware Layer

Framework: ESP-IDF (C/C++) + FreeRTOS

Sensor Task: reads PIR interrupt + mmWave, runs fusion logic, posts validated events to event queue

Camera Task: configures OV5640, buffers frames, manages clip capture windows, serves MJPEG stream

Storage Task: writes clips to microSD in buffered chunks via bounded queue, manages filenames

Wi-Fi Task: manages connection, reconnect with backoff, serves HTTP API, calls Cloud Function relay

mDNS: device advertises as dingdong-<deviceId>.local on the local network

NVS: stores device API token and Wi-Fi credentials persistently across reboots



## 2.3 Mobile App Layer

Framework: Flutter — Android-first, iOS nice-to-have

State management: Riverpod

Auth: Firebase Auth (email/password)

Event metadata: Firestore (primary, cloud-synced) + ESP32 device API (fallback on LAN)

Push: Firebase Cloud Messaging (FCM) — Android

Local DB/cache: Hive

Networking: Dio (HTTP client)

Secure storage: flutter_secure_storage (device API token)

Video playback: better_player (download-then-play)

Live view: MJPEG stream rendered via HTTP widget on LAN

mDNS discovery: multicast_dns package resolves dingdong-<id>.local



## 2.4 Cloud Layer (Minimal)

Firebase Auth — identity provider, free tier

Firestore — metadata only (no video), free tier quotas sufficient

Firebase Cloud Messaging — push delivery, free

Cloud Functions for Firebase — push relay + Firestore event writer, Node.js 18, requires Blaze plan (billing enabled, but free-tier invocations cover project usage easily)

No video ever reaches the cloud. Firestore stores only event metadata (timestamps, type, clip filename reference). All video stays on the microSD card.



# 3. Tech Stack



| Layer | Technology | Purpose | Cost |
| --- | --- | --- | --- |
| Flutter | Mobile framework | Cross-platform app (Android-first) | Free |
| Riverpod | State management | Providers, async state, dependency injection | Free |
| Dio | HTTP client | Device API calls, clip download | Free |
| Hive | Local cache | Event metadata cache, offline support | Free |
| flutter_secure_storage | Secure storage | Device API token storage | Free |
| better_player | Video playback | Download-then-play clip playback | Free |
| multicast_dns | mDNS discovery | Resolve dingdong-<id>.local on LAN | Free |
| Firebase Auth | Authentication | Email/password identity | Free |
| Firestore | Cloud DB | Event metadata, device registry | Free tier |
| FCM | Push notifications | Motion + doorbell push to Android | Free |
| Cloud Functions | Serverless relay | Push relay + Firestore writer, Node.js 18 | Blaze (free tier invocations) |
| ESP-IDF + FreeRTOS | Firmware | All device-side logic | Free |



# 4. Product Features



## 4.1 Authentication & Account (MVP)

Email/password sign up with validation (email format, password min 8 chars)

Sign in with session persistence — user stays logged in across app restarts

Sign out

Account settings screen: display name, email display, sign out button

Device membership model: a user owns a device; members can be added later (nice-to-have)



## 4.2 Device Onboarding — SoftAP Wizard (MVP)

A multi-step wizard that provisions the ESP32 onto the user's home Wi-Fi and pairs it to their account.

Step 1: Instruct user to plug in device and wait for indicator LED

Step 2: Instruct user to connect phone to device's Wi-Fi hotspot (SSID: DingDong-Setup)

Step 3: App connects to device at 192.168.4.1 and POSTs home Wi-Fi credentials

Step 4: App polls GET /provision/status until device reports 'connected' with its assigned IP

Step 5: Device returns generated API token in status response. App stores token in flutter_secure_storage

Step 6: App writes device registration to Firestore (deviceId, displayName, owner uid)

Step 7: App resolves device via mDNS (dingdong-<deviceId>.local) for future LAN communication

Token generation: ESP32 generates a cryptographically random 32-byte token at provisioning time, stores it in NVS, returns it once in the /provision/status response when state = 'connected'. The app stores it in flutter_secure_storage. All subsequent protected API calls include: Authorization: Bearer <token>.



## 4.3 Live View (MVP — Isolated Phase)

Live MJPEG video stream from the ESP32, accessible on LAN only.

Live View button on Home screen — enabled only when device is reachable on LAN

App opens stream at http://dingdong-<id>.local/stream and renders in MJPEG viewer widget

Resolution: 320x240 or 640x480 (configurable, lower res prioritized for stability)

Stream pauses/closes when app goes to background to free ESP32 resources

'Live View only available on home Wi-Fi' message when off LAN

IMPLEMENTATION NOTE: Live view runs in its own isolated FreeRTOS task. It must not interfere with clip capture or sensor tasks. If a motion event occurs during live view, capture takes priority and stream may drop frames. This is acceptable behavior. Live view is MVP-targeted but firewalled — if firmware instability is encountered, demo proceeds without it and it ships in the post-demo polish phase.



## 4.4 Push Notifications (MVP)

Motion event detected (PIR + mmWave confirmed) → ESP32 calls Cloud Function → FCM push sent to user's Android device

Doorbell button pressed → ESP32 calls Cloud Function → FCM push with type 'doorbell' sent

Notification payload includes: eventId, deviceId, type (motion/doorbell), timestamp

Tapping notification opens app directly to Event Detail screen for that event

Notifications work when app is closed, backgrounded, or open

Notification toggle in Device Settings disables/re-enables (stored in Firestore device doc)



## 4.5 Events Feed (MVP)

Primary source: Firestore events collection (synced, works off LAN)

Fallback source: GET /events from ESP32 device API (LAN only, used if Firestore unreachable)

Chronological list — most recent first

Each item shows: timestamp, event type (Motion / Doorbell), clip availability indicator

Pull-to-refresh

Event Detail screen: timestamp, type, sensor stats (optional), 'View Clip' button (LAN only), type badge

Empty state with illustration when no events yet



## 4.6 Clip Browsing & Playback (MVP — LAN only)

Clips tab shows list fetched from GET /clips on ESP32

Each item shows: timestamp, duration, file size

Tap clip → app downloads full clip via GET /clips/{clipId} → plays in better_player

Delete clip via DELETE /clips/{clipId} (with confirmation dialog)

'Connect to home Wi-Fi to access clips' gate shown when device not reachable on LAN

Download progress indicator shown during clip fetch

Playback model: Download-then-play. For clips up to 30 seconds at 1.5 Mbps, download over LAN takes under 2 seconds. This is simpler and more reliable than HTTP range request streaming on the ESP32.



## 4.7 Device Settings (MVP)

Motion detection enable/disable toggle → POST /settings {motionEnabled: bool}

mmWave sensitivity threshold slider (0–100) → POST /settings {mmwaveThreshold: int}

Notifications toggle → updates Firestore device doc + POST /settings {notifyEnabled: bool}

Clip length selector (5s / 10s / 20s / 30s) → POST /settings {clipLengthSec: int}

Device info: deviceId, firmware version, last seen timestamp

Settings fetched from GET /settings on load; local state shown immediately, synced on response



## 4.8 Device Status & Reliability UX (MVP)

Online/offline indicator on Home and Device Settings screens

mDNS probe on app foreground to determine LAN reachability

All API calls have timeout (5s default) + 2 retry attempts with exponential backoff

Clear, human-readable error messages — no raw error codes shown to user

'Last seen: X minutes ago' when device is offline



## 4.9 Nice-to-Have Features (Post March 28)

Live View stabilization and resolution upgrade (if MVP live view had issues)

Remote access via Cloudflare Tunnel — architecture already prepared, just a base URL swap

iOS APNs configuration for FCM push on iPhone

Privacy zones — mask/ignore motion areas in camera frame

Quiet hours — scheduled notification silence window

Storage manager — SD card usage display + auto-delete oldest clips rules

Activity heatmap — motion frequency visualization by hour/day

Event tagging + filtering/search

Multi-device support (front door + back door)

Package mode — temporary preset for longer clips and higher sensitivity



# 5. UX & UI Requirements

The app must not look like a default Material demo. A DingDong design system is enforced from day one.



## 5.1 Design System

Theme class: DDTheme — dark navy primary (#1A3C5E), electric blue accent (#2E86C1), clean whites and light grays

Typography: DDTypography — Inter or similar modern sans-serif, defined scale (display/title/body/caption)

Spacing: DDSpacing — 4pt base grid, consistent named tokens (xs/sm/md/lg/xl)

Motion: subtle page transitions, micro-interactions on buttons and cards (no jarring animations)

Layout: modern card-based event feed, bottom navigation, bottom sheets for actions



## 5.2 Custom Component Library

DDButton — primary, secondary, destructive variants

DDCard — event card, clip card, device status card

DDListTile — for events feed and clip list items

DDBottomSheet — for actions, confirmations, and settings panels

DDTextField — styled input with validation states

DDChip — event type badge (Motion / Doorbell), status chip (Online / Offline)

DDToast — non-blocking success/error feedback

DDEmptyState — illustrated empty states for Events, Clips

DDLoadingIndicator — branded loading spinner



## 5.3 Required Screens

| Screen | Route | Phase |
| --- | --- | --- |
| Splash / Loading | /splash | Phase 1 |
| Login | /login | Phase 1 |
| Sign Up | /signup | Phase 1 |
| Onboarding — Welcome | /onboard/welcome | Phase 1 |
| Onboarding — Connect to Device AP | /onboard/connect-ap | Phase 1 |
| Onboarding — Sending Credentials | /onboard/provisioning | Phase 1 |
| Onboarding — Confirming Connection | /onboard/confirming | Phase 1 |
| Onboarding — Success / Name Device | /onboard/success | Phase 1 |
| Home — Events Tab | /home/events | Phase 1 |
| Home — Clips Tab | /home/clips | Phase 1 |
| Home — Live View Tab | /home/live | Phase 3 (Live View) |
| Home — Settings Tab | /home/settings | Phase 1 |
| Event Detail | /events/:eventId | Phase 1 |
| Clip Player | /clips/:clipId | Phase 1 |
| Device Settings | /settings/device | Phase 1 |
| Account Settings | /settings/account | Phase 1 |
| Debug Screen | /debug | Phase 1 (dev only) |



# 6. Data Model (Firestore)

No video is stored in the cloud. Firestore holds metadata only. Video stays on the ESP32 microSD card.



## 6.1 Collections

### users/{uid}

{

  email: string,

  displayName: string,

  createdAt: timestamp

}



### devices/{deviceId}

{

  displayName: string,

  ownerId: string (uid),

  createdAt: timestamp,

  lastSeen: timestamp,

  firmwareVersion: string,

  notifyEnabled: boolean,

  motionEnabled: boolean

}



### deviceMembers/{deviceId}_{uid}

{

  deviceId: string,

  uid: string,

  role: 'owner' | 'member',

  addedAt: timestamp

}



### events/{eventId}

{

  deviceId: string,

  ts: timestamp,

  type: 'motion' | 'doorbell',

  clipId: string | null,

  sensorStats: {

    pirTriggered: boolean,

    mmwaveDistance: number | null

  } | null

}



## 6.2 Firestore Security Rules

rules_version = '2';

service cloud.firestore {

  match /databases/{database}/documents {



    // Users can only read/write their own profile

    match /users/{uid} {

      allow read, write: if request.auth != null && request.auth.uid == uid;

    }



    // Device readable only if membership record exists for this user

    match /devices/{deviceId} {

      allow read: if request.auth != null &&

        exists(/databases/$(database)/documents/deviceMembers/$(deviceId + '_' + request.auth.uid));

      allow write: if false; // Cloud Function only (Admin SDK)

    }



    // Membership: user can read their own memberships

    match /deviceMembers/{membershipId} {

      allow read: if request.auth != null &&

        membershipId.matches('.*_' + request.auth.uid);

      allow write: if false; // Cloud Function only

    }



    // Events: readable if user is a member of that device

    match /events/{eventId} {

      allow read: if request.auth != null &&

        exists(/databases/$(database)/documents/deviceMembers/

          $(resource.data.deviceId + '_' + request.auth.uid));

      allow write: if false; // Cloud Function only (Admin SDK)

    }

  }

}



# 7. Firmware ↔ App API Contract



## 7.1 Base URL & Discovery

Base URL: http://dingdong-<deviceId>.local/api/v1

Discovery: multicast_dns resolves dingdong-<deviceId>.local on LAN

Fallback: raw IP stored after provisioning if mDNS fails

Remote access prep: DeviceApiClient accepts a configurable baseUrl. Swapping to a Cloudflare Tunnel URL requires zero refactoring.



## 7.2 SoftAP Provisioning Endpoints (Public — No Token)

Available only while ESP32 is in SoftAP mode. Base: http://192.168.4.1



| Method | Path | Request Body | Response |
| --- | --- | --- | --- |
| POST | /provision | { ssid, password, deviceName } | { ok: true } |
| GET | /provision/status | — | { state: "connecting"\|"connected"\|"failed", ip?: string, deviceId?: string, token?: string } |

Token is returned exactly once — in the /provision/status response when state = 'connected'. The app must store it immediately in flutter_secure_storage. The ESP32 stores it in NVS.



## 7.3 Protected Endpoints (Require Bearer Token)

All requests must include:

Authorization: Bearer <device_api_token>



| Method | Path | Description | Response |
| --- | --- | --- | --- |
| GET | /health | Device status check | { ok, deviceId, fwVersion, time, lastEventTs } |
| GET | /events?since=<ts> | Event list (LAN fallback) | { events: Event[] } |
| GET | /clips | List all clips on SD card | { clips: [{ clipId, ts, durationSec, sizeBytes }] } |
| GET | /clips/{clipId} | Download clip file | Binary (video/mp4 or video/avi) |
| DELETE | /clips/{clipId} | Delete clip from SD | { ok: true } |
| GET | /settings | Get current device settings | { motionEnabled, notifyEnabled, mmwaveThreshold, clipLengthSec } |
| POST | /settings | Update device settings | { ok: true } |
| GET | /stream | MJPEG live stream | multipart/x-mixed-replace stream |



## 7.4 Contract Guarantees

All JSON fields are fixed and typed — no dynamic keys

Firmware validates all POST inputs (types, ranges, max lengths) and rejects invalid payloads with 400

401 for missing/invalid token, 429 for rate-limited auth failures, 403 for forbidden operations

Error responses always return: { error: string, code: number }

Clip downloads return Content-Length header so app can show download progress



# 8. Cloud Function — Push Relay



## 8.1 Runtime & Endpoint

Runtime: Node.js 18

Trigger: HTTPS callable (POST /notify)

Deployed via Firebase CLI on Blaze plan



## 8.2 What It Does

Receives event notification request from ESP32 (with HMAC signature)

Verifies HMAC signature, timestamp window, and nonce uniqueness

Verifies device is registered in Firestore

Writes event document to Firestore events collection

Fetches FCM tokens for all device members

Sends FCM push notification to all member devices

Returns { ok: true } to ESP32



## 8.3 ESP32 → Cloud Function Request

Headers:

X-Timestamp: <unix_ms>

X-Nonce: <random_hex_16>

X-Signature: HMAC_SHA256(device_secret, timestamp || nonce || body)

Content-Type: application/json

Body:

{

  deviceId: string,

  type: 'motion' | 'doorbell',

  ts: number (unix_ms),

  clipId: string | null,

  sensorStats: { pirTriggered: bool, mmwaveDistance: number | null } | null

}



## 8.4 Verification Steps (in order)

Validate request body schema and types

Verify timestamp is within ±60 seconds of server time

Verify nonce has not been used in the last 5 minutes (stored in Firestore or memory cache)

Verify HMAC_SHA256 signature using stored device_secret

Verify deviceId exists in Firestore devices collection

If all pass: write event to Firestore, send FCM, return { ok: true }

If any fail: return 401 or 400 with error code — no partial execution



## 8.5 Secrets Management

device_secret stored as Cloud Function environment secret (Firebase Secret Manager or .env in Function config) — never committed to repo

Service account JSON never committed — used only in CI/CD environment or local deploy

.env.example committed to repo with placeholder keys as documentation

.gitignore includes: .env, serviceAccount*.json, *.key, google-services.json (optional but recommended to keep out of public repos)

GitHub secret scanning and push protection enabled on repo



# 9. Security Requirements



## 9.1 Threat Model

| Threat | Mitigation |
| --- | --- |
| LAN attacker hitting device endpoints | Bearer token required on all protected endpoints |
| Brute force token guessing | Rate-limit: 5 failed auth attempts → 429 for 60s |
| Replay attacks on Cloud Function | HMAC + timestamp window ±60s + nonce deduplication |
| Spoofed push requests | HMAC signature verification in Cloud Function |
| Account data leaks | Firestore Security Rules enforce membership-based access |
| Secrets in GitHub | .gitignore + GitHub secret scanning + pre-commit hooks |
| Oversized payloads / buffer overflow on device | Firmware enforces max body size and field length limits |



## 9.2 Input Validation — App (Client Side)

Email: valid format check

Password: minimum 8 characters

Device name: 1–32 characters

Wi-Fi SSID: 1–32 characters; password: 0–63 characters

mmWave threshold: integer 0–100

Clip length: must be one of [5, 10, 20, 30] seconds



## 9.3 Input Validation — Firmware (Server Side)

Validate JSON schema and all field types on every POST

Reject unknown fields

Enforce max string lengths to prevent buffer overflow

Reject out-of-range numeric values

Reject payloads exceeding size limit (e.g., 2KB for settings, 512 bytes for provision)

Constant-time token comparison to prevent timing attacks

Return consistent error codes: 401 (bad token), 400 (bad input), 429 (rate limited), 403 (forbidden)



# 10. Development Workflow

This workflow is designed for maximum Claude Code autonomy. Each phase has a clear input (what exists) and output (what gets built). Firmware is not needed until Phase 4.



## Phase 1 — UI, Architecture & Mocks (No Firmware Needed)

Build full Flutter project structure in mobile/

Implement DDTheme, DDTypography, DDSpacing, DDComponents design system

Build all navigation routes and screen stubs

Create DeviceApi interface + MockDeviceApi implementation

Create EventsRepo interface + MockEventsRepo implementation

All screens render with realistic mock data

Widget tests for core screens

Run flutter analyze — zero errors/warnings

Claude Code prompt: 'Read docs/PRD.md in full. Implement Phase 1: scaffold the entire Flutter project with DDTheme, all navigation routes, all screen stubs, Riverpod providers, and mock repositories for DeviceApi and EventsRepo. Use realistic mock data. Run flutter analyze after and fix all errors.'



## Phase 2 — Firebase Integration

Firebase Auth integrated (sign up, sign in, sign out, session persistence)

Firestore queries wired to EventsRepo (replaces mock for events feed)

FCM receiver integrated — notifications route to Event Detail

Firestore Security Rules deployed

Claude Code prompt: 'Phase 2: Wire Firebase Auth into the auth screens. Replace MockEventsRepo with FirestoreEventsRepo. Integrate FCM notification receiver and route tap to Event Detail. Deploy Firestore security rules from docs/PRD.md section 6.2.'



## Phase 3 — Cloud Function Relay

Cloud Function implemented in cloud/ (Node.js 18)

HMAC verification, nonce check, timestamp window implemented

Function writes event to Firestore + sends FCM

.env.example committed, real secrets set in Firebase config

Tested end-to-end with curl from laptop before connecting ESP32

Claude Code prompt: 'Phase 3: Implement the Cloud Function in cloud/ per PRD section 8. HMAC verification, Firestore event write, and FCM send. Create .env.example. Test with a curl POST that mimics the ESP32 request format.'



## Phase 4 — Firmware API Endpoints (Hardware Required)

Firmware implements: /health, /provision, /provision/status, /clips, /settings, /stream

Token generation in NVS, Bearer token validation on all protected routes

Input validation per PRD section 9.3

mDNS advertisement of dingdong-<deviceId>.local

App swaps MockDeviceApi → RealDeviceApi (base URL from mDNS resolution)

Claude Code prompt: 'Phase 4: Implement the full firmware HTTP API per PRD section 7. Token generation and NVS storage, Bearer token validation, all endpoints, mDNS. Then update the Flutter app to replace MockDeviceApi with RealDeviceApi using the DeviceApiClient with configurable baseUrl.'



## Phase 5 — Live View

Firmware: MJPEG stream task isolated from capture/sensor tasks

App: MJPEG viewer widget on Live View screen, LAN gate enforced

Stream pause on app background

Claude Code prompt: 'Phase 5: Implement MJPEG live stream. Firmware: isolated FreeRTOS stream task serving /stream endpoint, 320x240, drops frames gracefully during motion capture. App: MJPEG viewer widget on Live View tab, disable when off LAN.'



## Phase 6 — Integration & Hardening

LAN detection gating for all device-dependent features

Retry/timeout behavior on all API calls

Wi-Fi reconnection logic on firmware

Logging without secrets

End-to-end test: motion → capture → notify → app feed → clip playback

Stress test: multiple events, SD write reliability, Wi-Fi reconnect



## Phase 7 — Nice-to-Haves (Post March 28 only)

Remote access via Cloudflare Tunnel

iOS APNs configuration

Privacy zones, quiet hours, storage manager, activity heatmap, event search



# 11. Repo Structure

dingdong/

├── mobile/                    # Flutter app

│   ├── lib/

│   │   ├── core/              # DDTheme, DDTypography, DDSpacing

│   │   ├── components/        # DDButton, DDCard, DDListTile, etc.

│   │   ├── features/

│   │   │   ├── auth/          # Login, SignUp, AccountSettings

│   │   │   ├── onboarding/    # SoftAP wizard screens

│   │   │   ├── events/        # EventsFeed, EventDetail

│   │   │   ├── clips/         # ClipList, ClipPlayer

│   │   │   ├── live_view/     # LiveViewScreen (MJPEG)

│   │   │   └── settings/      # DeviceSettings

│   │   ├── repositories/

│   │   │   ├── device_api/    # DeviceApi interface + Mock + Real

│   │   │   └── events/        # EventsRepo interface + Mock + Firestore

│   │   └── main.dart

│   └── test/

├── firmware/                  # ESP-IDF project

│   ├── main/

│   │   ├── tasks/             # sensor, camera, storage, wifi, stream

│   │   ├── api/               # HTTP server, routes, token auth

│   │   └── main.c

│   └── CMakeLists.txt

├── cloud/                     # Cloud Functions

│   ├── functions/

│   │   ├── index.js           # /notify endpoint

│   │   └── hmac.js            # HMAC verification helper

│   ├── firestore.rules

│   ├── .env.example

│   └── package.json

└── docs/

    ├── PRD.md                 # This document (source of truth)

    ├── API.md                 # Device API contract detail

    └── SECURITY.md            # Secrets management checklist



# 12. Testing & Definition of Done



## 12.1 MVP is Done When:

User can sign up, log in, and stay logged in across app restarts

User can onboard ESP32 via SoftAP wizard and see it paired to their account

Motion event triggers FCM push notification on Android device

Doorbell button press triggers its own FCM push notification

App shows event in Events Feed (from Firestore)

On home Wi-Fi: app lists clips and plays a clip

On home Wi-Fi: Live View shows real-time MJPEG stream

Unauthorized device on LAN cannot access clips or settings without valid token

No secrets are committed to repo; GitHub secret scanning is enabled



## 12.2 Test Coverage

| Test Type | What | Tool |
| --- | --- | --- |
| Flutter unit | DTO parsing, validators, Riverpod state logic | dart test |
| Flutter widget | Event feed renders, clip list renders, empty states | flutter test |
| Firmware curl | All endpoints: valid token, invalid token, bad payload, rate limit | curl / Postman |
| Cloud Function | HMAC valid, HMAC invalid, expired timestamp, replayed nonce | curl from laptop |
| System E2E | Motion → capture → notify → app feed → clip playback latency | Manual |
| Stress | 10 motion events in 60s, SD write reliability, Wi-Fi reconnect | Manual / scripted |



# 13. Cost & Free Tier Summary



| Service | Usage | Cost |
| --- | --- | --- |
| Firebase Auth | Email/password auth, session tokens | Free |
| Firestore | Event metadata, device registry — well within 50K reads/20K writes/day free tier | Free |
| Firebase Cloud Messaging | Push notifications to Android | Free |
| Cloud Functions | Requires Blaze plan (billing enabled). ~100 events/day = ~3,000/month vs 2M/month free tier invocations | Free usage on Blaze |
| Hardware BOM | ESP32-S3, OV5640, PIR, mmWave, SD, PCB, enclosure | ~$235 (team estimate) |

Cloud Functions requires the Blaze (pay-as-you-go) plan to deploy, but the underlying Google Cloud free tier provides 2 million invocations per month. At expected usage, the bill will be $0. A billing budget alert of $1 is recommended as a safety net.



# 14. Claude Code — Automation Guide



## 14.1 What Claude Code Handles Autonomously

Generate entire Flutter project structure, routing, and screen stubs

Implement all screens, Riverpod providers, repositories, validators

Build full DDTheme design system and component library

Write mock and real implementations of DeviceApi and EventsRepo

Write widget and unit tests, run flutter analyze, fix errors

Implement Cloud Function code in cloud/ with HMAC, Firestore write, FCM send

Write Firestore security rules

Create .gitignore, .env.example, pre-commit hooks, CI scripts

Implement firmware HTTP API endpoints, token auth, input validation, mDNS

Write curl test scripts for firmware endpoints



## 14.2 What You Must Do Manually (Account-Bound Steps)

Create Firebase project in Firebase Console

Register Android app in Firebase, download and place google-services.json

Enable Email/Password authentication provider in Firebase Console

Enable Firestore in Firebase Console

Enable Blaze billing plan to deploy Cloud Functions

Set real secrets in Firebase Function config or Google Cloud Secret Manager (not committed to repo)

(iOS, if pursued) Upload APNs authentication key to Firebase for iOS push



## 14.3 Recommended Claude Code Session Structure

Feed Claude Code the entire PRD as context at the start of each session. Reference it as 'the source of truth.' One phase per focused session works best.

Session 1: 'Read docs/PRD.md. Implement Phase 1 in full per section 10.'

Session 2: 'Read docs/PRD.md. Implement Phase 2 — Firebase Auth + Firestore + FCM receiver per section 10.'

Session 3: 'Read docs/PRD.md. Implement Phase 3 — Cloud Function in cloud/ per sections 8 and 10.'

Session 4 (firmware ready): 'Read docs/PRD.md. Implement Phase 4 — firmware API per section 7 and update Flutter app to use RealDeviceApi.'

Session 5: 'Read docs/PRD.md. Implement Phase 5 — MJPEG live view per section 4.3.'

Session 6: 'Read docs/PRD.md. Phase 6 hardening — all retry/timeout/LAN gating per section 10.'
