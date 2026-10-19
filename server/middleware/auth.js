/// JWT Authentication Middleware
///
/// Verifies the session token from the Authorization header.
/// Extracts the user ID from the token and attaches it to the request.
///
/// Usage: Apply to routes that require authentication:
///   router.get('/protected', requireAuth, handler)

import jwt from 'jsonwebtoken';
import { pool } from '../db.js';

/// Middleware that requires a valid session token.
///
/// Expects the token in the Authorization header as:
///   Authorization: Bearer <token>
///
/// On success, attaches `req.userId` to the request.
/// On failure, returns 401 Unauthorized.
export async function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization token' });
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, process.env.SESSION_JWT_SECRET);
    const userId = payload.sub;

    // Revocation check: disconnect bumps the user's token_version, so
    // any token with a stale `ver` was minted before the sign-out and
    // is rejected here. One indexed query in the hot path.
    const { rows } = await pool.query(
      'select token_version from users where id = $1',
      [userId],
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    if ((payload.ver ?? 0) !== (rows[0].token_version ?? 0)) {
      return res.status(401).json({ error: 'Session revoked. Sign in again.' });
    }

    req.userId = userId; // user ID from JWT subject claim
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}