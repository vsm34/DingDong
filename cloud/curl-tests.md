# Cloud Function — curl Test Cases

Replace `BASE_URL` with your deployed function URL, e.g.:
`https://us-central1-dingdong-596c2.cloudfunctions.net`

> **All tests target POST /notify unless otherwise noted.**
> Generate a real HMAC for valid tests using the script at the bottom.

---

## Helper: Generate a valid HMAC signature (bash)

```bash
DEVICE_SECRET="your_device_secret_64_char_hex"
TIMESTAMP=$(date +%s%3N)           # unix milliseconds
NONCE=$(openssl rand -hex 8)       # 16-char hex nonce
BODY='{"deviceId":"dev-001","type":"motion","ts":1711000000000,"clipId":"clip-abc","sensorStats":{"pirTriggered":true,"mmwaveDistance":1.5}}'
MESSAGE="${TIMESTAMP}${NONCE}${BODY}"
SIGNATURE=$(printf '%s' "$MESSAGE" | openssl dgst -sha256 -hmac "$DEVICE_SECRET" | awk '{print $2}')

echo "TIMESTAMP: $TIMESTAMP"
echo "NONCE:     $NONCE"
echo "SIGNATURE: $SIGNATURE"
```

---

## Test 1 — Valid request with correct HMAC

**Expected: 200 `{ "ok": true }`**

```bash
curl -s -X POST "$BASE_URL/notify" \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIGNATURE" \
  -d '{"deviceId":"dev-001","type":"motion","ts":1711000000000,"clipId":"clip-abc","sensorStats":{"pirTriggered":true,"mmwaveDistance":1.5}}'
```

**Expected response (200):**
```json
{ "ok": true }
```

---

## Test 2 — Missing X-Signature header

**Expected: 401 `{ "error": "Missing signature" }`**

```bash
TIMESTAMP=$(date +%s%3N)
NONCE=$(openssl rand -hex 8)

curl -s -X POST "$BASE_URL/notify" \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Nonce: $NONCE" \
  -d '{"deviceId":"dev-001","type":"motion","ts":1711000000000,"clipId":"clip-abc","sensorStats":null}'
```

**Expected response (401):**
```json
{ "error": "Missing signature" }
```

---

## Test 3 — Invalid signature (wrong HMAC value)

**Expected: 401 `{ "error": "Invalid signature" }`**

```bash
TIMESTAMP=$(date +%s%3N)
NONCE=$(openssl rand -hex 8)

curl -s -X POST "$BASE_URL/notify" \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: 0000000000000000000000000000000000000000000000000000000000000000" \
  -d '{"deviceId":"dev-001","type":"motion","ts":1711000000000,"clipId":null,"sensorStats":null}'
```

**Expected response (401):**
```json
{ "error": "Invalid signature" }
```

---

## Test 4 — Expired X-Timestamp (far in the past)

**Expected: 401 `{ "error": "Invalid or expired timestamp" }`**

```bash
NONCE=$(openssl rand -hex 8)

curl -s -X POST "$BASE_URL/notify" \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: 999999" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: 0000000000000000000000000000000000000000000000000000000000000000" \
  -d '{"deviceId":"dev-001","type":"motion","ts":1711000000000,"clipId":null,"sensorStats":null}'
```

**Expected response (401):**
```json
{ "error": "Invalid or expired timestamp" }
```

---

## Test 5 — Replayed nonce (send the same request twice)

Send the exact same request twice in succession. The first call should succeed (200).
The second call must be rejected because the nonce is now recorded in Firestore.

**Expected on second call: 401 `{ "error": "Replayed nonce" }`**

```bash
TIMESTAMP=$(date +%s%3N)
NONCE=$(openssl rand -hex 8)
BODY='{"deviceId":"dev-001","type":"doorbell","ts":1711000000000,"clipId":null,"sensorStats":null}'
MESSAGE="${TIMESTAMP}${NONCE}${BODY}"
SIGNATURE=$(printf '%s' "$MESSAGE" | openssl dgst -sha256 -hmac "$DEVICE_SECRET" | awk '{print $2}')

# First call — succeeds
curl -s -X POST "$BASE_URL/notify" \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"

echo "--- second call (same nonce) ---"

# Second call — same nonce → rejected
curl -s -X POST "$BASE_URL/notify" \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"
```

**Expected response on second call (401):**
```json
{ "error": "Replayed nonce" }
```

---

## Test 6 — Unknown deviceId

**Expected: 401 `{ "error": "Unknown device" }`**

The nonce is consumed before this check, so use a fresh nonce each run.

```bash
TIMESTAMP=$(date +%s%3N)
NONCE=$(openssl rand -hex 8)
BODY='{"deviceId":"nonexistent-device","type":"motion","ts":1711000000000,"clipId":null,"sensorStats":null}'
MESSAGE="${TIMESTAMP}${NONCE}${BODY}"
# Sign with any secret — validation fails at device-not-found step after signature check
SIGNATURE=$(printf '%s' "$MESSAGE" | openssl dgst -sha256 -hmac "$DEVICE_SECRET" | awk '{print $2}')

curl -s -X POST "$BASE_URL/notify" \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"
```

**Expected response (401):**
```json
{ "error": "Unknown device" }
```

---

## Summary Table

| Test | Condition | Expected Code | Expected Body |
|------|-----------|---------------|---------------|
| 1 | Valid request + correct HMAC | 200 | `{ "ok": true }` |
| 2 | Missing X-Signature header | 401 | `{ "error": "Missing signature" }` |
| 3 | Wrong HMAC value | 401 | `{ "error": "Invalid signature" }` |
| 4 | Expired X-Timestamp (999999 ms) | 401 | `{ "error": "Invalid or expired timestamp" }` |
| 5 | Replayed nonce (2nd request) | 401 | `{ "error": "Replayed nonce" }` |
| 6 | Unknown deviceId | 401 | `{ "error": "Unknown device" }` |
