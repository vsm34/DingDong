# DingDong — Smart Doorbell System
## FINAL PRODUCT REQUIREMENTS DOCUMENT
**SP26-41 — Rutgers University**
Gian Rosario · Vini Silva · Varun Mantha | Advisor: Dov Kruger | Version 4.0 — March 2026

---

# 1. Project Summary

DingDong is a privacy-focused smart doorbell system that eliminates cloud video subscription dependency by storing footage locally on a microSD card, while reducing false motion alerts using dual-sensor validation (PIR + mmWave). The system delivers real-time push notifications, live video view on LAN, clip browsing and playback, and full device management — all without paying for cloud storage.

## 1.1 Core Concept

- Detect candidate motion via PIR interrupt → validate with mmWave fusion → record buffered clip → save to microSD → push notification to user → app provides event feed, live view, and LAN clip access.
- Doorbell button press = separate event type with its own notification and event entry.
- All video stays on device. No video ever uploaded to cloud.

## 1.2 Must-Deliver Goals

- Local event-based video capture and microSD storage.
- Dual-sensor (PIR + mmWave) validation to reduce false triggers.
- Doorbell button press detection as a distinct event type.
- Live MJPEG video stream accessible on LAN.
- Wi-Fi connectivity for push notifications and LAN clip/stream access.
- Flutter mobile app: onboarding, live view, notifications, event feed, clip playback, device settings.
- Android-first. iOS is a nice-to-have after demo is stable.

## 1.3 Explicit Out of Scope

- Cloud video storage or remote video access (outside home network) — MVP is LAN only. Architecture is prepared for Cloudflare Tunnel post-demo.
- Face recognition, package detection, or advanced computer vision (see Section 16 for AI nice-to-haves).
- Battery-powered operation (wired 5V USB-C input assumed).
- iOS APNs push configuration (Android FCM only for demo).
- Commercial hardening (IP certification, full regulatory compliance).

## 1.4 Nice-to-Have Freeze Date

**HARD RULE:** No nice-to-have work begins before March 28. This protects integration testing and demo prep. Live view, while MVP-targeted, is architecturally isolated so it cannot block the rest of demo readiness if it slips.

---

# 2. System Architecture

DingDong is organized into three layers: Hardware, Firmware, and Mobile App — plus a minimal cloud relay for push notifications.

## 2.1 Hardware Layer

- MCU: ESP32-S3 DevKitC-1 — dual-core, Wi-Fi, FreeRTOS support
- Camera: OV5640 — connected via DVP interface, 5MP, 720p/15fps for clips, QVGA for stream
- Motion Sensor 1: PIR (HC-SR501) — thermal presence detection, interrupt source
- Motion Sensor 2: mmWave Radar (DFRobot SEN0395) — motion + distance confirmation, full ASCII output mode, separate power path
- Storage: microSD via SPI — all video clips stored locally
- Power: 5V USB-C input → TPS54331 buck converter → 3.3V regulated rail → LDO for camera sub-rails (2.8V, 1.8V)
- PCB: 4-layer custom board, 70mm x 45mm, housed in Polycase HD-36F NEMA 4X enclosure
- Buzzer: SDC1614L5-01 piezo, driven via BUZZER_CTRL through R5 resistor
- Doorbell button: TSW-102-26-G-S connector, DOORBELL_IN pulled HIGH to 3V3 via R6, active LOW

## 2.2 Firmware Layer

- Framework: ESP-IDF v5.x (latest stable) + FreeRTOS, written in **C++**
- Sensor Task: reads PIR interrupt + mmWave ASCII frames, runs fusion logic, posts validated events to event queue
- Camera Task: configures OV5640, buffers frames, manages clip capture, serves frames to stream task
- Storage Task: writes clips to microSD in buffered chunks via bounded queue, manages filenames
- Wi-Fi Task: manages connection, reconnect with backoff, serves HTTP API, calls Cloud Function relay
- Stream Task: isolated MJPEG stream task — does not block capture pipeline
- mDNS: device advertises as `dingdong-<deviceId>.local` on the local network
- NVS: stores device API token, Wi-Fi credentials, device_secret persistently across reboots

## 2.3 Mobile App Layer

- Framework: Flutter — Android-first, iOS nice-to-have
- State management: Riverpod
- Auth: Firebase Auth (email/password)
- Event metadata: Firestore (primary, cloud-synced) + ESP32 device API (fallback on LAN)
- Push: Firebase Cloud Messaging (FCM) — Android
- Local DB/cache: Hive
- Networking: Dio (HTTP client)
- Secure storage: flutter_secure_storage (device API token)
- Video playback: better_player (download-then-play)
- Live view: MJPEG stream rendered via HTTP widget on LAN
- mDNS discovery: multicast_dns package resolves `dingdong-<id>.local`

## 2.4 Cloud Layer (Minimal)

- Firebase Auth — identity provider, free tier
- Firestore — metadata only (no video), free tier quotas sufficient
- Firebase Cloud Messaging — push delivery, free
- Cloud Functions for Firebase — push relay + Firestore event writer, Node.js 22, requires Blaze plan

**No video ever reaches the cloud.** Firestore stores only event metadata. All video stays on the microSD card.

---

# 3. Tech Stack

| Layer | Technology | Purpose | Cost |
|---|---|---|---|
| Flutter | Mobile framework | Cross-platform app (Android-first) | Free |
| Riverpod | State management | Providers, async state, DI | Free |
| Dio | HTTP client | Device API calls, clip download | Free |
| Hive | Local cache | Event metadata cache, offline support | Free |
| flutter_secure_storage | Secure storage | Device API token storage | Free |
| better_player | Video playback | Download-then-play clip playback | Free |
| multicast_dns | mDNS discovery | Resolve dingdong-<id>.local on LAN | Free |
| shadcn_flutter | Base component system | Non-Material design primitives | Free |
| flutter_mix | Styling utility | Utility-based styling layer | Free |
| lottie | Micro-animations | Empty states, loading, onboarding | Free |
| google_fonts | Typography | Inter font family | Free |
| Firebase Auth | Authentication | Email/password identity | Free |
| Firestore | Cloud DB | Event metadata, device registry | Free tier |
| FCM | Push notifications | Motion + doorbell push to Android | Free |
| Cloud Functions | Serverless relay | Push relay + Firestore writer, Node.js 22 | Blaze (free tier) |
| ESP-IDF v5.x + FreeRTOS | Firmware | All device-side logic, C++ | Free |
| cJSON | JSON parsing | Lightweight JSON for HTTP API | Free (bundled) |
| esp_http_server | HTTP server | REST API on device | Free (bundled) |
| esp_mdns | mDNS | LAN device discovery | Free (bundled) |
| mbedTLS | HMAC-SHA256 | Cloud Function request signing | Free (bundled) |

---

# 4. Product Features

## 4.1 Authentication & Account (MVP)

- Email/password sign up with validation (email format, password min 8 chars)
- Sign in with session persistence — user stays logged in across app restarts
- Sign out with FCM token removal from Firestore on sign-out
- Account settings screen: display name, email display, sign out button
- Device membership model: a user owns a device; members can be added later (nice-to-have)

## 4.2 Device Onboarding — SoftAP Wizard (MVP)

A multi-step wizard that provisions the ESP32 onto the user's home Wi-Fi and pairs it to their account.

- Step 1: Instruct user to plug in device and wait for LED
- Step 2: Instruct user to connect phone to device hotspot (SSID: DingDong-Setup)
- Step 3: App connects to 192.168.4.1 and POSTs home Wi-Fi credentials + deviceName
- Step 4: App polls GET /provision/status until state = 'connected'
- Step 5: Device returns API token once. App stores in flutter_secure_storage immediately.
- Step 6: App calls Cloud Function to generate + provision device_secret. Device stores in NVS via POST /provision/secret.
- Step 7: App writes device registration to Firestore (deviceId, displayName, owner uid, deviceMembers record)
- Step 8: App resolves device via mDNS for all future LAN communication

**Token:** ESP32 generates 32-byte cryptographically random token at provisioning, stores in NVS, returns once in /provision/status response. All protected API calls require `Authorization: Bearer <token>`.

**DELETE /provision endpoint:** When a user forgets a device, the app calls DELETE /provision which clears NVS credentials and reboots the device into SoftAP mode.

## 4.3 Live View (MVP — Isolated Phase)

- Live View tab on Home screen — enabled only when device is reachable on LAN
- App opens MJPEG stream at `http://dingdong-<id>.local/api/v1/stream`
- Resolution: 320x240 default, 640x480 configurable
- Stream pauses when app goes to background
- "Live View only available on home Wi-Fi" shown when off LAN
- Stream runs in isolated FreeRTOS task — capture takes priority if motion event occurs

## 4.4 Push Notifications (MVP)

- Motion event (PIR + mmWave confirmed) → ESP32 calls Cloud Function → FCM push to Android
- Doorbell button pressed → ESP32 calls Cloud Function → FCM push with type 'doorbell'
- Notification payload: eventId, deviceId, type (motion/doorbell), timestamp
- Tapping notification opens app to Event Detail screen for that event
- Works when app is closed, backgrounded, or open
- Notification toggle in Device Settings stored in Firestore device doc

## 4.5 Events Feed (MVP)

