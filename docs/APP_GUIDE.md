# DingDong — App Guide

**For:** Vini Silva and Gian Rosario  
**Purpose:** Every screen in the mobile app explained — what it shows, what it connects to in firmware and Firebase, and what files power it.

---

## Table of Contents

1. [App Architecture Overview](#1-app-architecture-overview)
2. [State Management — How Riverpod Works](#2-state-management--how-riverpod-works)
3. [Screen-by-Screen Guide](#3-screen-by-screen-guide)
4. [Key Providers Reference](#4-key-providers-reference)
5. [Design System Reference](#5-design-system-reference)
6. [How the App Handles Being Offline](#6-how-the-app-handles-being-offline)

---

## 1. App Architecture Overview

The app is built in Flutter using a pattern called **Riverpod** for state management. Here is how data flows:

```
Firebase Firestore ──────────────────────────────────→ Events feed, device registry
Firebase Auth ────────────────────────────────────────→ Login state, user identity
Firebase Cloud Messaging (FCM) ────────────────────→ Push notifications
                                                          ↓
                                              App (Flutter + Riverpod)
                                                          ↑
ESP32 device (HTTP over LAN) ────────────────────────→ Device settings, clips, live stream
```

**Key rule:** All video stays on the device. Firestore only stores event metadata (timestamps, types, sensor stats). The app fetches clips and live view directly from the ESP32 over your home Wi-Fi.

### Folder Structure

```
mobile/lib/
├── core/              # Design system (colors, typography, spacing, theme)
├── components/        # Reusable UI components (DDButton, DDCard, etc.)
├── features/          # One folder per feature area
│   ├── auth/          # Login, Signup, Account Settings
│   ├── onboarding/    # 5-step device setup wizard
│   ├── events/        # Events feed, Event detail, Activity heatmap
│   ├── clips/         # Clips list, Clip player
│   ├── live_view/     # MJPEG live stream
│   ├── home/          # Home shell (bottom nav), Settings tab
│   └── settings/      # Device settings, remote access, members, privacy zones
├── models/            # Data classes (DdEvent, DdClip, DdDevice, DeviceSettings)
├── repositories/      # Data sources (DeviceApi, EventsRepo)
├── services/          # AiService (Claude API)
├── navigation/        # GoRouter with all routes and redirect logic
└── providers/         # All Riverpod providers
```

---

## 2. State Management — How Riverpod Works

Riverpod is a state management library. Think of **providers** as smart data sources that:
- Fetch data (from Firebase, from the device, from Hive cache)
- Hold state (is the device online? what events are loaded?)
- Automatically update the UI when data changes

Every screen uses `ref.watch(someProvider)` to read data. When the provider's data changes, the screen automatically rebuilds.

**You do not need to understand Riverpod deeply.** Just know that if something looks wrong in the UI, the provider powering that screen is where to look.

---

## 3. Screen-by-Screen Guide

### Splash Screen (`/splash`)

**File:** `lib/features/splash/screens/splash_screen.dart`

**What it shows:** White screen with the DingDong logo centered. A loading indicator appears below the logo.

**What it does:**
- Checks Firebase Auth state
- If user is signed in: checks if they have a device paired (Firestore `deviceMembers` query)
- If device paired → navigates to home events
- If no device paired and not skipped → navigates to onboarding welcome
- If not signed in → navigates to login

**Firmware connection:** None. This screen only talks to Firebase.

---

### Login Screen (`/login`)

**File:** `lib/features/auth/screens/login_screen.dart`

**What it shows:**
- Full-screen background photo (patio with Edison lights)
- Semi-transparent frosted glass card with:
  - DingDong logo and "Front door intelligence." tagline
  - Email field
  - Password field (with show/hide toggle)
  - Forgot password? link
  - Sign In button
  - "Don't have an account? Sign up" link

**What it does:**
- Validates email format and password minimum length (8 chars) before submitting
- Calls Firebase Auth `signInWithEmailAndPassword()`
- On wrong password: shows red inline error text below the password field — stays on login screen
- On success: auth state listener triggers, router redirects to home or onboarding

**Forgot Password:**
- Tapping opens a bottom sheet with an email field
- Calls Firebase Auth `sendPasswordResetEmail()`
- Shows success toast when email sent

**Firebase:** Firebase Auth for sign-in  
**Firmware connection:** None

---

### Signup Screen (`/signup`)

**File:** `lib/features/auth/screens/signup_screen.dart`

**What it shows:**
- Same full-screen background as login
- Frosted glass card with: display name, email, password, confirm password fields
- Create Account button
- "Already have an account? Sign in" link

**What it does:**
- Manual field validation (no Flutter Form widget — bypassed due to web rendering issue)
- Validation checks in order: name not empty → email valid format → password ≥ 8 chars → passwords match
- Calls Firebase Auth `createUserWithEmailAndPassword()`
- After account created: creates user document in Firestore `users/{uid}`
- Registers FCM token for push notifications
- On success: router redirects to onboarding (new user has no device)

**Firebase:** Firebase Auth for account creation, Firestore for user document  
**Firmware connection:** None

---

### Onboarding — Welcome (`/onboard/welcome`)

**File:** `lib/features/onboarding/screens/welcome_screen.dart`

**What it shows:**
- Top half: hunter green hero block with DingDong logo and name
- Bottom half: white with "Meet DingDong" heading, brief description
- "Get Started" green button
- "Skip for now" text button
- Step dots (5 dots, first one filled)

**What it does:**
- "Get Started" → navigates to Connect AP screen
- "Skip for now" → saves `onboarding_skipped = true` in Hive local storage, goes to home events

**Note:** If user has no device and has not skipped, the router automatically sends them here from any screen. If they skip, they go to home but see empty states with "Add Device" buttons throughout.

---

### Onboarding — Connect AP (`/onboard/connect-ap`)

**File:** `lib/features/onboarding/screens/connect_ap_screen.dart`

**What it shows:**
- Step 2/5 indicator
- Three numbered instruction cards:
  1. Plug in your DingDong device
  2. Wait for the LED to blink blue
  3. Go to Wi-Fi settings → connect to DingDong-Setup
- Collapsible "What do the LED colors mean?" section (red = booting, blinking blue = ready to pair, solid green = connected)
- "I'm Connected" button

**What it does:**
- User must physically connect phone to the DingDong-Setup Wi-Fi hotspot
- Tapping "I'm Connected" navigates to Provisioning screen

**Firmware connection:** This screen is instructions only. The actual communication happens in the next step.

---

### Onboarding — Provisioning (`/onboard/provisioning`)

**File:** `lib/features/onboarding/screens/provisioning_screen.dart`

**What it shows:**
- Step 3/5 indicator
- "Connect to home Wi-Fi" heading
- Wi-Fi network name (SSID) text field
- Password text field (obscured)
- 2.4GHz warning banner (amber): "DingDong only supports 2.4GHz Wi-Fi networks"
- Privacy note: "Your credentials are sent directly to the device and never stored in the cloud"
- "Connect Device" button

**What it does:**
- Sends `POST http://192.168.4.1/provision` with `{ssid, password, deviceName}`
- This is the direct communication to the ESP32 while phone is on DingDong-Setup hotspot
- Navigates to Confirming screen on success

**Firmware connection:** Direct HTTP POST to ESP32 at `192.168.4.1` (provisioning endpoint, no auth needed)

---

### Onboarding — Confirming (`/onboard/confirming`)

**File:** `lib/features/onboarding/screens/confirming_screen.dart`

**What it shows:**
- Step 4/5 indicator
- Lottie animation (connection spinner)
- "Connecting your device..." text
- "This may take up to 30 seconds." subtitle
- If timeout: troubleshooting bottom sheet with 4 steps and "Try Again" button

**What it does:**
- Polls `GET http://192.168.4.1/provision/status` every 2 seconds
- Waiting for `state: "connected"` in the response
- When connected: reads the API token from the response and stores it in `flutter_secure_storage`
- Also reads deviceId and device IP
- Then calls Cloud Function `provisionSecret` to generate the HMAC secret
- Posts the secret back to device via `POST http://192.168.4.1/provision/secret`
- Registers device in Firestore (`devices/{deviceId}` and `deviceMembers/{deviceId}_{uid}`)
- Times out after 60 seconds — shows troubleshooting sheet

**Firmware connection:** Polls ESP32 `/provision/status`, then POSTs to `/provision/secret`  
**Firebase:** Calls Cloud Function `provisionSecret`, writes to Firestore

---

### Onboarding — Success (`/onboard/success`)

**File:** `lib/features/onboarding/screens/success_screen.dart`

**What it shows:**
- Step 5/5 indicator
- Animated green checkmark icon
- "DingDong is Ready!" heading
- Device name text field (pre-filled with "Front Door")
- "Start Monitoring" button

**What it does:**
- User can rename the device
- "Start Monitoring" saves the device name, navigates to home events
- The device is now fully paired and the app will communicate with it via mDNS

---

### Home — Events Tab (`/home/events`)

**File:** `lib/features/events/screens/events_feed_screen.dart`

**What it shows:**
- App bar: DingDong logo, search icon, filter icon, three-dot menu, device name pill (red dot = offline, green dot = online)
- Email verification banner (amber, dismissible) if email not verified
- Events grouped by date: "Today", "Yesterday", specific dates
- Each event row: colored icon (teal for motion, amber for doorbell), event title, timestamp, event type chip, clip available chip
- Empty state: "No events yet" with Add Device button
- Live FAB (floating green button, bottom right): only visible when device is on LAN

**Tap a device name pill:** Opens bottom sheet to switch between multiple devices or add a new device

**Search:** Tap search icon → search bar appears → filters events by type, date, or tag in real time

**Filter:** Tap filter icon → bottom sheet with toggles for Motion only, Doorbell only, Has Clip, Today, This Week, By Tag

**Three-dot menu:** Mark all as read, View Heatmap

**Pull to refresh:** Reloads events from Firestore

**Firebase:** Reads from Firestore `events` collection  
**Firmware connection:** If Firestore unreachable, falls back to GET /events on device  
**Provider:** `eventsProvider`

---

### Event Detail (`/events/:eventId`)

**File:** `lib/features/events/screens/event_detail_screen.dart`

**What it shows:**
- Back button, "Event" title, delete icon (top right)
- Hero banner: amber background for doorbell events, green-gray for motion events
- Event type icon (large), event title, timestamp
- AI summary: sparkle icon + italic green text if auto-generated; "Generate AI Summary" button if not yet generated
- Sensor stats: "Motion sensor activated", "Movement detected 2.1 meters from door" (human-readable)
- Tags: existing tags as chips with X to remove; + chip to add new tags
- Play Clip button (disabled with tooltip when off LAN, shows download progress when loading)
- Left/right arrows for previous/next event navigation

**AI Summary:** Generated automatically when the ESP32 sends the event to the Cloud Function. The Cloud Function calls Claude Haiku to generate one sentence and stores it in Firestore `events/{eventId}.aiSummary`. If missing (for older events), user can tap "Generate AI Summary" to generate on demand.

**Play Clip:** Only available on home network. Downloads full clip from device then plays in better_player.

**Firebase:** Reads/updates Firestore event document  
**Firmware connection:** GET /clips/{clipId} for clip download  
**Provider:** `eventDetailProvider`

---

### Home — Clips Tab (`/home/clips`)

**File:** `lib/features/clips/screens/clips_list_screen.dart`

**What it shows:**
- LAN gate banner (amber) when off home network: "Connect to home Wi-Fi to browse clips"
- Storage warning banner (amber) when SD card over 80% full
- Each clip row: clock icon, timestamp, duration badge, file size
- Long-press → selection mode → checkboxes → bulk delete
- Empty state when no device paired

**What it does:**
- Loads clip list from device via GET /clips
- Only works on home network (LAN gate enforced)
- Tap clip → download progress screen → clip player
- Long-press for bulk operations

**Firmware connection:** GET /clips (list), GET /clips/{id} (download), DELETE /clips/{id}  
**Provider:** `clipsProvider`

---

### Clip Player (`/clips/:clipId`)

**File:** `lib/features/clips/screens/clip_player_screen.dart`

**What it shows:**
- Full-screen video player with custom controls
- Play/pause, seek bar (hunter green), fullscreen toggle
- Back button, delete icon (top right)
- Download icon: saves clip to phone's photo gallery
- Pull-up bottom sheet: clip metadata (timestamp, duration, file size)

**What it does:**
- Plays the downloaded clip using the better_player package
- Download-then-play: full clip downloads first, then playback begins
- Save to gallery saves to Android photo gallery

---

### Home — Live View Tab (`/home/live`)

**File:** `lib/features/live_view/screens/live_view_screen.dart`

**What it shows:**
- When on LAN: full-width MJPEG video frame (4:3 aspect ratio)
  - Red "LIVE" pill badge top-left
  - Connection quality indicator top-right
  - Tap to show overlay with resolution and close button
- When off LAN: camera-off icon, "Live View unavailable", explanation text

**What it does:**
- Checks `lanReachableProvider` before connecting
- Opens MJPEG stream at `http://dingdong-<id>.local/api/v1/stream`
- Renders frames as they arrive (no buffering — truly live)
- Pauses stream when app goes to background (saves bandwidth, device can capture clips)
- Resume when app comes back to foreground

**Firmware connection:** GET /stream (MJPEG multipart stream)  
**Provider:** `lanReachableProvider`

---

### Home — Settings Tab (`/home/settings`)

**File:** `lib/features/home/screens/home_settings_screen.dart`

**What it shows:**
- Account card: avatar (initials), display name, email, "Account Settings" arrow
- Device card: device name, online/offline chip, firmware version, "Last seen X ago", "Device Settings" arrow
- DEVICE section: Add Device, Remove Device (only shown when device paired)
- ACTIVITY section: Activity Heatmap
- SUPPORT section: AI Support
- About, Help, Debug Screen, app version

**Remove Device:** Shows confirmation bottom sheet. On confirm: deletes `deviceMembers/{deviceId}_{uid}` from Firestore, clears Hive skip flag, invalidates providers, navigates to onboarding.

---

### Device Settings (`/settings/device`)

**File:** `lib/features/settings/screens/device_settings_screen.dart`

**What it shows:**
- Back button, "Device Settings" title
- Device status card: device name, online/offline, firmware version, signal strength, last seen
- MOTION section: motion detection toggle, sensitivity slider (Low/Medium/High labels)
- NOTIFICATIONS section: push notifications toggle, test notification button
- CLIPS section: clip length selector (5/10/20/30 seconds)
- SCHEDULE section: motion schedule (enable + start/end time pickers)
- STORAGE section: storage usage, storage manager link
- ADVANCED section: remote access link, privacy zones link, members link, firmware update indicator
- DEVICE section: device rename, signal strength display
- DANGER ZONE: "Forget this device" destructive button

**When offline:** Shows amber banner "Device offline — showing last known settings." All controls visible but saves locally with pending sync.

**Firmware connection:** GET /settings (load), POST /settings (save each change)  
**Firebase:** Notification toggle also writes to Firestore `devices/{id}.notifyEnabled`  
**Provider:** `settingsProvider`

---

### Account Settings (`/settings/account`)

**File:** `lib/features/auth/screens/account_settings_screen.dart`

**What it shows:**
- Back button, "Account" title
- Display name row (tappable, opens edit bottom sheet)
- Email row (read-only)
- Sign Out button (destructive)
- App version caption at bottom

**Firebase:** Firebase Auth for sign out (also removes FCM token from Firestore)

---

### Remote Access (`/settings/remote-access`)

**File:** `lib/features/settings/screens/remote_access_screen.dart`

**What it shows:**
- Enable Remote Access toggle
- Cloudflare Tunnel URL text field (when enabled)
- "Save Tunnel URL" button
- "Test Connection" button
- How It Works explanation

**What it does:**
- When a tunnel URL is saved, all device API calls switch to that URL instead of the mDNS address
- This allows clip browsing and live view from outside home network
- Test Connection calls GET /health on the tunnel URL and shows result

**Setup required by user:** User must create a Cloudflare Tunnel pointing to the device's local IP on port 80. Instructions: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/

---

### Members (`/settings/members`)

**File:** `lib/features/settings/screens/members_screen.dart`

**What it shows:**
- List of current members: name, email, role chip (Owner/Member), remove button
- "Invite Member" button at top

**What it does:**
- Looks up user by email in Firestore `users` collection
- If found: creates `deviceMembers/{deviceId}_{uid}` document
- If not found: shows error toast "No DingDong account found with that email"

**Firebase:** Reads/writes Firestore `deviceMembers` collection

---

### Privacy Zones (`/settings/privacy-zones`)

**File:** `lib/features/settings/screens/privacy_zones_screen.dart`

**What it shows:**
- Dark gray camera frame placeholder (4:3 ratio) labeled "Camera view"
- Existing privacy zones as semi-transparent green rectangles with X to delete
- Drag on the frame to draw new zones
- "Save Zones" button
- "Clear All" destructive button

**What it does:**
- Zones are stored as fractions (0.0 to 1.0) of frame dimensions
- Maximum 4 zones — toast error if user tries to add more
- Zones saved to Firestore and synced to device via POST /settings
- Firmware uses zones to mask motion detection areas

---

### Activity Heatmap (`/events/heatmap`)

**File:** `lib/features/events/screens/activity_heatmap_screen.dart`

**What it shows:**
- Three summary cards: Most Active hour, Total Events, Daily Average
- Date range selector chips: 7 days, 30 days, 90 days
- 24-hour bar chart: one row per hour (12am to 11pm)
  - Bar width = proportional to event count
  - Colors: light green (0 events) → dark green (6+ events)
  - Count number at end of each bar

**Firebase:** Reads from Firestore `events` collection, filters by deviceId and date range  
**Provider:** Built locally from eventsProvider data

---

### AI Support Chat (`/settings/support`)

**File:** `lib/features/settings/screens/support_chat_screen.dart`

**What it shows:**
- "DingDong Support" app bar with back button
- Opening message: "Hi! I'm DingDong Support. Ask me anything..."
- User messages: right-aligned hunter green bubbles
- Assistant messages: left-aligned light gray bubbles with Markdown rendering
- Text input field at bottom with send button
- Conversation limit warning at 20 messages

**What it does:**
- Sends full conversation history to Cloud Function `aiSupportChat`
- Cloud Function proxies to Claude Haiku (claude-haiku-4-5-20251001)
- System prompt gives the AI full DingDong context and instructions to speak plainly without technical jargon
- No conversation history is saved — each session starts fresh

**Note:** Uses ~$0.001-0.002 per message from the $5 Anthropic credit. Use sparingly during testing.

---

### Debug Screen (`/debug`)

**File:** `lib/features/debug/screens/debug_screen.dart`

**What it shows:**
- Auth state (UID, email, verified)
- Device state (deviceId, LAN reachable, last health response)
- Provider states (events count, clips count, settings JSON)
- "Reset Onboarding" button (clears skip flag, forces onboarding on next navigation)
- "Trigger Mock Event" button (tests notification flow without hardware)

**Access:** Go to Settings tab → Debug Screen. This screen is not accessible from production navigation.

---

## 4. Key Providers Reference

These are the most important providers. When something looks wrong in the UI, check the relevant provider.

| Provider | File | What It Does |
|----------|------|-------------|
| `authProvider` | providers.dart | Firebase Auth state — is user signed in? |
| `deviceProvider` | providers.dart | Current active device info (name, ID, status) |
| `lanReachableProvider` | providers.dart | Is the device reachable on local network? |
| `eventsProvider` | providers.dart | List of events from Firestore |
| `clipsProvider` | providers.dart | List of clips from device |
| `settingsProvider` | providers.dart | Device settings (motion, notifications, clip length) |
| `deviceMembershipProvider` | providers.dart | Does user have a paired device? |
| `activeDeviceIdProvider` | providers.dart | Which device is currently selected (multi-device) |
| `tunnelUrlProvider` | providers.dart | Cloudflare Tunnel URL (null = use LAN) |
| `aiServiceProvider` | providers.dart | Claude API service for event summaries |

---

## 5. Design System Reference

The app uses a custom design system called DDTheme. These rules apply everywhere:

**Colors:**
- Hunter green `#355E3B` — primary buttons, active nav, toggles, logo
- Amber `#F59E0B` — logo waves, doorbell events, warnings
- White `#FFFFFF` — primary background
- Soft green-gray `#F4F6F1` — card surfaces, input backgrounds
- **No blue anywhere in the app**

**Typography:** All text uses Inter font (via google_fonts)

**Components:**
- `DDButton.primary` — green filled button
- `DDButton.secondary` — green outlined button
- `DDButton.destructive` — red tinted button for dangerous actions
- `DDCard` — white card with subtle border and shadow
- `DDListTile` — list row with icon, title, subtitle, trailing
- `DDTextField` — styled input with focus states and error states
- `DDChip` — small badge (Motion/Doorbell/Online/Offline)
- `DDBottomSheet` — slide-up modal for actions and confirmations
- `DDToast` — brief success/error feedback that auto-dismisses
- `DDEmptyState` — Lottie animation + title + subtitle + optional CTA

---

## 6. How the App Handles Being Offline

The app has several layers of offline handling:

**No device on LAN:**
- Events feed still works (pulls from Firestore)
- Clips tab shows "Connect to home Wi-Fi" banner
- Live view shows "unavailable" state
- Device settings shows cached last-known settings with "offline" banner

**No internet connection:**
- Events feed falls back to device's `GET /events` endpoint (LAN only)
- Push notifications won't arrive (FCM needs internet)
- Settings and clips still work over LAN

**Device offline (device unplugged/dead):**
- LAN probe fails, `lanReachableProvider` returns false
- Device pill shows red dot + "Offline"
- Clips and live view are inaccessible
- Events feed still works from Firestore
- "Last seen X ago" shows in device card

**New user, no device paired:**
- All device-dependent features show empty states
- "Add Device" button visible throughout app
- Router redirects to onboarding if not skipped
