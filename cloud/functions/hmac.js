'use strict';

const crypto = require('crypto');

/**
 * Verifies an HMAC-SHA256 signature using a timing-safe comparison.
 *
 * The message is constructed as: timestamp + nonce + body (string concatenation).
 *
 * @param {string} secret    - The device_secret (hex string)
 * @param {string} timestamp - The X-Timestamp header value
 * @param {string} nonce     - The X-Nonce header value
 * @param {string} body      - The raw request body string
 * @param {string} signature - The X-Signature header value (hex string)
 * @returns {boolean} true if the signature is valid, false otherwise
 */
function verifyHmac(secret, timestamp, nonce, body, signature) {
  try {
    const message = timestamp + nonce + body;
    const computed = crypto
      .createHmac('sha256', secret)
      .update(message, 'utf8')
      .digest('hex');

    const computedBuf = Buffer.from(computed, 'hex');
    const signatureBuf = Buffer.from(signature, 'hex');

    if (computedBuf.length !== signatureBuf.length) {
      return false;
    }

    return crypto.timingSafeEqual(computedBuf, signatureBuf);
  } catch {
    return false;
  }
}

module.exports = { verifyHmac };