- Primary source: Firestore events collection (synced, works off LAN)
- Fallback source: GET /events from ESP32 (LAN only, used if Firestore unreachable)
- Chronological list — most recent first
- Each item shows: timestamp, event type (Motion / Doorbell), clip availability indicator
- Pull-to-refresh
- Event Detail: timestamp, type, sensor stats, 'Play Clip' button (LAN only), delete action
- Empty state with Lottie animation

## 4.6 Clip Browsing & Playback (MVP — LAN only)

- Clips tab shows list from GET /clips on ESP32
- Each item shows: timestamp, duration, file size
- Tap clip → download via GET /clips/{clipId} → play in better_player
- Delete via DELETE /clips/{clipId} with confirmation dialog
- "Connect to home Wi-Fi to access clips" gate when off LAN
- Download progress indicator during fetch
- **Playback model:** Download-then-play. Clips up to 30s at 1.5 Mbps take under 2s on LAN.

## 4.7 Device Settings (MVP)

- Motion detection toggle → POST /settings {motionEnabled: bool}
- mmWave threshold slider (0–100) → POST /settings {mmwaveThreshold: int}
- Notifications toggle → Firestore + POST /settings {notifyEnabled: bool}
- Clip length selector (5s / 10s / 20s / 30s) → POST /settings {clipLengthSec: int}
- Device info: deviceId, firmware version, last seen timestamp
- Settings fetched on load; local state shown immediately, synced on response

## 4.8 Device Status & Reliability UX (MVP)

- Online/offline indicator on Home and Device Settings
- mDNS probe on app foreground to check LAN reachability
- All API calls: 5s timeout + 2 retries with exponential backoff
- Human-readable error messages — no raw error codes shown to user
- "Last seen: X minutes ago" when device is offline

## 4.9 Nice-to-Have Features (Sessions 7–10, post March 28)

See Section 16 for full grouping and session prompts.

---

# 5. UX & UI Design System

The app must not look like a default Material demo or vibe-coded. Every pixel is intentional. The DingDong design system is enforced from day one.

## 5.1 Design Philosophy

**Light mode primary.** The app is immediately readable at a glance — critical for a security product where users tap through notifications at any hour. Generous whitespace, precise typography, subtle depth through shadows not gradients, and micro-animations that feel earned.

Green is used as an **accent**, not a background. Amber is used for doorbell events and the logo only. White and light gray-green surfaces make up 90% of the screen real estate.

Inspiration: Ring's readability, SimpliSafe's clarity, with a more refined and premium component quality.

## 5.2 Color Palette

```
── Primary ──────────────────────────────────────────────────────
Hunter Green (brand):    #355E3B   — logo, active nav, toggles, primary buttons
Amber (accent):          #F59E0B   — logo waves, doorbell event, CTA hover
White (background):      #FFFFFF   — primary surface
Soft Green-Gray:         #F4F6F1   — card surfaces, input backgrounds, settings rows

── Text ──────────────────────────────────────────────────────────
Text Primary:            #1A2E1A   — headings, primary body
Text Secondary:          #4B6B4B   — supporting text, descriptions  
Text Muted:              #6B7280   — metadata, timestamps, captions
Text Disabled:           #9CA3AF   — placeholder, disabled states

── Semantic ──────────────────────────────────────────────────────
Online / Success:        #166534   — online status, success states
Offline / Error:         #DC2626   — offline, errors, destructive actions
Warning:                 #D97706   — low storage, weak signal
Doorbell Event bg:       #FFFBEB   — warm amber tint for doorbell cards
Doorbell Event chip:     #92400E   — doorbell event badge text/icon
Motion Event bg:         #F4F6F1   — cool green-gray for motion cards
Motion Event chip:       #1C4532   — motion event badge text/icon
Clip Available:          #D1FAE5   — clip badge background
Clip Text:               #065F46   — clip badge text

── Borders ───────────────────────────────────────────────────────
Border Default:          #E0E0DC   — card borders, dividers
Border Strong:           #C8D8C8   — emphasized borders, active inputs
```

**Rule: No blue anywhere in the app.** The only colors used are hunter green, amber, white, gray-green surfaces, and the semantic colors above. This keeps the palette clean and distinctive.

## 5.3 Logo Specification

The DingDong logo consists of a **green bell** (fat, wide body) centered between **amber sound waves** on both sides. Four wave arcs on each side, fading in opacity from inside out (100% → 75% → 45% → 20%).

```
Logo elements:
- Bell body:     fill #355E3B, wide trapezoid shape (wider than tall)
- Bell rim:      fill #2A4D2F, wide flat rect with rounded corners
- Bell clapper:  fill #2A4D2F, circle beneath rim
- Bell stem:     fill #355E3B, small rect + circle at top
- Wave arcs:     stroke #F59E0B, 4 arcs each side
  - Arc 1 (innermost): stroke-width 3, opacity 1.0
  - Arc 2: stroke-width 2.5, opacity 0.75
  - Arc 3: stroke-width 2, opacity 0.45
  - Arc 4 (outermost): stroke-width 1.5, opacity 0.20
- Wordmark:      "DingDong", Inter 700, #1A2E1A, letter-spacing -0.8px, size 26sp hero / 16sp app bar

Logo sizes:
- Hero (onboarding): Bell ~28px tall × 32px wide, waves spanning ~70px each side
- App bar: Bell ~18px tall × 20px wide, waves spanning ~44px each side  
- Icon only (launcher): Bell ~28px tall × 30px wide on #F8F8F6 rounded rect background, rx=18
```

## 5.4 Typography — DDTypography

Font family: **Inter** (via google_fonts package)

```
Display:   Inter 700, 32sp, letterSpacing: -0.5,  lineHeight: 1.2  — splash, hero
H1:        Inter 700, 24sp, letterSpacing: -0.3,  lineHeight: 1.3  — screen titles
H2:        Inter 600, 20sp, letterSpacing: -0.2,  lineHeight: 1.35 — section headers
H3:        Inter 600, 17sp, letterSpacing: 0,     lineHeight: 1.4  — card titles
Body L:    Inter 400, 16sp, letterSpacing: 0,     lineHeight: 1.6  — primary body
Body M:    Inter 400, 14sp, letterSpacing: 0,     lineHeight: 1.5  — list items, descriptions
Caption:   Inter 400, 12sp, letterSpacing: 0.2,   lineHeight: 1.4  — timestamps, metadata
Label:     Inter 500, 13sp, letterSpacing: 0.1,   lineHeight: 1.0  — buttons, chips, badges
Mono:      JetBrains Mono 400, 13sp               — device IDs, tokens, debug screen
```

## 5.5 Spacing System — DDSpacing

Base unit: 4pt

```
xs:   4px   — icon internal padding, tight chip padding
sm:   8px   — between related elements, icon + label gap
md:   16px  — card internal padding, standard list item spacing
lg:   24px  — section spacing, between cards
xl:   32px  — screen horizontal padding, major section breaks
xxl:  48px  — hero spacing, onboarding vertical rhythm
```

Border radius:
```
sm:   6px   — chips, badges, small buttons
md:   8px   — cards, input fields, event rows
lg:   12px  — bottom sheets, modals, large cards
xl:   16px  — screen-level rounded corners (bottom nav)
full: 9999px — pills, status indicators
```

## 5.6 Component Specifications

### DDButton

```
Primary:
  background: #355E3B, text: #FFFFFF, Label font
  padding: 14px vertical, 24px horizontal, radius: md
  hover/pressed: background #2A4D2F (10% darker)

Secondary:
  background: transparent, border: 1px #355E3B, text: #355E3B
  Same padding and radius as primary

Destructive:
  background: #FEF2F2, text: #DC2626, border: 1px #FCA5A5
  Same padding and radius

Disabled: all variants → opacity 0.4, no interaction
Loading: show 16px spinner replacing label text
```

### DDCard

```
background: #FFFFFF, border: 0.5px #E0E0DC, radius: md
padding: 16px, shadow: 0 1px 3px rgba(0,0,0,0.06)
Motion event card: background #F4F6F1
Doorbell event card: background #FFFBEB
```

### DDListTile

```
height: 64px minimum, padding: 12px horizontal
Leading icon area: 40x40px, radius sm, colored bg per event type
Title: Body M, #1A2E1A, font-weight 600
Subtitle: Caption, #6B7280
Trailing: clip badge or chevron
Separator: 0.5px #E0E0DC, inset 16px left
```

### DDTextField

```
background: #F4F6F1, border: 1px #E0E0DC, radius: md
padding: 14px horizontal, 12px vertical
focus border: #355E3B, focus shadow: 0 0 0 3px rgba(53,94,59,0.15)
error border: #DC2626
label: Caption, #6B7280, floats above on focus
```

### DDChip

```
Motion:   background #DCFCE7, text #065F46, Label font, radius sm
Doorbell: background #FEF3C7, text #92400E
Online:   background #DCFCE7, text #166534, with green dot 6px
Offline:  background #FEE2E2, text #991B1B, with red dot 6px
```

### DDBottomSheet

```
background: #FFFFFF, radius: lg top corners only
drag handle: 4px × 32px, #E0E0DC, centered, 12px from top
padding: 24px, max-height: 80% screen
backdrop: rgba(0,0,0,0.4) with fade animation
```

### DDToast

```
background: #1A2E1A, text: #FFFFFF, radius: full
padding: 12px 20px, max-width: 320px
auto-dismiss: 3 seconds
success variant: leading green check icon
error variant: leading red X icon
position: bottom center, 24px from bottom nav
```

### DDEmptyState

