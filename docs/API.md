# DingDong Device API Contract

> Full context and security requirements are in `PRD.md` Sections 7 and 9.
> This file is a quick reference for the device HTTP API.

---

## Base URL

```
http://dingdong-<deviceId>.local/api/v1
```

Resolved via mDNS. Falls back to raw IP stored during provisioning.
`DeviceApiClient` takes a configurable `baseUrl` — Cloudflare Tunnel is a base URL swap only.

---

## SoftAP Endpoints (Public — No Token)

Base: `http://192.168.4.1` (SoftAP mode only)

| Method | Path | Request Body | Response |
|---|---|---|---|
| POST | `/provision` | `{ ssid, password, deviceName }` | `{ ok: true }` |
| GET | `/provision/status` | — | `{ state, ip?, deviceId?, token? }` |
| POST | `/provision/secret` | `{ secret: "64-char-hex" }` | `{ ok: true }` |
| DELETE | `/provision` | — | Clears NVS, reboots to SoftAP |

**Token:** Returned once only when `state = "connected"`. Stored by app in `flutter_secure_storage`.
**Secret:** Called once during onboarding. Rejected on repeat calls.
**DELETE /provision:** Called when user forgets device. Clears all NVS, reboots to SoftAP.

---

## Protected Endpoints (Bearer Token Required)

Header: `Authorization: Bearer <device_api_token>`

| Method | Path | Description | Response |
|---|---|---|---|
| GET | `/health` | Device status | `{ ok, deviceId, fwVersion, time, lastEventTs }` |
| GET | `/events?since=<ts>` | Event list (LAN fallback) | `{ events: Event[] }` |
| GET | `/clips` | List clips on SD | `{ clips: [{ clipId, ts, durationSec, sizeBytes }] }` |
| GET | `/clips/{clipId}` | Download clip | Binary video/avi + Content-Length |
| DELETE | `/clips/{clipId}` | Delete clip | `{ ok: true }` |
| GET | `/settings` | Get settings | `{ motionEnabled, notifyEnabled, mmwaveThreshold, clipLengthSec }` |
| POST | `/settings` | Update settings | `{ ok: true }` |
| GET | `/stream` | MJPEG live stream | multipart/x-mixed-replace stream |

---

## CORS Headers (All Responses)

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
```
OPTIONS preflight returns 200 for all URI patterns.

---

## Error Codes

| Code | Meaning |
|---|---|
| 400 | Bad input — invalid JSON, missing fields, out-of-range values |
| 401 | Missing or invalid Bearer token |
| 403 | Forbidden |
| 429 | Rate limited — 5 failed auth attempts, resets after 60s |
| 503 | Device state unavailable |

Error format: `{ "error": "string", "code": number }`

---

## POST /settings Body

```json
{
  "motionEnabled": boolean,
  "notifyEnabled": boolean,
  "mmwaveThreshold": integer (0–100),
  "clipLengthSec": integer (5 | 10 | 20 | 30)
}
```

---

## MJPEG Stream

`GET /stream` — multipart response, one stream client max (second gets 503).
Stream pauses during clip capture. App closes stream on background.

---

## Clip Download

`GET /clips/{clipId}` streams in 4KB chunks with `Content-Length` header.
App downloads full clip then plays via `better_player`.
