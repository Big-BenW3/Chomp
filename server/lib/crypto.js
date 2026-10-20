/// Encryption utilities for sensitive data.
///
/// Provides AES-256-GCM encryption/decryption for storing GitHub
/// access tokens securely in the database. The raw access token
/// is never stored in plain text.
///
/// Uses a 256-bit key derived from the CRYPTO_SECRET environment
/// variable. The key must be exactly 32 bytes (256 bits) for AES-256.

// AES-256-GCM here because GitHub access tokens are high-value
// credentials: GCM gives confidentiality + integrity (tampering with
// the ciphertext fails the authTag check), and the random 96-bit IV
// means encrypting the same token twice yields different ciphertexts
// (no equal-plaintext leakage across rows).
//
// Storage layout (before base64): iv(12) | authTag(16) | ciphertext.
// The key is SHA-256 of CRYPTO_SECRET — not a memory-hard KDF, but the
// secret is a 32-byte random string, not a password, so offline brute
// force isn't the threat model. Rotating CRYPTO_SECRET invalidates
// every stored token (users must reconnect).

import crypto from 'crypto';

/// Derives a 256-bit encryption key from the environment secret.
///
/// Uses SHA-256 hash of the secret to ensure a consistent 32-byte key.
/// Throws if CRYPTO_SECRET is not set.
function getKey() {
  const secret = process.env.CRYPTO_SECRET;
  if (!secret) throw new Error('CRYPTO_SECRET environment variable is required');
  return crypto.createHash('sha256').update(secret).digest();
}

/// Encrypts a plaintext string.
///
/// Returns a base64-encoded string containing:
/// iv (12 bytes) + authTag (16 bytes) + ciphertext
///
/// @param {string} plaintext - The data to encrypt
/// @returns {string} Base64-encoded encrypted data
export function encryptToken(plaintext) {
  const iv = crypto.randomBytes(12); // 96-bit IV for GCM
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  // Combine iv + authTag + ciphertext and base64 encode
  return Buffer.concat([iv, authTag, ciphertext]).toString('base64');
}

/// Decrypts a base64-encoded encrypted string.
///
/// @param {string} encrypted - Base64-encoded encrypted data
/// @returns {string} Decrypted plaintext
export function decryptToken(encrypted) {
  const data = Buffer.from(encrypted, 'base64');
  const iv = data.subarray(0, 12); // First 12 bytes = IV
  const authTag = data.subarray(12, 28); // Next 16 bytes = auth tag
  const ciphertext = data.subarray(28); // Rest = ciphertext
  
  const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), iv);
  decipher.setAuthTag(authTag);
  return decipher.update(ciphertext).toString('utf8') + decipher.final('utf8');
}