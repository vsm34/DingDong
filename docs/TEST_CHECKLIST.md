# DingDong — Complete Test Checklist

**For:** Vini Silva and Gian Rosario  
**Purpose:** Structured test plan for hardware bring-up, firmware validation, app E2E testing, security testing, and stress testing.

**Ground Rules:**
- Firmware bugs (C++ code): fix directly and commit to a branch
- App/backend bugs: document using the Issue Template at the bottom and notify Varun
- AI feature tests (Sections 7-8): use sparingly — $5 Anthropic credit remaining, ~$0.001-0.002 per message
- Document every test result (pass/fail/notes) as you go

---

## Table of Contents

1. [Phase 1 — Hardware Bring-Up](#phase-1--hardware-bring-up)
2. [Phase 2 — Firmware API Tests](#phase-2--firmware-api-tests)
3. [Phase 3 — Onboarding and Provisioning](#phase-3--onboarding-and-provisioning)
4. [Phase 4 — Core App Features](#phase-4--core-app-features)
5. [Phase 5 — Sensor and Detection Tests](#phase-5--sensor-and-detection-tests)
6. [Phase 6 — Security Tests](#phase-6--security-tests)
7. [Phase 7 — AI Feature Tests](#phase-7--ai-feature-tests)
8. [Phase 8 — Stress Tests](#phase-8--stress-tests)
9. [Phase 9 — Pre-Demo Checklist](#phase-9--pre-demo-checklist)
10. [Issue Report Template](#issue-report-template)

---

## Phase 1 — Hardware Bring-Up

Do these tests before writing any code changes. They confirm the PCB and components are working.

### 1.1 Power System

- [ ] **5V rail:** Connect USB-C power. Measure 5V at USB-C connector with multimeter.
- [ ] **3.3V rail:** Measure 3.3V at TPS54331 output (should be 3.30V ± 0.05V).
- [ ] **Camera 2.8V rail:** Measure at LDO output for camera analog supply.
- [ ] **Camera 1.8V rail:** Measure at LDO output for camera digital supply.
- [ ] **No brownout on Wi-Fi TX:** Connect to serial monitor, watch for brownout reset messages during Wi-Fi connect. Should see none.
- [ ] **Current draw:** Measure total current draw at 5V. Expected: ~0.3A idle, up to ~1.2A during Wi-Fi TX + camera capture.

### 1.2 ESP32-S3 Basic Boot

- [ ] **Serial output:** Flash firmware, open monitor. See "DingDong booting..." within 3 seconds.
- [ ] **SoftAP started:** See "SoftAP started: DingDong-Setup" in serial output.
- [ ] **No crash loops:** Device should not repeatedly restart. If it does, check power supply stability.

### 1.3 microSD Card

- [ ] **Mount succeeds:** See "SD card mounted at /sdcard" in serial output.
- [ ] **Write test:** Trigger a motion event manually (short GPIO 42 to 3.3V briefly). See clip write message.
- [ ] **Read test:** List clips via the API (after provisioning). Should return the clip just written.
- [ ] **SD card failure handling:** Remove SD card and reboot. Device should continue running (degraded mode, no clip storage). Should see "SD card mount failed — retrying" in logs.

### 1.4 Camera (OV5640)

- [ ] **Camera init:** See "Camera ready" in serial output within 5 seconds of boot.
- [ ] **Verify PWDN pin:** If camera init fails, check GPIO 47 (DD_CAM_PWDN_GPIO) against final Altium sheet — this is the most likely pin mismatch.
- [ ] **Live stream works:** After provisioning, navigate to Live View in app. Should see camera output. Adjust camera aim if needed.
- [ ] **Clip capture:** Trigger motion, check that clip appears in Clips tab.

### 1.5 PIR Sensor (HC-SR501)

- [ ] **PIR power:** Confirm PIR module has 5V and GND.
- [ ] **Signal pin:** PIR OUT → GPIO 42. Voltage should be HIGH (~3.3V) when PIR fires.
- [ ] **PIR fires:** Wave hand in front of sensor. See "PIR triggered" in serial output.
- [ ] **PIR sensitivity:** Adjust orange sensitivity potentiometer if triggering too easily or not enough.

### 1.6 mmWave Radar (DFRobot SEN0395)

- [ ] **mmWave power:** Confirm radar module has 5V and GND.
- [ ] **UART wiring:** ESP GPIO 43 (TX) → mmWave RX. ESP GPIO 44 (RX) → mmWave TX. Note: TX/RX are crossed.
- [ ] **UART output:** See `$JYBSS` frames in serial output when motion present. If no frames, check wiring.
- [ ] **Detection range:** Stand at various distances. mmWave should report presence=1 up to ~9m.
- [ ] **No metal obstruction:** Ensure no metal in sensing path. Metal blocks 24GHz signal.
- [ ] **Full output mode:** Confirm SEN0395 is in full output mode (factory default should be correct — check DFRobot wiki if not seeing $JYBSS frames).

### 1.7 Doorbell Button

- [ ] **Button press:** Press doorbell button. See "DOORBELL pressed" in serial output.
- [ ] **Buzzer beep:** Should hear 100ms beep from piezo buzzer when doorbell pressed.
- [ ] **Active LOW:** Button should be pulled HIGH via R6. Pressing grounds GPIO 2.

### 1.8 Buzzer

- [ ] **Buzzer audible:** Triggered on doorbell press. Should produce a clear tone.
- [ ] **Buzzer driven correctly:** Through R5 resistor on GPIO 1. Active HIGH.

---

## Phase 2 — Firmware API Tests

These tests use curl commands to directly test the device HTTP API. Run these from a computer on the same Wi-Fi network as the device (after provisioning).

Replace `<ip>` with your device's IP address and `<token>` with the Bearer token from provisioning.

### 2.1 Unauthorized Access (Before Provisioning — SoftAP Mode)

Test from a computer connected to DingDong-Setup hotspot:

```bash
# POST /provision — should return ok:true
curl -X POST http://192.168.4.1/provision \
  -H "Content-Type: application/json" \
  -d '{"ssid":"TestNet","password":"test1234","deviceName":"Test"}'
# Expected: {"ok":true}
```

### 2.2 Health Endpoint

```bash
# GET /health — must return 200 with device info
curl -H "Authorization: Bearer <token>" \
  http://<ip>/api/v1/health
# Expected: {"ok":true,"deviceId":"...","fwVersion":"1.0.0","time":...,"lastEventTs":...}
```

- [ ] Returns 200 with ok:true
- [ ] deviceId matches what was stored during provisioning
- [ ] fwVersion is "1.0.0"
- [ ] time is a valid Unix timestamp (SNTP synced)

### 2.3 Auth Protection

```bash
# No token — must return 401
curl http://<ip>/api/v1/health
# Expected: {"error":"missing token","code":401}

# Wrong token — must return 401
curl -H "Authorization: Bearer wrongtoken" http://<ip>/api/v1/health
# Expected: {"error":"invalid token","code":401}

# Missing Bearer prefix — must return 401
curl -H "Authorization: <token>" http://<ip>/api/v1/health
# Expected: {"error":"missing token","code":401}
```

- [ ] No token → 401
- [ ] Wrong token → 401
- [ ] Missing Bearer prefix → 401

### 2.4 Rate Limiting

```bash
# Send 6 wrong-token requests — 6th should return 429
for i in {1..6}; do
  curl -H "Authorization: Bearer wrong" http://<ip>/api/v1/health
  echo ""
done
# Expected: first 5 return 401, 6th returns 429
```

- [ ] After 5 failures, 6th returns 429
- [ ] After 60 seconds, valid token is accepted again

### 2.5 Settings

```bash
# GET settings
curl -H "Authorization: Bearer <token>" http://<ip>/api/v1/settings
# Expected: {"motionEnabled":true,"notifyEnabled":true,"mmwaveThreshold":50,"clipLengthSec":10}

# POST settings — change clip length
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  http://<ip>/api/v1/settings \
  -d '{"motionEnabled":true,"notifyEnabled":true,"mmwaveThreshold":50,"clipLengthSec":20}'
# Expected: {"ok":true}

# Verify change
curl -H "Authorization: Bearer <token>" http://<ip>/api/v1/settings
# Expected: clipLengthSec is now 20
```

- [ ] GET /settings returns valid JSON
- [ ] POST /settings accepts valid payload and returns ok:true
- [ ] Settings persist after change

### 2.6 Settings Validation

```bash
# Invalid mmwaveThreshold (out of range)
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  http://<ip>/api/v1/settings \
  -d '{"motionEnabled":true,"notifyEnabled":true,"mmwaveThreshold":999,"clipLengthSec":10}'
# Expected: 400 bad input

# Invalid clipLengthSec (not in allowed list)
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  http://<ip>/api/v1/settings \
  -d '{"motionEnabled":true,"notifyEnabled":true,"mmwaveThreshold":50,"clipLengthSec":15}'
# Expected: 400 bad input
```

- [ ] Out-of-range threshold → 400
- [ ] Invalid clip length → 400

### 2.7 Clips API

```bash
# List clips
curl -H "Authorization: Bearer <token>" http://<ip>/api/v1/clips
# Expected: {"clips":[...]} — may be empty if no events triggered yet

# After triggering a motion event, list clips again — should have 1 entry
# Download a clip (replace <clipId> with actual ID from list)
curl -H "Authorization: Bearer <token>" \
  http://<ip>/api/v1/clips/<clipId> \
  --output test_clip.avi
# Expected: file downloads successfully
ls -la test_clip.avi  # Should be > 0 bytes

# Delete the clip
curl -X DELETE -H "Authorization: Bearer <token>" \
  http://<ip>/api/v1/clips/<clipId>
# Expected: {"ok":true}

# Verify deleted
curl -H "Authorization: Bearer <token>" http://<ip>/api/v1/clips
# Expected: clip no longer in list
```

- [ ] GET /clips returns valid JSON array
- [ ] Clip download produces valid AVI file
- [ ] DELETE /clips/{id} removes the clip
- [ ] Content-Length header present on clip download

### 2.8 HMAC Cloud Function Tests

```bash
# Missing HMAC — should return 401
curl -X POST https://us-central1-dingdong-596c2.cloudfunctions.net/notify \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"test","type":"motion","ts":1234567890,"clipId":null,"sensorStats":null}'
# Expected: {"error":"Missing signature"}

# Expired timestamp — should return 401
curl -X POST https://us-central1-dingdong-596c2.cloudfunctions.net/notify \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: 1000000000000" \
  -H "X-Nonce: abcdef1234567890" \
  -H "X-Signature: invalidsig" \
  -d '{"deviceId":"test","type":"motion","ts":1000000000,"clipId":null,"sensorStats":null}'
# Expected: {"error":"Invalid or expired timestamp"}
```

- [ ] Missing HMAC headers → 401
- [ ] Expired timestamp → 401

---

## Phase 3 — Onboarding and Provisioning

Test the full device setup flow using the Android phone.

- [ ] **Install app on Android phone** (see HANDOVER.md Section 5)
- [ ] **Create new account** in the app with a real email address
- [ ] **Routed to onboarding** after signup (no device paired yet)
- [ ] **Welcome screen** shows correctly: green hero, DingDong logo, "Get Started" and "Skip for now" buttons
- [ ] **Skip works:** Tapping Skip goes to home events with empty state and Add Device button
- [ ] **Reset onboarding:** Settings → Debug Screen → Reset Onboarding → back to home → should route to onboarding again

**Full provisioning test:**
- [ ] Power on ESP32, confirm DingDong-Setup hotspot appears in phone Wi-Fi list
- [ ] Connect phone to DingDong-Setup
- [ ] Open app → Onboarding → tap "I'm Connected"
- [ ] Enter home Wi-Fi SSID and password on provisioning screen
- [ ] Tap "Connect Device" — see connecting animation
- [ ] Device connects and success screen appears
- [ ] Name the device "Front Door" → "Start Monitoring"
- [ ] Verify in Firebase Console: device document created in `devices/`, deviceMembers record created
- [ ] App shows home events with device name pill now showing green online dot

---

## Phase 4 — Core App Features

### 4.1 Authentication

- [ ] **Sign in** with test@dingdong.com / testpass1
- [ ] **Wrong password** shows inline red error — stays on login screen
- [ ] **Session persists** — close app completely, reopen — stays signed in
- [ ] **Sign out** — tap Settings → Sign Out — returns to login screen
- [ ] **New account signup** — create new account, routes to onboarding
- [ ] **Forgot password** — tap "Forgot password?", enter email, check inbox for reset email

### 4.2 Events Feed

- [ ] **Events load** from Firestore when device has events
- [ ] **Date grouping** — "Today", "Yesterday", specific dates
- [ ] **Event type chips** — Motion events show green chip, doorbell shows amber chip
- [ ] **Clip available chip** — events with clips show clip badge
- [ ] **Pull to refresh** — pull down to reload
- [ ] **Search** — tap search icon, type "motion" → filters to motion events only
- [ ] **Filter** — tap filter icon, select "Motion only" → only motion events show
- [ ] **Filter active indicator** — amber dot appears on filter icon when filter active

### 4.3 Event Detail

- [ ] **Opens on tap** from events feed
- [ ] **Correct background** — amber for doorbell, green-gray for motion
- [ ] **Sensor stats** — human-readable ("Motion sensor activated", "Movement detected X.X meters from door")
- [ ] **Play Clip button** — disabled when off LAN, enabled on home network
- [ ] **Previous/Next arrows** — navigate between events
- [ ] **Delete event** — tap delete icon, confirm in bottom sheet, event removed from feed
- [ ] **Tags** — tap + chip, add a tag like "package", it appears as a chip
- [ ] **Remove tag** — tap X on tag chip, tag removed

### 4.4 Clips

- [ ] **LAN gate banner** shows when off home network
- [ ] **Clips list loads** when on home network
- [ ] **Download progress** shows correctly during clip download
- [ ] **Clip plays** after download completes
- [ ] **Delete clip** — swipe left or long-press, confirm, clip removed
- [ ] **Bulk delete** — long-press to enter selection mode, select multiple, delete all

### 4.5 Live View

- [ ] **Shows when on LAN** with real device streaming
- [ ] **"Unavailable" state** shown correctly when off LAN
- [ ] **Live FAB** — green "LIVE" button visible in events feed when on LAN, navigates to live view
- [ ] **Stream pauses** when navigating away (check serial — BIT_STREAMING_ACTIVE clears)
- [ ] **Stream resumes** when returning to live view

### 4.6 Device Settings

- [ ] **Settings load** when device is on LAN
- [ ] **Motion toggle** — toggle off, verify in serial "motion_enabled: 0"
- [ ] **Sensitivity slider** — slide to High, verify mmwaveThreshold = ~90 sent to device
- [ ] **Clip length selector** — change to 30s, verify clipLengthSec = 30 sent to device
- [ ] **Notifications toggle** — toggle off, verify in Firestore device doc notifyEnabled = false
- [ ] **Offline mode** — disconnect device from power, open Device Settings — should show offline banner with last known settings
- [ ] **Device rename** — rename to "Back Door", verify name updates in app bar and settings
- [ ] **Test notification button** — tap "Send test notification", should receive push notification

### 4.7 Push Notifications (Requires Android Device)

- [ ] **Motion notification arrives** when device detects motion (while app is backgrounded)
- [ ] **Notification body** has AI-generated summary (e.g., "Someone approached 2.1 meters from your front door.")
- [ ] **Tap notification** — app opens to Event Detail for that specific event
- [ ] **Doorbell notification** — press doorbell button, phone receives "Doorbell pressed" notification
- [ ] **Notification while app is open** — banner toast appears at top of screen
- [ ] **Notification while phone is locked** — notification appears on lock screen

---

## Phase 5 — Sensor and Detection Tests

### 5.1 Dual Sensor Fusion

- [ ] **Motion only (PIR) — should NOT alert:** Block the camera and walk past slowly (no motion for mmWave to confirm). PIR fires but mmWave doesn't confirm within 2 seconds. Verify: no clip captured, no notification sent.
- [ ] **Radar only — should NOT alert:** Use a fan to move air past PIR (non-thermal). mmWave may see motion but PIR doesn't fire. Verify: no alert.
- [ ] **Both sensors — SHOULD alert:** Walk toward camera within 5 meters. Both PIR and mmWave agree. Verify: clip captured, notification sent within ~3 seconds.
- [ ] **Distance threshold:** Walk at exactly 5m from device. Should trigger. Walk at 6m. Should not trigger. Adjust `DD_MMWAVE_MAX_DISTANCE_M` in dd_config.h if threshold is wrong.
- [ ] **Confirmation window:** Trigger PIR, wait 3 seconds, then walk in front of mmWave. Should NOT trigger (PIR already timed out). Walk quickly so both trigger within 2 seconds — SHOULD trigger.

### 5.2 False Alert Suppression

- [ ] **Cars on street:** Place device facing the street. Cars passing should NOT trigger alerts.
- [ ] **Pets:** Animal walking past should ideally not trigger (PIR detects heat, but if it does trigger, mmWave won't confirm at correct distance range).
- [ ] **Shadows/lights:** Headlights sweeping across PIR should not trigger (no thermal source).
- [ ] **Wind-blown vegetation:** Should not trigger mmWave (no human presence signature).

### 5.3 Doorbell

- [ ] **Single press:** One notification, one event, one beep.
- [ ] **Rapid pressing:** Should not flood with notifications. Check debounce in sensor_task.
- [ ] **Doorbell clip:** If motion is also active, doorbell and motion should be separate events.

### 5.4 PIR Debounce

- [ ] **Trigger PIR, immediately trigger again:** Second trigger within 500ms should be ignored. Only one event should fire.

---

## Phase 6 — Security Tests

### 6.1 Git History Audit (Run Before Demo)

```bash
# Run all three — all should return NO OUTPUT
git log --all -- "*/google-services.json"
git log --all -- ".env"
git log --all -- "serviceAccount*"

# Scan for potential secrets
git log --all -p | grep -i "secret\|password\|token\|key" | grep -v "// \|# \|* "
# Review any matches — most will be legitimate variable names
```

- [ ] google-services.json never committed
- [ ] .env never committed
- [ ] serviceAccount files never committed
- [ ] No raw secret values in any committed file

### 6.2 Device API Security

- [ ] **Unauthorized access:** `curl http://<ip>/api/v1/clips` → must return 401
- [ ] **Wrong token:** `curl -H "Authorization: Bearer badtoken" http://<ip>/api/v1/clips` → must return 401
- [ ] **Rate limiting:** 6 wrong attempts → 6th returns 429 (see Phase 2.4)

### 6.3 Cloud Function Security

- [ ] **No HMAC → 401** (see Phase 2.8)
- [ ] **Expired timestamp → 401** (see Phase 2.8)
- [ ] **Replayed nonce:** Send the exact same valid request twice (same nonce). Second should return 401.
- [ ] **Tampered body:** Send valid HMAC but modify the body after signing. Should return 401.

### 6.4 Firestore Rules

- [ ] **User can read own events:** Sign in as test account, events load correctly.
- [ ] **User cannot read other user's events:** Would need two accounts — verify in Firebase Console that rules are in production mode.
- [ ] **Client cannot write events:** In browser console, try `firebase.firestore().collection('events').add({})` — should fail with permission denied.

---

## Phase 7 — AI Feature Tests

**Budget reminder:** ~$0.001-0.002 per message. With $5 remaining, limit to ~20-30 AI-related tests.

### 7.1 AI Event Summary (Auto-Generated)

- [ ] **Trigger a motion event** (real hardware)
- [ ] **Check push notification body** — should be a natural language summary, not "Motion detected at your door"
- [ ] **Open Event Detail** — should show the AI summary with sparkle icon
- [ ] **AI summary quality** — should mention distance and time (e.g., "Someone approached 2.1 meters from your door at 3:14 PM.")
- [ ] **Check Firebase Console** — event document should have `aiSummary` field populated

### 7.2 Generate AI Summary (Manual Button)

- [ ] **Find an old event without aiSummary**
- [ ] **Tap "Generate AI Summary"** — button shows spinner
- [ ] **Summary appears** in hunter green italic text
- [ ] **Summary is accurate** to the event type and time

### 7.3 AI Support Chat (Use Sparingly — 5 Tests Max)

- [ ] **Basic question:** "How do I set up my device?" — should get clear step-by-step answer
- [ ] **Technical question:** "Why am I not getting notifications?" — should troubleshoot FCM issues in plain language
- [ ] **Feature question:** "What is the activity heatmap?" — should explain correctly
- [ ] **Off-topic question:** "What is the capital of France?" — should briefly answer and redirect to DingDong
- [ ] **No technical jargon:** Verify responses never say Firebase, FCM, ESP32, Flutter, SoftAP, etc.

---

## Phase 8 — Stress Tests

### 8.1 Rapid Motion Events

- [ ] **Trigger 5 motion events in 60 seconds** (wave in front of sensors repeatedly)
- [ ] **Verify all 5 notifications arrive** on the phone
- [ ] **Verify all 5 events appear** in the events feed
- [ ] **Verify all 5 clips captured** on SD card
- [ ] **Device remains stable** — no crashes, no lost events

### 8.2 Continuous Operation

- [ ] **Run device for 2 hours** with occasional motion triggers
- [ ] **No memory leaks or crashes** — check serial output periodically
- [ ] **Wi-Fi stays connected** — if it drops, verify reconnect happens automatically
- [ ] **SD card continues writing** — clips still captured after 2 hours

### 8.3 Wi-Fi Disconnect Recovery

- [ ] **Turn off home router for 30 seconds**
- [ ] **Turn router back on**
- [ ] **Device reconnects** — see reconnect messages in serial
- [ ] **Next motion event sends notification** — full pipeline works after reconnect

### 8.4 SD Card Full (Simulated)

- [ ] Fill SD card to near capacity (or set a very small clip limit in firmware)
- [ ] **Storage warning** appears in app (above 80% of 4GB)
- [ ] **Clips still deletable** — user can delete old clips
- [ ] **Device handles full SD gracefully** — no crash, error logged

### 8.5 Multiple App Instances

- [ ] **Open app on two devices** (main phone + another Android)
- [ ] **Trigger motion event** — both devices should receive notification
- [ ] **Both see same events** in Firestore-based feed

### 8.6 App Stress Test

- [ ] **Navigate all screens rapidly** — no crashes
- [ ] **Open and close live view 5 times** — stream connects and disconnects cleanly each time
- [ ] **Download 5 clips in sequence** — all download successfully
- [ ] **Sign out and sign back in** — session restores correctly

---

## Phase 9 — Pre-Demo Checklist

Run these checks the day before the demo.

### Hardware

- [ ] Device powers on cleanly from cold boot
- [ ] All sensors working (PIR, mmWave, doorbell button, buzzer)
- [ ] Camera produces clear video
- [ ] SD card mounted and has adequate free space
- [ ] Device connected to demo Wi-Fi network
- [ ] mDNS resolving: `ping dingdong-<id>.local` returns IP address

### App

- [ ] App installed on demo Android phone
- [ ] Signed in with demo account
- [ ] Device shows green Online dot
- [ ] Events feed loads (or shows clean empty state)
- [ ] Live view works over demo Wi-Fi
- [ ] Demo script prepared (which features to show, in what order)

### Backend

- [ ] Firebase Console: all Cloud Functions showing as active
- [ ] Firestore: demo device document exists
- [ ] Run security audit (Section 6.1) — all clean

### Demo Account Setup

- [ ] Create a fresh account with a real email (not test@dingdong.com) for demo day
- [ ] Go through full onboarding once with the fresh account
- [ ] Verify email if prompted
- [ ] Make sure notifications are enabled in Android settings for the DingDong app

### Demo Flow (Suggested 3-Minute Demo)

1. Show the app: Sign in → Events feed (clean empty state or existing events)
2. Trigger doorbell button → show notification arriving, tap to open Event Detail with AI summary
3. Walk in front of device → show motion notification, event feed updates
4. Navigate to Live View → show real-time camera feed
5. Tap a clip → show download and playback
6. Show Device Settings → sensitivity slider, motion schedule
7. Show Activity Heatmap → motion pattern visualization
8. Show AI Support Chat → ask one question to demonstrate

---

## Issue Report Template

When you find an issue in the app or backend (not firmware), document it like this and send to Varun:

```
## Issue: [Short descriptive title]

Date: [Date found]
Tester: [Your name]
Severity: Critical / High / Medium / Low

**Where:** [Screen name, e.g., "Event Detail" or "Cloud Function notify"]
**When:** [Exact steps to reproduce]
  1. Step one
  2. Step two
  3. Issue occurs

**What happens:** [Describe what you see]

**What should happen:** [Describe correct behavior per this documentation]

**Screenshot/Video:** [Attach if possible]

**Serial log (if relevant):** [Paste relevant serial output]

**Suspected cause:** [Your best guess, if any]
```

Send to Varun via WhatsApp or create a GitHub Issue at:
https://github.com/vsm34/DingDong/issues

---

## Test Results Log

Use this section to track results as you go.

| Test | Date | Result | Notes |
|------|------|--------|-------|
| 1.1 Power — 5V rail | | | |
| 1.1 Power — 3.3V rail | | | |
| 1.2 ESP32 boot | | | |
| 1.3 SD card mount | | | |
| 1.4 Camera init | | | |
| 1.5 PIR fires | | | |
| 1.6 mmWave UART frames | | | |
| 1.7 Doorbell press | | | |
| 1.8 Buzzer | | | |
| 2.2 GET /health | | | |
| 2.3 Unauthorized access | | | |
| 2.4 Rate limiting | | | |
| 2.5 GET/POST /settings | | | |
| 2.7 Clips API | | | |
| 2.8 HMAC Cloud Function | | | |
| 3.0 Full provisioning | | | |
| 4.1 Authentication | | | |
| 4.2 Events feed | | | |
| 4.5 Live view | | | |
| 4.7 Push notifications | | | |
| 5.1 Dual sensor fusion | | | |
| 5.2 False alert suppression | | | |
| 6.1 Git audit | | | |
| 6.2 Device API security | | | |
| 6.3 Cloud Function security | | | |
| 7.1 AI notification summary | | | |
| 8.1 Rapid motion events | | | |
| 8.2 Continuous operation | | | |
| 8.3 Wi-Fi recovery | | | |
