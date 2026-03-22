'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { verifyHmac } = require('./hmac');

admin.initializeApp();
const db = admin.firestore();

// ─── POST /notify ──────────────────────────────────────────────────────────────
// Called by the ESP32 after every validated motion or doorbell event.
// Verification order (PRD Section 8.4):
//   1. Body schema validation
//   2. Timestamp window (±60 s)
//   3. Nonce uniqueness (5-minute window)
//   4. HMAC-SHA256 signature
//   5. Device registration check
//   6. Write event → send FCM → return { ok: true }
exports.notify = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // ── Step 1: Validate body schema ────────────────────────────────────────────
  const { deviceId, type, ts, clipId, sensorStats } = req.body || {};

  const bodyInvalid =
    typeof deviceId !== 'string' || deviceId === '' ||
    (type !== 'motion' && type !== 'doorbell') ||
    typeof ts !== 'number' ||
    (clipId !== null && typeof clipId !== 'string') ||
    (sensorStats !== null && typeof sensorStats !== 'object');

  if (bodyInvalid) {
    return res.status(400).json({ error: 'Invalid request body' });
  }

  // ── Step 2: Timestamp window ─────────────────────────────────────────────────
  const xTimestamp = req.headers['x-timestamp'];
  if (!xTimestamp || Math.abs(Date.now() - parseInt(xTimestamp, 10)) > 60000) {
    return res.status(401).json({ error: 'Invalid or expired timestamp' });
  }

  // ── Step 3: Nonce uniqueness ─────────────────────────────────────────────────
  const xNonce = req.headers['x-nonce'];
  if (!xNonce) {
    return res.status(401).json({ error: 'Missing nonce' });
  }

  const nonceRef = db.collection('nonces').doc(xNonce);
  const nonceDoc = await nonceRef.get();
  if (nonceDoc.exists) {
    return res.status(401).json({ error: 'Replayed nonce' });
  }

  await nonceRef.set({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 5 * 60 * 1000),
  });

  // ── Step 4: HMAC-SHA256 signature ────────────────────────────────────────────
  const xSignature = req.headers['x-signature'];
  if (!xSignature) {
    return res.status(401).json({ error: 'Missing signature' });
  }

  const deviceRef = db.collection('devices').doc(deviceId);
  const deviceDoc = await deviceRef.get();

  // ── Step 5: Device registration check ───────────────────────────────────────
  if (!deviceDoc.exists) {
    return res.status(401).json({ error: 'Unknown device' });
  }

  const deviceSecret = deviceDoc.get('secret');
  const rawBody = req.rawBody ? req.rawBody.toString() : JSON.stringify(req.body);

  if (!verifyHmac(deviceSecret, xTimestamp, xNonce, rawBody, xSignature)) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  // ── Step 6: Write event document ─────────────────────────────────────────────
  const eventId = crypto.randomUUID();
  await db.collection('events').doc(eventId).set({
    deviceId,
    ts: admin.firestore.Timestamp.fromMillis(ts),
    type,
    clipId: clipId !== undefined ? clipId : null,
    sensorStats: sensorStats !== undefined ? sensorStats : null,
  });

  // ── Fetch FCM tokens for all device members ───────────────────────────────────
  const membersSnap = await db
    .collection('deviceMembers')
    .where('deviceId', '==', deviceId)
    .get();

  const tokenArrays = await Promise.all(
    membersSnap.docs.map(async (memberDoc) => {
      const uid = memberDoc.get('uid');
      const userDoc = await db.collection('users').doc(uid).get();
      return userDoc.exists ? (userDoc.get('fcmTokens') || []) : [];
    })
  );

  const tokens = tokenArrays.flat().filter((t) => typeof t === 'string' && t.length > 0);

  // ── Send FCM multicast ────────────────────────────────────────────────────────
  if (tokens.length > 0) {
    const title = type === 'doorbell' ? 'Doorbell pressed' : 'Motion detected';
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title },
      data: {
        eventId,
        deviceId,
        type,
        ts: String(ts),
      },
    });
  }

  return res.json({ ok: true });
});

// ─── POST /testNotify ─────────────────────────────────────────────────────────
// Called by the mobile app to send a test push notification to the current user.
// Requires a valid Firebase Auth ID token and a deviceId.
exports.testNotify = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // ── Verify Firebase Auth ID token ─────────────────────────────────────────────
  const authHeader = req.headers['authorization'] || '';
  const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!idToken) {
    return res.status(401).json({ error: 'Missing authorization' });
  }

  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }

  const { deviceId } = req.body || {};
  if (!deviceId || typeof deviceId !== 'string') {
    return res.status(400).json({ error: 'Missing deviceId' });
  }

  // ── Get user FCM tokens ───────────────────────────────────────────────────────
  const userDoc = await db.collection('users').doc(decodedToken.uid).get();
  const tokens = userDoc.exists ? (userDoc.get('fcmTokens') || []) : [];

  if (tokens.length === 0) {
    return res.status(200).json({ ok: true, sent: 0 });
  }

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title: 'Test Notification', body: 'DingDong is working!' },
    data: { deviceId, type: 'test' },
  });

  return res.json({ ok: true, sent: tokens.length });
});

// ─── POST /provisionSecret ────────────────────────────────────────────────────
// Called by the mobile app during device onboarding (PRD Section 4.2 Step 6).
// Generates a fresh 32-byte HMAC signing secret and stores it on the device doc.
exports.provisionSecret = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // ── Verify Firebase Auth ID token ─────────────────────────────────────────────
  const authHeader = req.headers['authorization'] || '';
  const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!idToken) {
    return res.status(401).json({ error: 'Missing authorization' });
  }

  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }

  // ── Validate body ─────────────────────────────────────────────────────────────
  const { deviceId } = req.body || {};
  if (!deviceId || typeof deviceId !== 'string') {
    return res.status(400).json({ error: 'Invalid deviceId' });
  }

  // ── Verify caller owns the device ─────────────────────────────────────────────
  const deviceDoc = await db.collection('devices').doc(deviceId).get();
  if (!deviceDoc.exists || deviceDoc.get('ownerId') !== decodedToken.uid) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  // ── Generate and store secret ─────────────────────────────────────────────────
  const secret = crypto.randomBytes(32).toString('hex');
  await db.collection('devices').doc(deviceId).set({ secret }, { merge: true });

  return res.json({ secret });
});