```
Lottie animation: 160px × 160px centered
Title: H3, #1A2E1A, centered
Subtitle: Body M, #6B7280, centered, max-width 260px
Optional CTA: DDButton secondary variant
Spacing: animation → title 16px, title → subtitle 8px, subtitle → CTA 24px
```

### DDLoadingIndicator

```
Circular progress, color: #355E3B, strokeWidth: 2.5px
Sizes: sm 16px, md 24px, lg 40px
Full-screen loading: centered md indicator on white background with 300ms delay before showing (prevents flash)
```

## 5.7 Screen Specifications

### Splash Screen (/splash)

Full white background. DingDong logo hero size centered vertically at 40% from top. DDLoadingIndicator lg beneath logo. Auto-navigates after auth state check. No user interaction. Logo appears with 200ms scale-in animation (0.8 → 1.0, ease-out curve).

### Login (/login)

White background. Logo small centered at top (80px from safe area). 48px gap. H1 "Welcome back". 8px gap. Body M muted "Sign in to your account". 32px gap. DDTextField email. 12px gap. DDTextField password (obscured, toggle visibility icon). 8px gap. Body M right-aligned "Forgot password?" link in #355E3B. 24px gap. DDButton primary full-width "Sign In". 16px gap. Body M centered "Don't have an account? " + "Sign up" link in #355E3B.

Validation: inline error below field on submit attempt. Email format check. Password min 8 chars.

### Sign Up (/signup)

Same layout as Login. Fields: display name, email, password, confirm password. Button "Create Account". Below: "Already have an account? Sign in".

### Onboarding — Welcome (/onboard/welcome)

