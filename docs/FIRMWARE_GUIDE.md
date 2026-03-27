# DingDong — Firmware Guide

**For:** Vini Silva and Gian Rosario  
**Purpose:** Complete explanation of every firmware file, how the system works, GPIO pins, build and flash instructions, and how firmware connects to the mobile app.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [GPIO Pin Reference](#2-gpio-pin-reference)
3. [FreeRTOS Task Architecture](#3-freertos-task-architecture)
4. [File-by-File Explanation](#4-file-by-file-explanation)
5. [How Firmware Connects to the App](#5-how-firmware-connects-to-the-app)
6. [Event Flow — End to End](#6-event-flow--end-to-end)
7. [Build, Flash, and Monitor](#7-build-flash-and-monitor)
8. [Expected Serial Output](#8-expected-serial-output)
9. [NVS Key Reference](#9-nvs-key-reference)
10. [Common Firmware Issues](#10-common-firmware-issues)

---

## 1. System Overview

The firmware runs on an ESP32-S3 microcontroller using the ESP-IDF framework (Espressif's official SDK) with FreeRTOS for multitasking.

The device operates in two modes:

**SoftAP Mode (first boot / factory reset):**
- Device broadcasts its own Wi-Fi hotspot named `DingDong-Setup`
- User connects their phone to this hotspot
- App sends home Wi-Fi credentials to the device at `192.168.4.1`
- Device connects to home Wi-Fi and switches to normal mode

**Normal Mode (after provisioning):**
- Device is connected to home Wi-Fi
- Device advertises itself on the local network as `dingdong-<deviceId>.local`
- App discovers it via mDNS and communicates over the local network
- Device monitors sensors continuously and sends alerts when motion is confirmed

---

## 2. GPIO Pin Reference

These are **finalized pins verified against the Altium schematic**. Do not change them without updating both `dd_config.h` and the PCB.

### Camera (OV5640) — DVP Interface

| Signal | GPIO | Notes |
|--------|------|-------|
| D0 (data bit 0) | GPIO 8 | |
| D1 (data bit 1) | GPIO 16 | |
| D2 (data bit 2) | GPIO 15 | |
| D3 (data bit 3) | GPIO 7 | |
| D4 (data bit 4) | GPIO 6 | |
| D5 (data bit 5) | GPIO 5 | |
| D6 (data bit 6) | GPIO 4 | |
| D7 (data bit 7) | GPIO 10 | |
| PCLK (pixel clock) | GPIO 9 | |
| XCLK (external clock) | GPIO 11 | |
| HREF (horizontal ref) | GPIO 3 | |
| VSYNC (vertical sync) | GPIO 46 | |
| SDA (I2C data) | GPIO 14 | Camera configuration |
| SCL (I2C clock) | GPIO 13 | Camera configuration |
| RESETB (reset) | GPIO 21 | Active low |
| PWDN (power down) | GPIO 47 | **Verify against final Altium sheet** |

### microSD Card — SPI Interface

| Signal | GPIO | Notes |
|--------|------|-------|
| CS (chip select) | GPIO 38 | |
| MOSI (data out) | GPIO 39 | |
| SCLK (clock) | GPIO 40 | |
| MISO (data in) | GPIO 41 | |
| Mount point | `/sdcard` | FAT filesystem |

### Sensors and I/O

| Component | GPIO | Type | Notes |
|-----------|------|------|-------|
| PIR sensor (HC-SR501) | GPIO 42 | Input, rising edge interrupt | Thermal presence detection |
| mmWave TX (ESP → radar) | GPIO 43 | UART1 TX | 115200 baud |
| mmWave RX (radar → ESP) | GPIO 44 | UART1 RX | 115200 baud |
| Doorbell button | GPIO 2 | Input, falling edge, pull-up | Active LOW via R6 |
| Buzzer (SDC1614L5-01) | GPIO 1 | Output, active HIGH | Through R5 resistor |

### Key Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| DD_SOFTAP_SSID | "DingDong-Setup" | Hotspot name during provisioning |
| DD_HTTP_PORT | 80 | Device HTTP server port |
| DD_MMWAVE_CONFIRM_WINDOW_MS | 2000 | Time window for PIR+mmWave to agree (2 seconds) |
| DD_MMWAVE_MAX_DISTANCE_M | 5.0 | Max detection distance in meters |
| DD_PIR_DEBOUNCE_MS | 500 | Minimum time between PIR triggers |
| DD_AUTH_FAIL_MAX | 5 | Failed auth attempts before rate limiting |
| DD_AUTH_FAIL_WINDOW_MS | 60000 | Rate limit window (60 seconds) |

---

## 3. FreeRTOS Task Architecture

The firmware runs 5 independent tasks simultaneously. Each task has its own priority, stack size, and CPU core assignment.

```
Task Name     | Priority | Stack  | Core | Role
--------------|----------|--------|------|-----------------------------------
wifi_task     |    6     |  8192  |  0   | Wi-Fi, SoftAP, HTTP server, notify
sensor_task   |    5     |  4096  |  0   | PIR, mmWave UART, sensor fusion
camera_task   |    4     |  8192  |  1   | OV5640 init, clip capture, frames
storage_task  |    3     |  4096  |  0   | SD mount, file read/write/list
stream_task   |    2     |  4096  |  1   | MJPEG live stream (isolated)
```

**Priority 6 = highest.** wifi_task has highest priority because Wi-Fi and HTTP serving must be responsive. stream_task has lowest priority so it never starves the other tasks.

### Shared Communication Channels

Tasks communicate through queues and an event group — never through shared variables without mutex protection.

```
event_queue         — sensor_task → camera_task (motion/doorbell events, depth 10)
storage_queue       — camera_task → storage_task (clip write commands, depth 5)
stream_frame_queue  — camera_task → stream_task (JPEG frames, depth 2)
system_eg           — event group tracking system state bits
settings_mutex      — protects the global dd_settings struct from concurrent access
```

### System Event Group Bits

```
BIT_WIFI_CONNECTED   (bit 0) — Wi-Fi station connected
BIT_CAMERA_READY     (bit 1) — OV5640 initialized successfully
BIT_SD_MOUNTED       (bit 2) — microSD card mounted
BIT_PROVISIONED      (bit 3) — device has been provisioned with home Wi-Fi
BIT_STREAMING_ACTIVE (bit 4) — an app client is receiving the live stream
```

---

## 4. File-by-File Explanation

### firmware/main/main.cpp

**What it does:** Entry point of the entire firmware. Runs once when the device boots.

Sequence:
1. Initializes NVS (Non-Volatile Storage) — this is where Wi-Fi credentials and the API token are stored persistently
2. Creates all shared queues and the event group
3. Loads saved settings from NVS into the global `dd_settings` struct
4. Launches all 5 FreeRTOS tasks using `xTaskCreatePinnedToCore()`
5. Logs "DingDong booting..."

After `app_main()` returns, FreeRTOS takes over and runs the tasks indefinitely.

---

### firmware/main/config/dd_config.h

**What it does:** Defines every GPIO pin number and every system constant used throughout the firmware.

This is the single place where pins and constants are defined. If a pin ever needs to change (because of a PCB revision), you change it here only — everything else picks it up automatically.

**Important:** The `DD_CAM_PWDN_GPIO` (GPIO 47) has a note to verify against the final Altium schematic before flashing. Cross-check this against the PCB schematic before the first flash.

---

### firmware/main/shared/dd_types.h

**What it does:** Defines all shared data structures used across multiple tasks. Every task that needs to communicate uses types defined here.

Key types:
- `dd_event_t` — represents a motion or doorbell event, contains type (MOTION/DOORBELL) and sensor stats (PIR triggered, mmWave distance)
- `storage_cmd_t` — command sent to storage_task (WRITE_CLIP, DELETE_CLIP, LIST_CLIPS)
- `dd_settings_t` — global settings struct: motionEnabled, notifyEnabled, mmwaveThreshold, clipLengthSec
- `dd_clip_info_t` — metadata for one clip: clipId, timestamp, duration, size in bytes

Also declares `extern` handles for all queues and the event group — these are defined once in main.cpp and used everywhere else.

---

### firmware/main/tasks/sensor_task.cpp

**What it does:** Monitors both sensors and implements the dual-sensor fusion logic. This is the most important task for the core DingDong value proposition — reducing false alerts.

**PIR sensor:**
- Configured as a hardware interrupt on GPIO 42, rising edge
- When the PIR fires (person detected by body heat), it posts to an internal ISR queue
- The task reads from this queue and sets `pir_triggered = true` with a timestamp

**Doorbell button:**
- Configured as a hardware interrupt on GPIO 2, falling edge (active LOW)
- When pressed, immediately posts a DOORBELL event to the event_queue and beeps the buzzer for 100ms

**mmWave radar:**
- Reads ASCII frames from UART1 continuously
- Parses lines in the format: `$JYBSS,<presence>,<distance_m>,<speed>,<angle>\r\n`
- Only processes lines starting with `$JYBSS`
- Extracts presence (1 = target detected) and distance_m

**Fusion logic (the key algorithm):**
```
IF mmWave says presence=1 AND distance <= 5.0m:
    IF PIR was triggered in the last 2 seconds:
        → Validated motion event! Post MOTION event to event_queue with distance
        → Reset pir_triggered

IF PIR triggered BUT no mmWave confirmation within 2 seconds:
    → False positive suppressed. Reset pir_triggered. No alert sent.
```

This means a dog walking past (PIR triggers from body heat, mmWave sees motion) will be suppressed if the PIR fires but mmWave distance is too large or presence=0. A person approaching (both sensors agree within 2 seconds) fires an alert.

**PIR debounce:** The PIR is ignored for 500ms after it fires to prevent duplicate triggers.

---

### firmware/main/tasks/camera_task.cpp

**What it does:** Manages the OV5640 camera. Initializes it on boot, captures video clips when events occur, and pushes frames to the stream task.

**Initialization:**
- Calls `esp_camera_init()` with the DVP pin configuration from dd_config.h
- Sets frame size to FRAMESIZE_HD (1280×720) for clips
- Sets JPEG quality to 12 (higher number = lower quality, smaller file)
- Uses 2 frame buffers for smooth capture
- Sets BIT_CAMERA_READY in system_eg when done

**Clip capture (triggered by events):**
- Waits on event_queue for MOTION or DOORBELL events
- When an event arrives, captures JPEG frames for `settings.clip_length_sec` seconds (5, 10, 20, or 30)
- Generates filename: `/sdcard/clips/<unix_timestamp_ms>.avi`
- Posts the clip data to storage_queue for writing to SD card

**Live stream frames:**
- When BIT_STREAMING_ACTIVE is set (app is watching live), switches to QVGA (320×240) resolution
- Pushes frames to stream_frame_queue (non-blocking, drops frames if queue full)
- **Clip capture always takes priority** — stream pauses during clip recording and resumes after

---

### firmware/main/tasks/storage_task.cpp

**What it does:** Manages all microSD card operations. Reads/writes/deletes clips on the SD card.

**Initialization:**
- Mounts the FAT filesystem on the SD card using SPI (pins from dd_config.h)
- Creates `/sdcard/clips/` directory if it doesn't exist
- Sets BIT_SD_MOUNTED in system_eg when done
- If mount fails, logs the error and retries every 5 seconds

**Queue consumer loop:**
- Waits for commands from storage_queue
- `WRITE_CLIP`: Opens file, writes data in 4KB chunks, closes file
- `DELETE_CLIP`: Calls `unlink()` to delete `/sdcard/clips/<clipId>.avi`
- `LIST_CLIPS`: Scans the clips directory, builds a JSON array of all clips with metadata

**Clip ID format:** The clip ID is the Unix timestamp in milliseconds as a string (e.g., `1711234567890`). The actual file on SD is `/sdcard/clips/1711234567890.avi`.

---

### firmware/main/tasks/wifi_task.cpp

**What it does:** The most complex task. Manages Wi-Fi connection, SoftAP provisioning, HTTP server, and sending event notifications to the Cloud Function.

**First boot (no Wi-Fi credentials in NVS):**
1. Starts SoftAP: broadcasts `DingDong-Setup` hotspot, max 1 client
2. Starts HTTP server with provisioning routes only (POST /provision, GET /provision/status)
3. Waits for the app to send credentials

**After receiving credentials via POST /provision:**
1. Stores SSID and password in NVS
2. Connects to home Wi-Fi in station mode
3. Generates deviceId (16-char hex based on MAC address) if not already in NVS
4. Generates API token (32 bytes random → 64-char hex) if not already in NVS
5. Starts mDNS advertising as `dingdong-<deviceId>.local`
6. Sets BIT_WIFI_CONNECTED and BIT_PROVISIONED
7. Stops SoftAP, starts full HTTP server with all routes
8. Syncs time via SNTP (`pool.ntp.org`)

**Reconnection:**
- If Wi-Fi drops, reconnects with exponential backoff: 1s → 2s → 4s → 8s → max 30s
- HTTP server stays running during reconnect (returns 503 on state-dependent endpoints)

**Sending event notifications:**
- When sensor_task posts to event_queue, wifi_task reads it
- Calls `notify_client.cpp` to POST the event to the Cloud Function
- The Cloud Function writes to Firestore and sends FCM push to the app

---

### firmware/main/tasks/stream_task.cpp

**What it does:** Handles the live MJPEG video stream. Completely isolated from the capture pipeline so it can never block motion detection.

**How it works:**
- Registers a handler for `GET /stream`
- When an app connects: sets BIT_STREAMING_ACTIVE, sends multipart HTTP headers
- Loop: reads frame from stream_frame_queue, sends as MJPEG frame
- If queue is empty (camera is busy capturing a clip), skips — no blocking
- When client disconnects: clears BIT_STREAMING_ACTIVE
- Only one streaming client allowed at a time — second client gets 503

**MJPEG format:**
```
Content-Type: multipart/x-mixed-replace; boundary=frame

--frame\r\n
Content-Type: image/jpeg\r\n
Content-Length: <n>\r\n
\r\n
<JPEG data>\r\n
```

---

### firmware/main/api/http_server.cpp

**What it does:** Sets up the ESP-IDF HTTP server and registers all routes.

All responses include CORS headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
```

OPTIONS preflight requests return 200 immediately for all URI patterns.

---

### firmware/main/api/auth_middleware.cpp

**What it does:** Validates the Bearer token on every protected request.

- Extracts the `Authorization` header
- Verifies format: must be `Bearer <token>`
- Uses `mbedtls_ct_memcmp()` for **constant-time comparison** — this prevents timing attacks where an attacker could guess the token one byte at a time by measuring response time
- Rate limiting: after 5 failed attempts, returns 429 for 60 seconds
- Rate limit is per-IP

---

### firmware/main/api/routes_public.cpp

**What it does:** Handles provisioning endpoints that do not require authentication. Available during SoftAP mode.

**POST /provision:**
- Accepts: `{ ssid, password, deviceName }`
- Validates lengths (SSID 1-32 chars, password 0-63 chars)
- Stores in NVS and triggers Wi-Fi connect
- Returns `{ ok: true }`

**GET /provision/status:**
- Returns current provisioning state: `connecting`, `connected`, or `failed`
- When state = `connected`, includes `ip`, `deviceId`, and **token** (one time only)
- The `token_served` NVS flag ensures the token is only ever returned once

**POST /provision/secret:**
- Accepts: `{ secret: "64-char-hex" }` 
- Called by the app during onboarding after Cloud Function generates the HMAC secret
- Stores the secret in NVS under `device_secret`
- Sets `secret_provisioned` NVS flag — rejects repeat calls

**DELETE /provision:**
- Clears all NVS keys (Wi-Fi credentials, token, secret, device ID)
- Schedules a reboot after 500ms
- Device reboots into SoftAP mode (factory reset behavior)
- Called by the app when user taps "Remove Device"

---

### firmware/main/api/routes_protected.cpp

**What it does:** All API endpoints that require a valid Bearer token. Auth middleware runs first for all of these.

**GET /health:**
- Returns: `{ ok: true, deviceId, fwVersion: "1.0.0", time, lastEventTs }`
- The app polls this every 30 seconds to check if the device is online
- Also returns `signal_strength` (Wi-Fi RSSI in dBm) for the signal indicator in the app

**GET /events?since=\<timestamp\>:**
- Returns events from the device's in-memory circular buffer
- Used as a fallback when Firestore is unreachable
- Normal operation uses Firestore for events

**GET /clips:**
- Requests LIST_CLIPS from storage_task via storage_queue
- Returns JSON array of all clips: `[{ clipId, ts, durationSec, sizeBytes }]`

**GET /clips/{clipId}:**
- Streams the clip file from SD card in 4KB chunks
- Includes `Content-Length` header so the app can show download progress
- App downloads the full clip then plays it

**DELETE /clips/{clipId}:**
- Posts DELETE_CLIP to storage_queue
- Returns `{ ok: true }`

**GET /settings:**
- Reads current settings from NVS
- Returns: `{ motionEnabled, notifyEnabled, mmwaveThreshold, clipLengthSec }`

**POST /settings:**
- Validates all fields against allowed ranges
- Writes to NVS
- Updates the live `dd_settings` struct (mutex locked so no race conditions)
- Changes take effect immediately — no reboot needed

---

### firmware/main/api/notify_client.cpp

**What it does:** Signs and sends event notifications to the Cloud Function. This is the bridge between the device and the app's push notifications.

**Process:**
1. Builds the JSON body with event data (deviceId, type, timestamp, clipId, sensorStats)
2. Generates a 16-byte random nonce (32-char hex) using `esp_fill_random()`
3. Gets current timestamp from SNTP
4. Computes HMAC-SHA256 signature: `HMAC(device_secret, timestamp + nonce + body)`
5. POSTs to the Cloud Function URL with:
   - `X-Timestamp: <unix_ms>`
   - `X-Nonce: <32-char-hex>`
   - `X-Signature: <64-char-hex>`
6. On success (HTTP 200): logs ok
7. On failure: retries up to 3 times with 5 second delay between attempts

**Root CA certificate pinning:**
The firmware embeds the root CA certificate for `*.cloudfunctions.net` to prevent man-in-the-middle attacks. This is set in `esp_http_client_config_t.cert_pem`.

---

## 5. How Firmware Connects to the App

This section explains every touchpoint between the firmware and the mobile app.

### Connection: Onboarding

```
App (phone on DingDong-Setup hotspot)
  ↓ POST http://192.168.4.1/provision  {ssid, password, deviceName}
Device (SoftAP mode)
  ↓ Stores credentials, connects to home Wi-Fi
App polls GET http://192.168.4.1/provision/status
  ← {state: "connected", deviceId: "abc123", ip: "192.168.1.50", token: "64-char-hex"}
App stores token in flutter_secure_storage
App calls Cloud Function provisionSecret (generates HMAC secret)
App POST http://192.168.4.1/provision/secret  {secret: "64-char-hex"}
Device stores HMAC secret in NVS
App registers device in Firestore (deviceId, displayName, ownerId)
App resolves dingdong-abc123.local via mDNS for future communication
```

### Connection: Motion Event to Push Notification

```
PIR sensor fires → sensor_task sets pir_triggered=true
mmWave confirms within 2 seconds → sensor_task posts MOTION event to event_queue
camera_task reads event → captures clip → posts to storage_queue
storage_task writes clip to /sdcard/clips/<ts>.avi
wifi_task reads event → calls notify_client
notify_client POSTs signed request to Cloud Function
Cloud Function verifies HMAC → writes event to Firestore → sends FCM push
App receives FCM push → shows notification
User taps notification → app opens to Event Detail screen for that event
```

### Connection: Live View

```
App navigates to Live View tab (must be on LAN)
App opens http://dingdong-<id>.local/api/v1/stream
Device stream_task starts serving MJPEG frames
camera_task switches to QVGA resolution, pushes frames to stream_frame_queue
stream_task reads frames and sends them to app
App renders frames as they arrive
When app goes to background → closes stream connection
stream_task clears BIT_STREAMING_ACTIVE
```

### Connection: Device Settings

```
App opens Device Settings screen
App GET http://dingdong-<id>.local/api/v1/settings
Device returns current settings from NVS
App displays settings with current values
User changes motion sensitivity slider
App POST http://dingdong-<id>.local/api/v1/settings  {mmwaveThreshold: 65}
Device validates, writes to NVS, updates dd_settings immediately
App shows success toast
```

### Connection: Clip Playback

```
App opens Clips tab (must be on LAN)
App GET http://dingdong-<id>.local/api/v1/clips
Device requests list from storage_task, returns JSON array
App displays list of clips with timestamps, duration, size
User taps a clip
App GET http://dingdong-<id>.local/api/v1/clips/<clipId>
Device streams file from SD card in 4KB chunks
App shows download progress bar
When download complete, app plays clip in better_player
```

---

## 6. Event Flow — End to End

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MOTION DETECTED                                    │
│                                                                               │
│  PIR fires (GPIO 42, rising edge)                                            │
│      ↓                                                                        │
│  sensor_task: pir_triggered = true, record timestamp                         │
│      ↓                                                                        │
│  mmWave UART: $JYBSS,1,2.1,... received                                      │
│      ↓                                                                        │
│  sensor_task: distance=2.1m ≤ 5.0m, PIR fired within 2s → VALIDATED        │
│      ↓                                                                        │
│  event_queue ← dd_event_t{MOTION, distance=2.1}                              │
│      ↓                                                                        │
│  camera_task reads event → captures 10 seconds of JPEG frames                │
│      ↓                                                                        │
│  storage_queue ← WRITE_CLIP command                                           │
│      ↓                                                                        │
│  storage_task writes /sdcard/clips/1711234567890.avi                          │
│      ↓                                                                        │
│  wifi_task reads same event → calls notify_client                             │
│      ↓                                                                        │
│  notify_client: build JSON, sign HMAC, POST to Cloud Function                │
│      ↓                                                                        │
│  Cloud Function: verify HMAC → write to Firestore → generate AI summary     │
│      ↓                                                                        │
│  Cloud Function: send FCM multicast to all device members                    │
│      ↓                                                                        │
│  Android phone: receives push notification                                    │
│  Notification body: "Someone approached 2.1 meters from your door."          │
│      ↓                                                                        │
│  User taps notification → app opens Event Detail screen                       │
│  Event Detail: shows AI summary, sensor stats, Play Clip button (on LAN)     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Build, Flash, and Monitor

### Prerequisites

- ESP-IDF 5.x installed (see HANDOVER.md Section 2.7)
- ESP32-S3-DevKitC-1 connected via USB
- Terminal is the ESP-IDF CMD (not regular PowerShell)

### Full Build + Flash + Monitor

```bash
# From repo root, set up environment
. .\esp-idf-init.ps1

# Go to firmware directory
cd firmware

# Set target (only needed once per machine)
idf.py set-target esp32s3

# Build
idf.py build

# Flash and open monitor (replace COM3 with your port)
idf.py -p COM3 flash monitor
```

### Build Only (No Flash)

```bash
idf.py build
```

Use this to verify the code compiles before flashing.

### Monitor Only (No Flash)

```bash
idf.py -p COM3 monitor
```

Use this to see serial output without flashing a new build.

Press `Ctrl+]` to exit the monitor.

### Find Your COM Port

1. Open Device Manager (Win+X → Device Manager)
2. Expand "Ports (COM & LPT)"
3. Look for "Silicon Labs CP210x" or "USB Serial Device" — that is your ESP32
4. Note the COM number (e.g., COM3, COM7)

---

## 8. Expected Serial Output

### First Boot (No Wi-Fi Credentials)

```
I (xxx) main: DingDong booting...
I (xxx) storage: SD card mounted at /sdcard
I (xxx) camera: OV5640 initialized successfully
I (xxx) wifi: No credentials in NVS — starting SoftAP
I (xxx) wifi: SoftAP started: DingDong-Setup (IP: 192.168.4.1)
I (xxx) wifi: HTTP server started (provisioning routes only)
```

At this point, connect your phone to DingDong-Setup and run the app onboarding.

### After Provisioning

```
I (xxx) wifi: Received POST /provision: ssid=MyHomeNetwork
I (xxx) wifi: Connecting to home Wi-Fi...
I (xxx) wifi: Connected! IP: 192.168.1.50
I (xxx) wifi: deviceId: dd001a2b3c4d5e6f
I (xxx) wifi: mDNS started: dingdong-dd001a2b3c4d5e6f.local
I (xxx) wifi: HTTP server restarted (all routes)
I (xxx) wifi: SNTP time synced
```

### Normal Operation

```
I (xxx) sensor: PIR triggered
I (xxx) sensor: mmWave: presence=1, distance=2.1m
I (xxx) sensor: MOTION VALIDATED — posting event
I (xxx) camera: Capturing clip (10s)...
I (xxx) storage: Writing clip: /sdcard/clips/1711234567890.avi
I (xxx) camera: Clip written: 1711234567890
I (xxx) notify: POSTing event to Cloud Function...
I (xxx) notify: Cloud Function responded: 200 OK
```

### Doorbell Press

```
I (xxx) sensor: DOORBELL pressed
I (xxx) sensor: Buzzer beep 100ms
I (xxx) camera: Capturing clip (10s)...
I (xxx) notify: POSTing doorbell event to Cloud Function...
I (xxx) notify: Cloud Function responded: 200 OK
```

### Error States

```
E (xxx) storage: SD card mount failed — retrying in 5s
E (xxx) camera: esp_camera_init() failed: 0x101
E (xxx) notify: Cloud Function error 401 — check HMAC secret
E (xxx) wifi: Wi-Fi disconnected — reconnecting (attempt 1, delay 1s)
```

---

## 9. NVS Key Reference

All persistent data is stored in NVS under the namespace `"dingdong"`.

| Key | Type | What It Stores |
|-----|------|---------------|
| wifi_ssid | string | Home Wi-Fi network name |
| wifi_pass | string | Home Wi-Fi password |
| device_id | string | 16-char hex ID (MAC-based) |
| api_token | string | 64-char hex Bearer token for app auth |
| token_served | uint8 | 1 = token already returned to app once |
| device_secret | string | 64-char hex HMAC signing key |
| secret_provisioned | uint8 | 1 = secret set, reject re-provisioning |
| device_name | string | Human-readable name (e.g., "Front Door") |
| motion_enabled | uint8 | 0 = off, 1 = on |
| notify_enabled | uint8 | 0 = off, 1 = on |
| mmwave_threshold | uint8 | 0-100 sensitivity value |
| clip_length_sec | uint8 | 5, 10, 20, or 30 |

To erase all NVS data (full factory reset without needing the app):
```bash
idf.py -p COM3 erase-flash
```
Then reflash the firmware.

---

## 10. Common Firmware Issues

### "SD card mount failed"

- Check SD card is inserted
- Check SPI GPIO connections match dd_config.h (MOSI/MISO/SCLK/CS)
- Try a different SD card — some brands have compatibility issues with esp_vfs_fat_sdspi_mount
- Verify SD card is formatted as FAT32

### "Camera init failed"

- Check all DVP GPIO connections match dd_config.h
- Verify CAM_PWDN (GPIO 47) against final Altium sheet — this is the most likely mismatch
- Check I2C SDA/SCL connections (GPIO 14/13)
- Check power — camera needs stable 2.8V and 1.8V from LDO regulators

### "Wi-Fi disconnected" in a loop

- Device cannot reconnect to the home Wi-Fi
- Check home router is 2.4GHz — device does not support 5GHz
- Try moving device closer to router
- Check password is correct (factory reset and re-provision if needed)

### "Cloud Function 401" after initial provisioning

- The HMAC secret provisioning step may have failed during onboarding
- In the app: Settings → Remove Device → re-do onboarding
- This regenerates the secret and re-provisions

### PIR fires constantly (false triggers)

- Adjust the PIR sensitivity potentiometer on the HC-SR501 module (small orange dial)
- Turn clockwise to reduce sensitivity
- Increase `DD_PIR_DEBOUNCE_MS` in dd_config.h if needed

### mmWave not detecting

- Verify UART wiring: ESP TX (GPIO 43) → mmWave RX, ESP RX (GPIO 44) → mmWave TX (TX/RX are crossed)
- Verify mmWave module is set to "full output mode" — check DFRobot SEN0395 documentation
- Check baud rate: must be 115200
- Remove any metal objects from the sensing path — metal blocks 24GHz signals
