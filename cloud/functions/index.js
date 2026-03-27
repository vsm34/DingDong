'use strict';
 
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const cors = require('cors')({ origin: true });
const { verifyHmac } = require('./hmac');
const Anthropic = require('@anthropic-ai/sdk');
 
admin.initializeApp();
const db = admin.firestore();
 
// ─── Helper: build AI summary from event data ─────────────────────────────────
function _buildNotifySummaryMessage(type, ts, sensorStats, deviceName) {
  const date = new Date(ts);
  const hours = date.getHours();
  const minutes = date.getMinutes();
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const h = hours % 12 || 12;
  const mm = String(minutes).padStart(2, '0');
  const formattedTime = `${h}:${mm} ${ampm}`;
  const pirTriggered = sensorStats?.pirTriggered ?? false;
  const mmwaveDistance = sensorStats?.mmwaveDistance ?? null;
  const distanceStr = mmwaveDistance != null ? `${mmwaveDistance}m` : 'not available';
  return (
    `Event type: ${type}. ` +
    `Time: ${formattedTime}. ` +
    `PIR triggered: ${pirTriggered}. ` +
    `mmWave distance: ${distanceStr}. ` +
    `Device: ${deviceName}. ` +
    `Generate one summary sentence.`
  );
}
 
const _aiSystemPrompt =
  "You are a smart doorbell assistant. Generate a single short sentence (under 15 words) " +
  "describing a doorbell event. Be specific and natural. Never start with 'I'. " +
  "Examples: 'Someone approached 2.1 meters from your door at 3:14 PM.' or " +
  "'Your doorbell was pressed.' or 'Motion detected near your front door.'";
 
// ─── POST /notify ──────────────────────────────────────────────────────────────
// Called by the ESP32 after every validated motion or doorbell event.
// Verification order (PRD Section 8.4):
//   1. Body schema validation
//   2. Timestamp window (±60 s)
//   3. Nonce uniqueness (5-minute window)
//   4. HMAC-SHA256 signature
//   5. Device registration check
//   6. Write event → generate AI summary → send FCM → return { ok: true }
exports.notify = functions
  .runWith({ secrets: ['ANTHROPIC_API_KEY'] })
  .https.onRequest(async (req, res) => {
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
 
    // ── Step 7: Generate AI summary (non-fatal) ───────────────────────────────────
    const deviceName = deviceDoc.get('displayName') || deviceId;
    let aiSummary = null;
    try {
      const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
      const userMessage = _buildNotifySummaryMessage(type, ts, sensorStats, deviceName);
      const aiResponse = await anthropic.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 60,
        system: _aiSystemPrompt,
        messages: [{ role: 'user', content: userMessage }],
      });
      aiSummary = aiResponse.content[0]?.text?.trim() || null;
      if (aiSummary) {
        await db.collection('events').doc(eventId).update({ aiSummary });
      }
    } catch (_) {
      // Non-fatal — continue without AI summary
    }
 
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
      const body = aiSummary || (type === 'doorbell'
        ? 'Someone rang your doorbell.'
        : 'Motion detected at your door.');
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
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
 
// ─── generateEventSummary ─────────────────────────────────────────────────────
// HTTPS Callable — requires Firebase Auth.
// Generates a one-sentence AI summary of a doorbell event using Claude Haiku.
// Stores the result back to Firestore events/{eventId}.aiSummary for caching.
exports.generateEventSummary = functions
  .runWith({ secrets: ['ANTHROPIC_API_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Request must be authenticated.'
      );
    }
 
    const { eventId, eventType, timestamp, sensorStats, deviceName } = data || {};
 
    if (!eventId || typeof eventId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Missing eventId');
    }
 
    const userMessage = _buildNotifySummaryMessage(
      eventType || 'motion',
      timestamp || Date.now(),
      sensorStats,
      deviceName || 'your device'
    );
 
    try {
      const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
 
      const response = await anthropic.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 60,
        system: _aiSystemPrompt,
        messages: [{ role: 'user', content: userMessage }],
      });
 
      const summary = response.content[0]?.text?.trim() || null;
 
      if (summary) {
        await db.collection('events').doc(eventId).set(
          { aiSummary: summary },
          { merge: true }
        );
      }
 
      return { summary };
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      return { summary: null, error: errorMsg };
    }
  });
 