Top half: hunter green (#355E3B) hero block taking 50% screen height. Logo icon centered in hero, 64px. Below logo: Display "DingDong" in white. Caption "Smart Doorbell System" in #A7D4A7. Bottom half: white. H2 "Meet DingDong" #1A2E1A. 8px. Body M #4B6B4B "Privacy-first doorbell with local storage and smart alerts." 32px. DDButton primary full-width "Get Started". Step dots row (5 dots, first filled #355E3B, rest outline).

### Onboarding — Connect AP (/onboard/connect-ap)

White background. Step indicator 2/5 at top. H2 "Connect to DingDong". Body M muted instructions. 3 numbered instruction rows (DDCard each): "1. Plug in your DingDong device", "2. Wait for the LED to blink", "3. Go to Wi-Fi settings → connect to DingDong-Setup". DDButton primary "I'm Connected" at bottom. Back link top-left.

### Onboarding — Provisioning (/onboard/provisioning)

Step 3/5. H2 "Connect to home Wi-Fi". Body M "Enter your home Wi-Fi credentials." DDTextField "Wi-Fi Network (SSID)". 12px. DDTextField "Password" obscured. 8px. Caption muted "Your credentials are sent directly to the device and never stored in the cloud." DDButton primary "Connect Device". Validation inline.

### Onboarding — Confirming (/onboard/confirming)

Step 4/5. Centered Lottie animation (connection spinner, 120px). H3 "Connecting your device..." below animation. Caption muted "This may take up to 30 seconds." Auto-advances when provisioning completes. Error state: show DDToast error + "Try Again" button if timeout exceeds 60s.

### Onboarding — Success (/onboard/success)

Step 5/5. Lottie checkmark animation (120px). H2 "DingDong is Ready!" centered. 8px. Body M muted "Give your device a name." 16px. DDTextField "Device name" pre-filled "Front Door". 24px. DDButton primary "Start Monitoring". Subtle animated confetti Lottie behind content.

### Home — Events Tab (/home/events)

App bar (white): Logo small left. Right: device name pill (green dot + name). Pull-to-refresh. Section header "Recent Events" Body M 600 #1A2E1A with date context ("Today", "Yesterday"). DDListTile for each event: colored icon bg (teal for motion, amber for doorbell), event title, relative timestamp, event type DDChip, clip available DDChip if applicable. Tapping row → Event Detail. Empty state with Lottie + "No events yet. Motion and doorbell events will appear here."

FAB bottom-right: "Live" button (camera icon + "LIVE" label, #355E3B background) — visible only when on LAN. Routes to /home/live.

### Home — Clips Tab (/home/clips)

Same app bar. LAN gate banner at top when off home network: amber background, "Connect to home Wi-Fi to browse clips." DDListTile for each clip: clock icon bg, filename as timestamp, duration badge, file size. Tap → download + play. Long-press or swipe left → delete confirmation DDBottomSheet. Empty state Lottie.

### Home — Live View Tab (/home/live)

When on LAN: Full-width MJPEG frame (aspect 4:3, with black letterbox if needed). "LIVE" pill badge top-left corner (#DC2626 background, white text). Connection quality indicator top-right (green/amber/red dot). Tap screen → show overlay with stream resolution text + close button. Off LAN: centered camera icon (64px, muted), H3 "Live View unavailable", Body M muted "Connect to your home Wi-Fi to view the live stream."

### Home — Settings Tab (/home/settings)

Account card at top: avatar circle (initials, #355E3B bg), display name H3, email Caption, "Account Settings" arrow link. Divider. Device card: device name H3, online/offline DDChip, firmware version Caption, "last seen X ago" Caption, "Device Settings" arrow link. Divider. App section: "About", "Help", app version Caption.

### Event Detail (/events/:eventId)

Back button + "Event" title in app bar. Delete icon top-right (destructive). Event type hero banner (DDCard): doorbell → #FFFBEB bg, motion → #F4F6F1 bg. Event type icon large (40px). Event title H2. Timestamp Body M. Sensor stats row: two DDCards side by side — "PIR" (triggered/not) and "mmWave" (distance in meters or —). "Play Clip" DDButton primary full-width (disabled + tooltip "Available on home Wi-Fi" when off LAN, shows download progress when loading). 16px. Caption muted "Clip stored locally on your device."

### Clip Player (/clips/:clipId)

better_player full-screen with custom controls styled in DDTheme. Back button top-left. Delete icon top-right. Clip metadata bottom sheet (pull up): timestamp, duration, file size. Controls: play/pause, seek bar (#355E3B accent), fullscreen toggle.

### Device Settings (/settings/device)

Back navigation. "Device Settings" H1. Device status DDCard at top. Section "MOTION" (Caption label, #6B7280): motion detection toggle row, sensitivity slider row (0–100, thumb #355E3B). Section "NOTIFICATIONS": push notifications toggle row. Section "CLIPS": clip length selector row (DDBottomSheet with 4 options). Section "DANGER ZONE": "Forget this device" DDButton destructive — confirmation DDBottomSheet before executing. All rows use DDListTile in #F4F6F1 DDCard.

### Account Settings (/settings/account)

Back navigation. "Account" H1. Display name row (tappable, opens edit DDBottomSheet). Email row (read-only). Divider. "Sign Out" DDButton destructive full-width. Caption muted "App version 1.0.0" at bottom.

### Debug Screen (/debug)

Dev-only, not accessible from production nav. Monospaced font throughout. Sections: Auth state (uid, email), Device state (deviceId, LAN reachable, last health response), Provider states (events count, clips count, settings JSON), Last API call timings. "Trigger mock motion event" button for testing notification flow.

---

# 6. Data Model (Firestore)

No video is stored in the cloud. Firestore holds metadata only. Video stays on the ESP32 microSD.

## 6.1 Collections

### users/{uid}
```json
{
  "email": "string",
  "displayName": "string",
  "createdAt": "timestamp",
  "fcmTokens": ["string"]
}
```

### devices/{deviceId}
```json
{
  "displayName": "string",
  "ownerId": "string (uid)",
  "createdAt": "timestamp",
  "lastSeen": "timestamp",
  "firmwareVersion": "string",
  "notifyEnabled": "boolean",
  "motionEnabled": "boolean",
  "secret": "string (admin-only, not readable by client rules)"
}
```

### deviceMembers/{deviceId}_{uid}
```json
{
  "deviceId": "string",
  "uid": "string",
  "role": "owner | member",
  "addedAt": "timestamp"
}
```

### events/{eventId}
```json
{
  "deviceId": "string",
  "ts": "timestamp",
  "type": "motion | doorbell",
  "clipId": "string | null",
  "sensorStats": {
    "pirTriggered": "boolean",
    "mmwaveDistance": "number | null"
  }
}
```

## 6.2 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: own profile only
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Devices: readable only if membership exists. Write = Cloud Function only.
    match /devices/{deviceId} {
      allow read: if request.auth != null &&
        exists(/databases/$(database)/documents/deviceMembers/$(deviceId + '_' + request.auth.uid));
      allow write: if false;
    }

    // DeviceMembers: user can read own memberships. Write = Cloud Function only.
    match /deviceMembers/{membershipId} {
      allow read: if request.auth != null &&
        membershipId.matches('.*_' + request.auth.uid);
      allow write: if false;
    }

    // Events: readable if user is member of that device. Write = Cloud Function only.
    match /events/{eventId} {
      allow read: if request.auth != null &&
        exists(/databases/$(database)/documents/deviceMembers/
          $(resource.data.deviceId + '_' + request.auth.uid));
      allow write: if false;
    }
  }
}
```

---

# 7. Firmware ↔ App API Contract

## 7.1 Base URL & Discovery

- Base URL: `http://dingdong-<deviceId>.local/api/v1`
- Discovery: multicast_dns resolves `dingdong-<deviceId>.local` on LAN
- Fallback: raw IP stored after provisioning if mDNS fails
- Remote access prep: `DeviceApiClient` takes a configurable `baseUrl` — swapping to a Cloudflare Tunnel URL requires zero app refactoring

## 7.2 SoftAP Provisioning Endpoints (Public — No Token)

Base: `http://192.168.4.1`

| Method | Path | Request Body | Response |
|---|---|---|---|
| POST | /provision | `{ ssid, password, deviceName }` | `{ ok: true }` |
| GET | /provision/status | — | `{ state: "connecting"\|"connected"\|"failed", ip?, deviceId?, token? }` |
| POST | /provision/secret | `{ secret: string(64 hex) }` | `{ ok: true }` |
| DELETE | /provision | — | `{ ok: true }` — clears NVS, reboots to SoftAP |

Token returned once only in /provision/status when state='connected'. App stores immediately in flutter_secure_storage.

## 7.3 Protected Endpoints (Require Bearer Token)

All requests: `Authorization: Bearer <device_api_token>`

| Method | Path | Description | Response |
|---|---|---|---|
| GET | /health | Device status | `{ ok, deviceId, fwVersion, time, lastEventTs }` |
| GET | /events?since=\<ts\> | Event list (LAN fallback) | `{ events: Event[] }` |
| GET | /clips | List all clips | `{ clips: [{ clipId, ts, durationSec, sizeBytes }] }` |
| GET | /clips/{clipId} | Download clip | Binary video/avi + Content-Length header |
| DELETE | /clips/{clipId} | Delete clip | `{ ok: true }` |
| GET | /settings | Get settings | `{ motionEnabled, notifyEnabled, mmwaveThreshold, clipLengthSec }` |
| POST | /settings | Update settings | `{ ok: true }` |
| GET | /stream | MJPEG live stream | multipart/x-mixed-replace stream |

## 7.4 CORS Headers (All Responses)

```cpp
httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
httpd_resp_set_hdr(req, "Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
httpd_resp_set_hdr(req, "Access-Control-Allow-Headers", "Authorization, Content-Type");
```

OPTIONS preflight: return 200 immediately for all URI patterns.

## 7.5 Contract Guarantees

- All JSON fields are fixed and typed — no dynamic keys
- Firmware validates all POST inputs and rejects invalid payloads with 400
- 401: missing/invalid token | 429: rate-limited | 403: forbidden | 400: bad input
- Error responses: `{ "error": "string", "code": number }`
- Clip downloads return Content-Length header

---

# 8. Cloud Function — Push Relay

## 8.1 Runtime & Endpoint

- Runtime: Node.js 22
- Trigger: HTTPS (POST /notify)
- Deployed via Firebase CLI on Blaze plan
- Project ID: dingdong-596c2

## 8.2 What It Does

1. Receives event notification from ESP32 with HMAC signature
2. Verifies HMAC signature, timestamp window, nonce uniqueness
3. Verifies device is registered in Firestore
4. **Writes event document to Firestore** events collection
5. Fetches FCM tokens from all users/{uid}.fcmTokens for device members
6. Sends FCM push notification to all member devices
7. Returns `{ ok: true }` to ESP32

## 8.3 ESP32 → Cloud Function Request

```
Headers:
  X-Timestamp: <unix_ms>
  X-Nonce: <random_hex_16>
  X-Signature: HMAC_SHA256(device_secret, timestamp || nonce || body)
  Content-Type: application/json

Body:
{
  "deviceId": "string",
  "type": "motion | doorbell",
  "ts": number,
  "clipId": "string | null",
  "sensorStats": { "pirTriggered": bool, "mmwaveDistance": number | null } | null
}
```

## 8.4 Verification Steps (in order)

1. Validate body schema and types
2. Verify timestamp within ±60 seconds of server time
3. Verify nonce not used in last 5 minutes
4. Verify HMAC_SHA256 signature using stored device_secret
5. Verify deviceId exists in Firestore
6. If all pass: write event → send FCM → return `{ ok: true }`
7. If any fail: return 401 or 400 — no partial execution

## 8.5 FCM Token Management

- On user sign-in: app registers FCM token and appends to `users/{uid}.fcmTokens` array
- On user sign-out: app removes FCM token from `users/{uid}.fcmTokens`
- Cloud Function reads all tokens for device members and sends multicast FCM push

## 8.6 Secrets Management

- `device_secret` stored in Cloud Function environment via Firebase Secret Manager — never committed
- Service account JSON never committed — used in CI/CD only
- `.env.example` committed with placeholder keys
- `.gitignore` covers: `.env`, `serviceAccount*.json`, `*.key`
- GitHub secret scanning + push protection enabled

---

# 9. Security Requirements

## 9.1 Threat Model

| Threat | Mitigation |
|---|---|
| LAN attacker hitting device endpoints | Bearer token on all protected endpoints |
| Brute force token guessing | Rate-limit: 5 failed attempts → 429 for 60s |
| Replay attacks on Cloud Function | HMAC + timestamp ±60s + nonce deduplication |
| Spoofed push requests | HMAC signature verification in Cloud Function |
| Account data leaks | Firestore Security Rules — membership-based access |
| Secrets in GitHub | .gitignore + GitHub secret scanning + pre-commit hooks |
| Buffer overflow on device | Firmware enforces max body size and field lengths |
| CORS abuse on device HTTP | CORS headers on every response, OPTIONS returns 200 |
| Session persistence after sign-out | FCM token removed from Firestore on sign-out |
| Device re-pairing abuse | /provision/secret rejects calls after first provisioning (NVS flag) |
| Device forgotten but token still valid | DELETE /provision clears NVS and reboots device |
| SSID/password injection | Input sanitization strips null bytes and control chars from onboarding fields |

## 9.2 Input Validation — App (Client Side)

- Email: valid format (regex)
- Password: minimum 8 characters
- Display name: 1–32 characters
- Device name: 1–32 characters
- Wi-Fi SSID: 1–32 characters, strip null bytes and control chars
- Wi-Fi password: 0–63 characters, strip null bytes
- mmWave threshold: integer 0–100
- Clip length: must be one of [5, 10, 20, 30]

## 9.3 Input Validation — Firmware (Server Side)

- Validate JSON schema and all field types on every POST
- Reject unknown fields
- Enforce max string lengths (prevent buffer overflow)
- Reject out-of-range numeric values
- Reject payloads > 2KB for settings, > 512 bytes for provision
- Constant-time token comparison (mbedtls_ct_memcmp)
- Return consistent codes: 401 (bad token), 400 (bad input), 429 (rate limited), 403 (forbidden)

## 9.4 Certificate Pinning (Firmware)

When making HTTPS calls to the Cloud Function URL, the firmware should pin the root CA certificate for `*.cloudfunctions.net` using `esp_http_client_config_t.cert_pem`. This prevents MITM attacks on the notify call. The certificate PEM should be embedded as a const char array in the firmware.

---

# 10. Development Workflow

## Phase 1 — UI, Architecture & Mocks ✅ COMPLETE

Flutter project scaffolded in mobile/. DDTheme, DDTypography, DDSpacing, all DD components built. All 17 screens stubbed with mock data. DeviceApi interface + MockDeviceApi. EventsRepo interface + MockEventsRepo. Riverpod providers. flutter analyze: 0 errors, 0 warnings.

**Note for Session 2:** Before Firebase work, upgrade DDTheme and all components to the full design spec in Section 5. Rebuild dd_colors.dart, dd_typography.dart, dd_spacing.dart, dd_theme.dart. Upgrade all screen layouts to match Section 5.7 screen specs. Run flutter analyze clean before proceeding to Firebase.

## Phase 2A — Design System Upgrade

- Rebuild DDColors with full palette from Section 5.2
- Rebuild DDTypography with Inter font, full scale from Section 5.4
- Rebuild DDSpacing with named tokens from Section 5.5
- Rebuild DDTheme around light-mode ThemeData
- Upgrade all DD components per specs in Section 5.6
- Implement all screen layouts per Section 5.7
- Add lottie, google_fonts, shadcn_flutter, flutter_mix to pubspec.yaml
- Run flutter analyze clean

## Phase 2B — Firebase Integration

- Add firebase_core, firebase_auth, cloud_firestore, firebase_messaging to pubspec.yaml
- Initialize Firebase in main.dart (WidgetsFlutterBinding.ensureInitialized + Firebase.initializeApp)
- Replace mock AuthNotifier with real FirebaseAuth (sign up, sign in, sign out, session persistence)
- On sign-in: register FCM token to users/{uid}.fcmTokens
- On sign-out: remove FCM token from users/{uid}.fcmTokens
- Wire auth redirect into routerProvider (unauthenticated → /login, authenticated away from auth screens)
- Create FirestoreEventsRepo reading from events collection per Section 6.1
- Integrate FCM receiver: foreground → DDToast, background/terminated tap → route to /events/:eventId
- Write Firestore security rules to cloud/firestore.rules per Section 6.2
- Add getStreamUrl() to DeviceApi interface and MockDeviceApi
- Run flutter analyze clean

## Phase 3 — Cloud Function Relay

- Implement Cloud Function in cloud/functions/ (Node.js 22) per Section 8
- HMAC verification, nonce deduplication, timestamp window
- Write event to Firestore + send FCM multicast
- Provision secret endpoint: generate device_secret, store in Firestore devices/{id}.secret, return to app
- Create .env.example with placeholder keys
- Test with curl from laptop before connecting ESP32
- Deploy Firestore rules via `firebase deploy --only firestore:rules`

## Phase 4 — Firmware (C++) per Section 15

- Full ESP-IDF v5.x project in firmware/
- All 5 FreeRTOS tasks: sensor, camera, storage, wifi, stream
- All HTTP API endpoints per Section 7
- HMAC notify client per Section 8.3
- App swaps MockDeviceApi → RealDeviceApi

## Phase 5 — Live View

- Firmware: MJPEG stream task isolated, serves /stream endpoint
- App: MJPEG viewer on Live View tab, LAN gate enforced, pauses on background

## Phase 6 — Integration & Hardening

- LAN detection gating for all device-dependent features
- Retry/timeout on all API calls
- Wi-Fi reconnection on firmware
- Full E2E test: motion → capture → notify → feed → clip playback
- Stress test: 10 events/60s, SD reliability, Wi-Fi reconnect
- Security audit per Section 12.3

---

# 11. Repo Structure

```
dingdong/
├── .gitignore                     # Root-level — covers secrets, env files, google-services.json
├── .env                           # Local secrets — NEVER committed
├── README.md
├── docs/
│   ├── PRD.md                     # This document — source of truth
│   ├── API.md                     # Device API contract detail
│   └── SECURITY.md                # Secrets management checklist
├── mobile/                        # Flutter app
│   ├── android/
│   │   └── app/
│   │       └── google-services.json   # NOT committed — in .gitignore
│   ├── lib/
│   │   ├── core/
│   │   │   └── theme/
│   │   │       ├── dd_colors.dart
│   │   │       ├── dd_typography.dart
│   │   │       ├── dd_spacing.dart
│   │   │       └── dd_theme.dart
│   │   ├── components/
│   │   │   ├── dd_button.dart
│   │   │   ├── dd_card.dart
│   │   │   ├── dd_list_tile.dart
│   │   │   ├── dd_bottom_sheet.dart
│   │   │   ├── dd_text_field.dart
│   │   │   ├── dd_chip.dart
│   │   │   ├── dd_toast.dart
│   │   │   ├── dd_empty_state.dart
│   │   │   └── dd_loading_indicator.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── onboarding/
│   │   │   ├── events/
│   │   │   ├── clips/
│   │   │   ├── live_view/
│   │   │   └── settings/
│   │   ├── repositories/
│   │   │   ├── device_api/        # DeviceApi interface + Mock + Real
│   │   │   └── events/            # EventsRepo interface + Mock + Firestore
│   │   ├── navigation/
│   │   │   └── app_router.dart
│   │   ├── providers/
│   │   │   └── providers.dart
│   │   └── main.dart
│   └── test/
├── firmware/                      # ESP-IDF v5.x C++ project
│   ├── main/
│   │   ├── config/
│   │   │   └── dd_config.h        # GPIO pins, constants
│   │   ├── tasks/
│   │   │   ├── sensor_task.cpp
│   │   │   ├── camera_task.cpp
│   │   │   ├── storage_task.cpp
│   │   │   ├── wifi_task.cpp
│   │   │   └── stream_task.cpp
│   │   ├── api/
│   │   │   ├── http_server.cpp
│   │   │   ├── auth_middleware.cpp
│   │   │   ├── routes_public.cpp
│   │   │   ├── routes_protected.cpp
│   │   │   └── notify_client.cpp
│   │   ├── shared/
│   │   │   └── dd_types.h         # Shared structs, queue types, extern handles
│   │   ├── main.cpp
│   │   └── CMakeLists.txt
│   ├── CMakeLists.txt
│   └── sdkconfig.defaults
├── cloud/                         # Cloud Functions
│   ├── functions/
│   │   ├── index.js               # /notify endpoint
│   │   └── hmac.js                # HMAC verification
│   ├── firestore.rules
│   ├── .env.example               # Placeholder keys — committed
│   └── package.json
```

---

# 12. Testing Strategy & Checklists

## 12.1 Automated Checks (Run After Every Session)

Claude Code runs these after every phase — fix all issues before stopping:

```bash
# Flutter
cd mobile
flutter analyze          # Must return: No issues found
dart test               # All tests pass
flutter build apk --debug  # Build must succeed

# Firmware (Phase 4+)
cd firmware
idf.py build            # Must compile with 0 errors, 0 warnings

# Cloud Functions (Phase 3+)
cd cloud/functions
npm run lint            # ESLint clean
npm test                # All Jest tests pass
```

## 12.2 Manual Integration Checks (Run When Hardware Available)

Run these in order after Phase 4 firmware is flashed:

- [ ] Device powers on, serial monitor shows "DingDong booting..."
- [ ] SD card mounted: "SD card mounted" in serial monitor
- [ ] Camera init: "Camera ready" in serial monitor
- [ ] SoftAP visible: "DingDong-Setup" appears in phone Wi-Fi list
- [ ] Provisioning: app wizard completes, device joins home Wi-Fi
- [ ] mDNS: `ping dingdong-<id>.local` resolves on LAN
- [ ] Health endpoint: `curl http://dingdong-<id>.local/api/v1/health` returns JSON
- [ ] Auth: curl with wrong token returns 401, correct token returns 200
- [ ] Rate limit: 6 failed auth attempts triggers 429
- [ ] PIR trigger: wave hand in front of PIR, motion event appears in app feed
- [ ] mmWave fusion: PIR + mmWave both needed — PIR-only should not trigger clip
- [ ] Doorbell: press button, doorbell event appears in app feed
- [ ] Clip: motion event creates clip, clip appears in Clips tab
- [ ] Clip playback: tap clip, video plays in app
- [ ] Clip delete: delete clip, removed from list
- [ ] Live view: Live tab shows MJPEG stream
- [ ] Push notification: motion event sends FCM push to Android device
- [ ] Doorbell notification: doorbell press sends distinct FCM push
- [ ] Notification tap: tapping notification opens correct Event Detail screen
- [ ] Wi-Fi reconnect: disconnect router for 30s, reconnect — device reconnects automatically
- [ ] Settings sync: change sensitivity slider, verify firmware applies new threshold
- [ ] Forget device: DELETE /provision resets device to SoftAP mode

## 12.3 Security Audit Checklist (Run Once Before Demo)

- [ ] `git log --all -- "*.json" | grep google-services` — must return nothing
- [ ] `git log --all -- ".env"` — must return nothing
- [ ] `git log --all -- "serviceAccount*"` — must return nothing
- [ ] GitHub Settings → Secret scanning → enabled ✅
- [ ] GitHub Settings → Push protection → enabled ✅
- [ ] Firebase Console → Firestore Rules → deployed and active
- [ ] Firebase Console → Auth → only Email/Password enabled
- [ ] Cloud Function env secrets set (not in code)
- [ ] `curl -X POST /notify` without HMAC → returns 401
- [ ] `curl -X POST /notify` with expired timestamp → returns 401
- [ ] `curl -X POST /notify` with replayed nonce → returns 401
- [ ] Unauthorized curl to /clips without token → returns 401
- [ ] `/provision/secret` called twice → second call rejected
- [ ] No hardcoded URLs, tokens, or secrets in any committed file
- [ ] `.env.example` contains only placeholders, not real values

## 12.4 MVP Completion Checklist

- [ ] User can sign up, log in, stay logged in across restarts
- [ ] User can onboard ESP32 via SoftAP wizard
- [ ] Motion event triggers FCM push notification on Android
- [ ] Doorbell button press triggers distinct FCM push notification
- [ ] App shows event in Events Feed (from Firestore)
- [ ] On home Wi-Fi: app lists and plays clips
- [ ] On home Wi-Fi: Live View shows MJPEG stream
- [ ] Unauthorized LAN device cannot access clips without token
- [ ] No secrets committed to repo

## 12.5 Optional Features Checklist (Sessions 7–10)

**Session 7 — Polish:**
- [ ] Dark mode theme implemented
- [ ] iOS APNs configured for FCM push
- [ ] Quiet hours / notification schedule
- [ ] Storage manager screen (SD usage + auto-delete)

**Session 8 — Power Features:**
- [ ] Remote access via Cloudflare Tunnel
- [ ] Privacy zones (mask motion areas)
- [ ] Activity heatmap screen
- [ ] Event tagging + search
- [ ] Multi-device support

**Session 9 — AI Features:**
- [ ] Smart Event Summaries (LLM API via Cloud Function proxy)
- [ ] In-app AI Support Chat (Claude/OpenAI, pre-loaded with DingDong docs)

**Session 10 — Advanced:**
- [ ] Package mode preset
- [ ] TFLite on-device motion classification (person/animal/vehicle, COCO dataset)

---

# 13. Cost & Free Tier Summary

| Service | Usage | Cost |
|---|---|---|
| Firebase Auth | Email/password auth, session tokens | Free |
| Firestore | Event metadata — well within 50K reads/20K writes/day | Free |
| Firebase Cloud Messaging | Push notifications to Android | Free |
| Cloud Functions | ~100 events/day = ~3K/month vs 2M free invocations | Free on Blaze |
| Claude/OpenAI API (Phase 9) | ~100 calls/month for summaries + support | ~$1-2/month |
| Hardware BOM | ESP32-S3, OV5640, PIR, mmWave, SD, PCB, enclosure | ~$235 |

Set a $1 billing alert in Firebase Console as a safety net.

---

# 14. What You Must Do Manually vs What AI Handles

## 14.1 AI Handles Autonomously

- Entire Flutter project structure, all screens, all components
- DDTheme design system, all DD components
- Riverpod providers, repositories, mock and real implementations
- Firebase Auth integration, FCM receiver, Firestore queries
- Firestore security rules file
- Cloud Function code (HMAC, Firestore write, FCM send)
- Full ESP-IDF firmware in C++ per Section 15
- .gitignore, .env.example, pre-commit hooks
- All curl test scripts for firmware endpoints
- All automated test files

## 14.2 You Must Do Manually (Account-Bound)

These cannot be automated — they require your Google/Firebase/Apple accounts:

1. **Firebase Console:** Create project, enable Email/Password Auth, enable Firestore, register Android app
2. **Download google-services.json** from Firebase → place in `mobile/android/app/` (not committed)
3. **Upgrade to Blaze plan** in Firebase Console (required for Cloud Functions)
4. **Set Cloud Function secrets** in Firebase/Google Cloud Secret Manager (never in code)
5. **Deploy Cloud Functions:** `firebase deploy --only functions` from `cloud/` directory
6. **Deploy Firestore rules:** `firebase deploy --only firestore:rules`
7. **Install ESP-IDF v5.x** on your machine (see Section 15.13)
8. **Flash firmware:** `idf.py -p COM<N> flash monitor` via USB to ESP32-S3
9. **iOS (if pursued):** Upload APNs key to Firebase Console

## 14.3 Files You Need in Your Codebase (Not Committed)

These files must exist locally but must NEVER be committed:

```
mobile/android/app/google-services.json   — Firebase Android config
.env                                       — local secrets for development
cloud/functions/.env                       — Cloud Function secrets for local testing
```

The `.env` file format (copy from `.env.example`, fill in real values):
```
DEVICE_SECRET_SIGNING_KEY=your_secret_here
FIREBASE_PROJECT_ID=dingdong-596c2
```

## 14.4 What Must Be Installed Before Session 4 (Firmware)

Before running the Phase 4 firmware session prompt, you need:

```
1. ESP-IDF v5.x Tools Installer
   → espressif.com/en/support/download/idf-windows-installer
   → Run installer, select ESP32-S3 as target
   → After install: open "ESP-IDF v5.x CMD" (special command prompt)

2. USB driver for ESP32-S3
   → CP2102 driver or CH340 driver depending on your DevKit's USB chip
   → Device Manager should show a COM port when ESP32-S3 is plugged in

3. Verify install:
   → Open ESP-IDF CMD
   → cd to firmware/
   → idf.py --version (should show 5.x)
   → idf.py set-target esp32s3
   → idf.py build (should compile after Phase 4 session)
```
4. Initialize ESP-IDF before any firmware commands by running from repo root:
   . .\esp-idf-init.ps1
   Must be run once per PowerShell session before any idf.py commands.

## 14.5 Session Prompts

**Session 2A (Design upgrade):**
> "Read docs/PRD.md fully. Phase 1 is complete. Before any Firebase work, upgrade the DDTheme design system to the full spec in Section 5. Rebuild dd_colors.dart, dd_typography.dart, dd_spacing.dart, dd_theme.dart, and all DD components per Section 5.6. Update all screen layouts per Section 5.7. Add lottie, google_fonts to pubspec.yaml. Run flutter analyze and fix all errors before stopping."

**Session 2B (Firebase):**
> "Read docs/PRD.md fully. Design system upgrade is complete (Session 2A done). Implement Phase 2B per Section 10: Firebase Auth in AuthNotifier, FCM token registration on sign-in and removal on sign-out, FirestoreEventsRepo, FCM receiver with DDToast for foreground and routing for background tap, auth redirect in routerProvider, Firestore security rules to cloud/firestore.rules. Run flutter analyze clean."

**Session 3 (Cloud Function):**
> "Read docs/PRD.md fully. Implement Phase 3 per Section 10: Cloud Function in cloud/functions/ per Section 8. HMAC verification, nonce deduplication, Firestore event write, FCM multicast send, device secret provisioning endpoint. Create .env.example. Write curl test commands for every verification path."

**Session 4 (Firmware):**
> "Read docs/PRD.md fully — specifically Section 15 which is the complete firmware implementation spec. Implement the full ESP-IDF v5.x firmware in C++ in firmware/. Start by reading existing files. Implement in order per Section 15.14. After all files written, verify idf.py build would succeed by checking includes, declarations, and CMakeLists.txt. Do not flash."

**Session 5 (Live View):**
> "Read docs/PRD.md. Implement Phase 5: firmware MJPEG stream task (Section 15.9) in C++, isolated from capture. App MJPEG viewer widget on Live View tab per Section 5.7, LAN gate enforced, pauses on background."

**Session 6 (Hardening):**
> "Read docs/PRD.md. Implement Phase 6: all retry/timeout/LAN gating per Section 10. Run full automated checks per Section 12.1. Verify all MVP checklist items in Section 12.4 are testable."

---

# 15. Firmware Implementation Specification (C++)

This is the complete source of truth for AI to implement the firmware autonomously.

## 15.1 ESP-IDF Project Setup

- Framework: ESP-IDF v5.x (latest stable)
- Language: **C++** — all files use `.cpp` extension. Use `extern "C"` for ESP-IDF C header includes where needed.
- Target: ESP32-S3
- Build: CMake via idf.py

`sdkconfig.defaults`:
```
CONFIG_ESP_MAIN_TASK_STACK_SIZE=8192
CONFIG_FREERTOS_HZ=1000
CONFIG_MBEDTLS_HMAC_DRBG_ENABLED=y
CONFIG_ESP_HTTP_SERVER_MAX_OPEN_SOCKETS=7
CONFIG_HTTPD_MAX_REQ_HDR_LEN=1024
CONFIG_FATFS_LFN_HEAP=y
CONFIG_CAMERA_TASK_STACK_SIZE=8192
CONFIG_ESP_TLS_INSECURE=n
CONFIG_ESP_TLS_SKIP_SERVER_CERT_VERIFY=n
```

## 15.2 GPIO Pin Configuration (dd_config.h)

**VERIFIED from Varun's schematic and ESP32-S3-DevKitC-1 pinout. Confirm CAM_PWDN against final Altium sheet before flashing.**

```cpp
// ── Camera DVP (OV5640) ──────────────────────────────────────────────────────
#define DD_CAM_D0_GPIO       GPIO_NUM_8
#define DD_CAM_D1_GPIO       GPIO_NUM_16
#define DD_CAM_D2_GPIO       GPIO_NUM_15
#define DD_CAM_D3_GPIO       GPIO_NUM_7
#define DD_CAM_D4_GPIO       GPIO_NUM_6
#define DD_CAM_D5_GPIO       GPIO_NUM_5
#define DD_CAM_D6_GPIO       GPIO_NUM_4
#define DD_CAM_D7_GPIO       GPIO_NUM_10
#define DD_CAM_PCLK_GPIO     GPIO_NUM_9
#define DD_CAM_XCLK_GPIO     GPIO_NUM_11
#define DD_CAM_HREF_GPIO     GPIO_NUM_3
#define DD_CAM_VSYNC_GPIO    GPIO_NUM_46
#define DD_CAM_SDA_GPIO      GPIO_NUM_14   // I2C SDA
#define DD_CAM_SCL_GPIO      GPIO_NUM_13   // I2C SCL
#define DD_CAM_RESETB_GPIO   GPIO_NUM_21
#define DD_CAM_PWDN_GPIO     GPIO_NUM_47   // Verify against final Altium sheet

// ── microSD SPI ───────────────────────────────────────────────────────────────
#define DD_SD_CS_GPIO        GPIO_NUM_38
#define DD_SD_MOSI_GPIO      GPIO_NUM_39
#define DD_SD_SCLK_GPIO      GPIO_NUM_40
#define DD_SD_MISO_GPIO      GPIO_NUM_41
#define DD_SD_MOUNT_POINT    "/sdcard"

// ── PIR Sensor ────────────────────────────────────────────────────────────────
#define DD_PIR_GPIO          GPIO_NUM_42   // Rising edge interrupt

// ── mmWave Radar UART (DFRobot SEN0395) ──────────────────────────────────────
#define DD_MMWAVE_UART_NUM   UART_NUM_1
#define DD_MMWAVE_TX_GPIO    GPIO_NUM_43   // ESP TX → mmWave RX
#define DD_MMWAVE_RX_GPIO    GPIO_NUM_44   // ESP RX ← mmWave TX
#define DD_MMWAVE_BAUD       115200

// ── Doorbell Button ───────────────────────────────────────────────────────────
#define DD_DOORBELL_GPIO     GPIO_NUM_2    // Active LOW, falling edge, pulled up via R6

// ── Buzzer ────────────────────────────────────────────────────────────────────
#define DD_BUZZER_GPIO       GPIO_NUM_1    // Active HIGH, through R5

// ── System Constants ──────────────────────────────────────────────────────────
#define DD_DEVICE_ID_LEN          16
#define DD_TOKEN_LEN              32
#define DD_TOKEN_HEX_LEN          65
#define DD_SOFTAP_SSID            "DingDong-Setup"
#define DD_SOFTAP_MAX_CONN        1
#define DD_HTTP_PORT              80
#define DD_MDNS_HOSTNAME_PREFIX   "dingdong-"

// ── Motion Fusion ─────────────────────────────────────────────────────────────
#define DD_MMWAVE_CONFIRM_WINDOW_MS   2000
#define DD_MMWAVE_MAX_DISTANCE_M      5.0f
#define DD_PIR_DEBOUNCE_MS            500

// ── Rate Limiting ─────────────────────────────────────────────────────────────
#define DD_AUTH_FAIL_MAX         5
#define DD_AUTH_FAIL_WINDOW_MS   60000

// ── Clip Settings ─────────────────────────────────────────────────────────────
#define DD_DEFAULT_CLIP_LENGTH_SEC   10
#define DD_MAX_CLIP_LENGTH_SEC       30
#define DD_VIDEO_BITRATE_KBPS        1500

// ── Cloud Function ────────────────────────────────────────────────────────────
#define DD_CLOUD_FUNCTION_URL   "https://us-central1-dingdong-596c2.cloudfunctions.net/notify"
#define DD_HMAC_NONCE_LEN       16
#define DD_TIMESTAMP_TOLERANCE_MS   60000
```

## 15.3 FreeRTOS Task Architecture

```
Task Name      | Priority | Stack  | Core | Role
---------------|----------|--------|------|----------------------------------
sensor_task    |    5     |  4096  |  0   | PIR ISR + mmWave UART + fusion
camera_task    |    4     |  8192  |  1   | OV5640 init + capture + frame push
storage_task   |    3     |  4096  |  0   | SD mount + file queue consumer
wifi_task      |    6     |  8192  |  0   | Wi-Fi + HTTP server + notify
stream_task    |    2     |  4096  |  1   | MJPEG stream (isolated)
```

**Shared handles (defined in main.cpp, extern in dd_types.h):**
```cpp
extern QueueHandle_t  event_queue;        // depth 10, dd_event_t
extern QueueHandle_t  storage_queue;      // depth 5,  storage_cmd_t
extern QueueHandle_t  stream_frame_queue; // depth 2,  camera_fb_t*
extern EventGroupHandle_t system_eg;
extern SemaphoreHandle_t settings_mutex;

// Event group bits
#define BIT_WIFI_CONNECTED   (1 << 0)
#define BIT_CAMERA_READY     (1 << 1)
#define BIT_SD_MOUNTED       (1 << 2)
#define BIT_PROVISIONED      (1 << 3)
#define BIT_STREAMING_ACTIVE (1 << 4)
```

## 15.4 sensor_task.cpp — PIR + mmWave + Fusion

```
- Configure DD_PIR_GPIO: input, pull-down, rising-edge ISR
- Configure DD_DOORBELL_GPIO: input, pull-up, falling-edge ISR (active LOW)
- ISRs post to internal isr_queue only (no heap alloc, no logging in ISR)
- Initialize UART1: DD_MMWAVE_TX/RX_GPIO, 115200 baud
- Task loop:
  PIR trigger → set pir_triggered=true, record pir_ts
  Doorbell trigger → post dd_event_t{DOORBELL} to event_queue, beep buzzer 100ms
  mmWave UART → parse $JYBSS frames (see 15.4.1)
    if presence=1 AND distance <= DD_MMWAVE_MAX_DISTANCE_M:
      if pir_triggered AND (now - pir_ts) <= DD_MMWAVE_CONFIRM_WINDOW_MS:
        post dd_event_t{MOTION, distance} to event_queue
        reset pir_triggered
  if pir_triggered AND (now - pir_ts) > DD_MMWAVE_CONFIRM_WINDOW_MS:
    reset pir_triggered (false positive suppressed — no mmWave confirm)
  PIR debounce: ignore re-triggers within DD_PIR_DEBOUNCE_MS
```

### 15.4.1 mmWave SEN0395 Full Output Mode

Parse ASCII lines: `"$JYBSS,<presence>,<distance_m>,<speed>,<angle>\r\n"`
- presence = 1: target detected
- distance_m: float in meters
- Ignore lines not starting with `$JYBSS`
- Use `uart_read_bytes` with 100ms timeout in loop

## 15.5 camera_task.cpp — OV5640 Init + Capture

```
- esp_camera_init() with camera_config_t:
  pixel_format: PIXFORMAT_JPEG
  frame_size: FRAMESIZE_HD (1280x720) for clips
  jpeg_quality: 12
  fb_count: 2
- Set BIT_CAMERA_READY in system_eg
- Loop on event_queue:
  MOTION/DOORBELL → capture frames for settings.clip_length_sec seconds
    → generate filename: /sdcard/clips/<unix_ts_ms>.avi
    → post storage_cmd_t{WRITE_CLIP, filename, data} to storage_queue
  If BIT_STREAMING_ACTIVE: switch to FRAMESIZE_QVGA, push frame to stream_frame_queue (non-blocking, drop if full)
  Clip capture takes priority: pause stream frames during clip, resume after
```

## 15.6 storage_task.cpp — SD Card SPI

```
- Mount: esp_vfs_fat_sdspi_mount() with DD_SD_MOSI/MISO/SCLK/CS
- On success: mkdir /sdcard/clips, set BIT_SD_MOUNTED
- Queue consumer loop:
  WRITE_CLIP: open file, write 4KB chunks, close
  DELETE_CLIP: unlink /sdcard/clips/<clipId>.avi
  LIST_CLIPS: scan dir, build JSON array [{clipId, ts, durationSec, sizeBytes}]
- On SD error: log, attempt remount after 5s
- clipId = unix_timestamp_ms string (no extension)
```

## 15.7 wifi_task.cpp — Wi-Fi + HTTP Server + Notify

```
First boot (no creds in NVS):
  - Start SoftAP: DD_SOFTAP_SSID, open, max 1 client
  - Start HTTP server with provisioning routes only

POST /provision received:
  - Parse + validate ssid/password/deviceName
  - Store in NVS, connect to station

On station connect:
  - Generate deviceId (MAC hex, 16 chars) if not in NVS
  - Generate token (32 bytes esp_fill_random → hex) if not in NVS
  - Start mDNS: hostname dingdong-<deviceId>
  - Set BIT_WIFI_CONNECTED + BIT_PROVISIONED
  - Stop SoftAP, start full HTTP server with all routes
  - Call esp_sntp_init("pool.ntp.org") for timestamp sync

Reconnect: exponential backoff 1s → 2s → 4s → 8s → max 30s
Keep HTTP server running during reconnect (503 on state-dependent endpoints)
```

## 15.8 HTTP Server Routes

All responses include CORS headers (Section 7.4). OPTIONS returns 200 for all URIs.

**auth_middleware.cpp:** Extract Authorization header, verify "Bearer <token>" format, mbedtls_ct_memcmp constant-time compare, rate-limit 5 fails → 429 for 60s.

**routes_public.cpp:**
- POST /provision: validate inputs, store NVS, trigger connect, return {ok:true}
- GET /provision/status: return state. Token returned once (NVS token_served flag).
- POST /provision/secret: validate 64-char hex, store in NVS, set secret_provisioned flag, reject if already provisioned
- DELETE /provision: clear NVS keys, schedule reboot after 500ms

**routes_protected.cpp:**
- GET /health: return {ok, deviceId, fwVersion:"1.0.0", time, lastEventTs}
- GET /events?since=ts: return last 50 events from circular buffer, filtered by since
- GET /clips: request LIST_CLIPS from storage_queue, return JSON
- GET /clips/<clipId>: stream file in 4KB chunks, Content-Length header
- DELETE /clips/<clipId>: post DELETE_CLIP to storage_queue
- GET /settings: read NVS, return JSON
- POST /settings: validate ranges, write NVS, update live settings struct (mutex locked)

## 15.9 stream_task.cpp — Isolated MJPEG

```
- Register GET /stream handler
- On client connect:
  - Set BIT_STREAMING_ACTIVE
  - Send Content-Type: multipart/x-mixed-replace; boundary=frame
  - Loop: get frame from stream_frame_queue (100ms timeout)
    - Send: --frame\r\nContent-Type: image/jpeg\r\nContent-Length: <n>\r\n\r\n<data>\r\n
    - Skip frame if queue empty (camera busy)
    - Break on client disconnect
  - Clear BIT_STREAMING_ACTIVE
- Reject second client with 503
- stream_task never calls esp_camera_fb_get() directly
```

## 15.10 notify_client.cpp — HMAC + Cloud Function POST

```
- Build JSON body per Section 8.3
- Generate 16-byte nonce via esp_fill_random → 32-char hex string
- Get timestamp: SNTP epoch + esp_timer offset
- Compute HMAC-SHA256 (mbedtls_md_hmac):
  key: device_secret from NVS
  message: timestamp_str || nonce || body
  output: 32 bytes → 64-char hex
- POST to DD_CLOUD_FUNCTION_URL:
  X-Timestamp, X-Nonce, X-Signature headers
  esp_http_client, timeout 10s
  Pin root CA cert for *.cloudfunctions.net (embed PEM as const char[])
- On success (200): log ok
- On failure: retry max 3 times, 5s delay
```

### 15.10.1 Device Secret Provisioning Flow

1. App completes onboarding, device paired in Firestore
2. App calls Cloud Function /provisionSecret endpoint
3. Cloud Function generates 32-byte secret → stores in devices/{id}.secret (admin-only Firestore field)
4. Cloud Function returns secret to app
5. App calls device POST /provision/secret with secret hex
6. Device stores in NVS under "device_secret", sets secret_provisioned=1
7. All subsequent notify calls use this secret for HMAC

## 15.11 NVS Key Reference

Namespace: "dingdong"

| Key | Type | Description |
|---|---|---|
| wifi_ssid | string | Home Wi-Fi SSID |
| wifi_pass | string | Home Wi-Fi password |
| device_id | string | 16-char hex MAC-based ID |
| api_token | string | 64-char hex Bearer token |
| token_served | uint8 | 1 = token already returned to app |
| device_secret | string | 64-char hex HMAC secret |
| secret_provisioned | uint8 | 1 = secret set, reject re-provisioning |
| device_name | string | Human-readable name |
| motion_enabled | uint8 | 0 or 1 |
| notify_enabled | uint8 | 0 or 1 |
| mmwave_threshold | uint8 | 0–100 |
| clip_length_sec | uint8 | 5, 10, 20, or 30 |
| last_event_ts | int64 | Unix ms of last event |

## 15.12 main.cpp — Entry Point

```cpp
extern "C" void app_main(void) {
    // 1. NVS flash init
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    // 2. Create shared queues
    event_queue         = xQueueCreate(10, sizeof(dd_event_t));
    storage_queue       = xQueueCreate(5,  sizeof(storage_cmd_t));
    stream_frame_queue  = xQueueCreate(2,  sizeof(camera_fb_t*));
    system_eg           = xEventGroupCreate();
    settings_mutex      = xSemaphoreCreateMutex();

    // 3. Load settings from NVS into global dd_settings
    load_settings_from_nvs();

    // 4. Launch tasks
    xTaskCreatePinnedToCore(sensor_task,  "sensor",  4096, nullptr, 5, nullptr, 0);
    xTaskCreatePinnedToCore(camera_task,  "camera",  8192, nullptr, 4, nullptr, 1);
    xTaskCreatePinnedToCore(storage_task, "storage", 4096, nullptr, 3, nullptr, 0);
    xTaskCreatePinnedToCore(wifi_task,    "wifi",    8192, nullptr, 6, nullptr, 0);
    xTaskCreatePinnedToCore(stream_task,  "stream",  4096, nullptr, 2, nullptr, 1);

    ESP_LOGI("main", "DingDong booting...");
}
```

## 15.13 Build & Flash

```bash
# Open ESP-IDF v5.x CMD (Windows) or source export.sh (Mac/Linux)
cd firmware
idf.py set-target esp32s3
idf.py menuconfig        # verify sdkconfig
idf.py build             # compile
idf.py -p COM<N> flash monitor   # flash + open serial monitor

# Expected serial output:
# I (xxx) main: DingDong booting...
# I (xxx) storage: SD card mounted
# I (xxx) camera: Camera ready
# I (xxx) wifi: SoftAP started: DingDong-Setup   (first boot)
# I (xxx) wifi: Wi-Fi connected, IP: x.x.x.x     (after provisioning)
# I (xxx) wifi: mDNS started: dingdong-<id>.local
```

## 15.14 Session 4 Firmware Prompt

```
Before any idf.py commands, run: . .\esp-idf-init.ps1 from repo root.
Read docs/PRD.md fully — Section 15 is the complete firmware spec.
Implement the full ESP-IDF v5.x firmware in C++ in firmware/.

First read all existing files in firmware/ to understand current scaffolding.

Implement in this order:
1. firmware/main/shared/dd_types.h — all shared structs, event types, queue types, extern handle declarations
2. firmware/main/config/dd_config.h — all GPIO defines and constants from Section 15.2
3. firmware/CMakeLists.txt + firmware/main/CMakeLists.txt — proper ESP-IDF C++ project structure
4. firmware/sdkconfig.defaults — all settings from Section 15.1
5. firmware/main/main.cpp — entry point per Section 15.12
6. firmware/main/tasks/sensor_task.cpp — PIR + mmWave + fusion per Section 15.4
7. firmware/main/tasks/camera_task.cpp — OV5640 per Section 15.5
8. firmware/main/tasks/storage_task.cpp — SD card per Section 15.6
9. firmware/main/tasks/wifi_task.cpp — Wi-Fi + HTTP server per Section 15.7
10. firmware/main/api/http_server.cpp — route registration + CORS per Section 15.8
11. firmware/main/api/auth_middleware.cpp — Bearer token validation per Section 15.8
12. firmware/main/api/routes_public.cpp — provisioning endpoints per Section 15.8
13. firmware/main/api/routes_protected.cpp — all protected endpoints per Section 15.8
14. firmware/main/tasks/stream_task.cpp — MJPEG stream per Section 15.9
15. firmware/main/api/notify_client.cpp — HMAC Cloud Function POST per Section 15.10

After all files written, verify idf.py build would succeed:
- All #include paths correct and using extern "C" where needed for C headers
- All function declarations match definitions
- All extern handles in dd_types.h match definitions in main.cpp
- CMakeLists.txt lists all .cpp source files
- No C++ features that conflict with ESP-IDF C API

Do not flash. Output build-ready C++ code only.
```

---

# 16. Optional Features — Sessions 7–10

## Session 7 — Polish & Accessibility

- Dark mode theme (DDTheme dark variant, toggle in Account Settings)
- iOS APNs key configuration for FCM push on iPhone
- Quiet hours: schedule notification silence window (stored in Firestore device doc)
- Storage manager screen: SD card usage bar, auto-delete oldest clips toggle + threshold

## Session 8 — Power User Features

- Remote access via Cloudflare Tunnel: DeviceApiClient already takes configurable baseUrl — just update discovery to try tunnel URL when mDNS fails
- Privacy zones: tap-to-draw mask overlay on live view frame, stored as exclusion rect in device settings
- Activity heatmap: motion frequency chart by hour of day, built from Firestore events collection
- Event tagging + search: add optional label to events, filter feed by type/label/date range
- Multi-device support: add second device to same account, tabbed navigation between devices

## Session 9 — AI Features

### Smart Event Summaries

After each event notification, the app makes an optional call to a Cloud Function proxy (`/summarize`) which calls the Claude API (or OpenAI) with:
- System prompt: "You are a doorbell security assistant. Summarize this event in one clear sentence."
- User message: event type, sensor stats (PIR triggered, mmWave distance), time of day
- Response displayed as a subtitle under the event in the feed

Cost: ~$0.001 per event at Claude Haiku pricing. Cloud Function proxy keeps API key server-side.

### In-App AI Support Chat

Floating chat button on Settings tab. Opens DDBottomSheet chat interface. System prompt pre-loaded with DingDong full documentation (setup, troubleshooting, settings guide, FAQ). User messages sent to Cloud Function proxy which calls LLM API. Responses streamed back. No conversation history stored — each session is fresh.

Implementation: new Cloud Function `/support` endpoint, ~80 lines of Flutter chat UI, ~40 lines of Node.js proxy.

## Session 10 — Advanced Hardware ML

### Package Mode

Preset button in Device Settings: temporarily sets clip length to 30s, mmWave threshold to maximum sensitivity, adds "Package Mode" label to events captured during this window. Auto-expires after 4 hours.

### On-Device TFLite Classification

Use TensorFlow Lite for Microcontrollers on ESP32-S3 to classify motion events as person / animal / vehicle before triggering a clip. Base model: MobileNetV2 quantized to INT8, pre-trained on COCO dataset (freely available at cocodataset.org). Fine-tune on doorbell-angle frames if time permits. Inference runs on Core 1 after PIR+mmWave fusion confirms event, adds classification label to event metadata. Requires ~500KB flash for model weights — feasible on ESP32-S3's 8MB flash.

---

# 17. Environment & Security Files

## 17.1 Root .gitignore

```gitignore
# ── Secrets — NEVER commit ──────────────────────────────────────────────────
.env
.env.*
!.env.example
serviceAccount*.json
*.key
*secret*

# ── Firebase ─────────────────────────────────────────────────────────────────
google-services.json
GoogleService-Info.plist 

# ── Node / Cloud Functions ───────────────────────────────────────────────────
node_modules/
cloud/functions/node_modules/

# ── Flutter ───────────────────────────────────────────────────────────────────
**/build/
**/.dart_tool/
**/.flutter-plugins
**/.flutter-plugins-dependencies

# ── Android ───────────────────────────────────────────────────────────────────
*.jks
*.keystore
local.properties

# ── ESP-IDF ───────────────────────────────────────────────────────────────────
firmware/build/
firmware/managed_components/
firmware/sdkconfig
firmware/.cache/

# ── OS ────────────────────────────────────────────────────────────────────────
.DS_Store
Thumbs.db
desktop.ini

# ── IDE ───────────────────────────────────────────────────────────────────────
.vscode/settings.json
.idea/
*.iml
```

## 17.2 cloud/.env.example

```bash
# Copy this to .env and fill in real values. Never commit .env.
FIREBASE_PROJECT_ID=dingdong-596c2
CLOUD_FUNCTION_REGION=us-central1

# Set via Firebase Secret Manager, not .env, in production:
# firebase functions:secrets:set DEVICE_SECRET_SIGNING_KEY
DEVICE_SECRET_SIGNING_KEY=your_64_char_hex_secret_here
```

## 17.3 Pre-Commit Hook

Create `.git/hooks/pre-commit`:
```bash
#!/bin/sh
# Block commits containing known secret patterns
if git diff --cached --name-only | xargs grep -l "serviceAccount\|PRIVATE KEY\|google-services" 2>/dev/null; then
  echo "ERROR: Potential secret detected in staged files. Commit blocked."
  exit 1
fi
```
`chmod +x .git/hooks/pre-commit`