// ─── aiSupportChat ────────────────────────────────────────────────────────────
// HTTPS onRequest with CORS — requires Firebase Auth (Bearer token).
// Proxies a conversation to Claude and returns the assistant reply.
exports.aiSupportChat = functions
  .runWith({ secrets: ['ANTHROPIC_API_KEY'] })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      // ── Verify Firebase Auth ID token ──────────────────────────────────────────
      const authHeader = req.headers['authorization'] || '';
      const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
      if (!idToken) {
        return res.status(401).json({ error: 'Missing authorization' });
      }
 
      try {
        await admin.auth().verifyIdToken(idToken);
      } catch {
        return res.status(401).json({ error: 'Invalid token' });
      }
 
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }
 
      const { messages } = req.body || {};
 
      if (!Array.isArray(messages) || messages.length === 0) {
        return res.status(400).json({ error: 'Missing messages' });
      }
 
      const systemPrompt =
        "You are a friendly and helpful customer support assistant for DingDong, a smart doorbell product for everyday home users. " +
"Speak in simple, clear, friendly language that any homeowner can understand. Never use technical jargon or developer terms. " +
"Never mention: Firebase, FCM, Firestore, ESP32, SoftAP, Flutter, Riverpod, mDNS, MJPEG, PIR, mmWave, SEN0395, LAN, SDK, or any framework or library name. " +
"Instead say: 'your account' not 'Firebase account', 'setup mode' not 'SoftAP', 'motion sensor' not 'PIR', 'radar sensor' not 'mmWave', " +
"'the app' not 'Flutter app', 'push notifications' not 'FCM', 'home network' not 'LAN', 'live camera feed' not 'MJPEG stream'. " +
"For questions unrelated to DingDong, give a very brief answer then say you are here to help with DingDong questions. " +
"Keep all responses under 100 words. Use plain text only — no asterisks, no bold, no markdown symbols. Write in plain sentences or plain numbered lists.\n\n" +
"About DingDong: DingDong is a privacy-first smart doorbell that stores all video locally on the device — no cloud subscription, no monthly fees, no third-party servers. " +
"Video is stored on a memory card inside the device. It uses two motion sensors that must both agree before sending an alert, which means fewer false alarms. " +
"It runs on standard 5V USB-C power and connects to your home Wi-Fi.\n\n" +
"App features: sign up and sign in with email and password, set up your device through the app using a simple step-by-step wizard, " +
"view a feed of all motion and doorbell events, watch recorded clips over your home Wi-Fi, view a live camera feed when at home, " +
"receive push notifications when motion is detected or doorbell is pressed, " +
"adjust motion sensitivity (Low, Medium, High), turn notifications on or off, set clip recording length (5, 10, 20, or 30 seconds), " +
"set a motion schedule so alerts only fire during certain hours, draw privacy zones on the camera view to block certain areas, " +
"view an activity heatmap showing what hours of the day have the most motion, add family members to share device access, " +
"add multiple devices, access your device remotely from outside your home network, tag and search events, " +
"and get an AI-generated plain-English summary with every motion or doorbell notification.\n\n" +
"Common problems and solutions: " +
"Device shows offline — make sure your phone is connected to the same home Wi-Fi network as the doorbell. " +
"Clips not loading — clips can only be viewed when you are on your home Wi-Fi network. " +
"Not receiving notifications — check that notifications are turned on in Device Settings and that the app has notification permission on your phone. " +
"Device not found during setup — go to your phone Wi-Fi settings and connect to the DingDong setup network first, then return to the app. " +
"Want to reset or remove a device — go to Settings, tap Remove Device, and the device will reset and be ready to set up again.";
 
      try {
        const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
 
        const response = await anthropic.messages.create({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 200,
          system: systemPrompt,
          messages: messages,
        });
 
        const reply = response.content[0]?.text?.trim() || "I couldn't generate a response.";
        return res.json({ reply });
      } catch (err) {
  console.error('Anthropic error:', err.message || err);
  return res.json({ reply: "Sorry, I'm having trouble connecting. Please try again." });
}
    });
  });