/// Authentication routes.
///
/// Handles GitHub OAuth flow:
/// - POST /github/oauth/exchange - Exchange code for session token
/// - GET /me - Get current authenticated user profile

import { Router } from 'express';
import jwt from 'jsonwebtoken';
import { query } from '../db.js';
import { encryptToken } from '../lib/crypto.js';
import { requireAuth } from '../middleware/auth.js';
import { exchangeCodeForToken, fetchGitHubUser } from '../lib/githubClient.js';

export const authRouter = Router();

/// Exchange GitHub OAuth code for a Chomp session token.
///
/// This is the final step of the OAuth flow. The client has already
/// obtained an authorization code from GitHub and sends it here.
/// We exchange it for a GitHub access token, then create/update the
/// user in our database and return a Chomp JWT.
///
/// @route POST /github/oauth/exchange
/// @param {string} code - GitHub OAuth authorization code
/// @returns {Object} Session token and user info
authRouter.post('/github/oauth/exchange', async (req, res) => {
  const { code } = req.body;
  if (!code) return res.status(400).json({ error: 'Missing code' });

  try {
    // Exchange OAuth code for GitHub access token
    const accessToken = await exchangeCodeForToken(code);
    const githubUser = await fetchGitHubUser(accessToken);

    // Create or update user in database
    const existing = await query('select * from users where github_id = $1', [githubUser.id]);
    let userRow;
    if (existing.rows.length > 0) {
      userRow = (
        await query(
          'update users set access_token_encrypted = $1, github_username = $2, avatar_url = $3 where github_id = $4 returning *',
          [encryptToken(accessToken), githubUser.login, githubUser.avatar_url, githubUser.id],
        )
      ).rows[0];
    } else {
      userRow = (
        await query(
          'insert into users (github_id, github_username, access_token_encrypted, avatar_url) values ($1, $2, $3, $4) returning *',
          [githubUser.id, githubUser.login, encryptToken(accessToken), githubUser.avatar_url],
        )
      ).rows[0];
    }

    // Issue Chomp JWT (30 day expiry). The `ver` claim carries the
    // user's token_version so a disconnect is able to revoke every
    // outstanding token immediately.
    const sessionToken = jwt.sign(
      { sub: userRow.id, ver: userRow.token_version ?? 0 },
      process.env.SESSION_JWT_SECRET,
      { expiresIn: '30d' },
    );

    res.json({
      session_token: sessionToken,
      user: {
        id: userRow.id,
        github_id: userRow.github_id,
        github_username: userRow.github_username,
        avatar_url: userRow.avatar_url ?? githubUser.avatar_url,
        created_at: userRow.created_at,
      },
    });
  } catch (err) {
    console.error('OAuth exchange failed', err);
    res.status(500).json({ error: 'GitHub OAuth exchange failed' });
  }
});

/// Server-side sign out.
///
/// "Disconnect GitHub" used to clear only the phone's stored token —
/// the JWT stayed valid server-side for up to 30 days. Bumping this
/// user's token_version invalidates every issued JWT instantly (the
/// middleware's `ver` claim check), and dropping their device tokens
/// stops FCM pushes to signed-out installs.
///
/// @route POST /auth/disconnect
/// @returns {Object} { ok: true }
authRouter.post('/auth/disconnect', requireAuth, async (req, res) => {
  try {
    await Promise.all([
      query('update users set token_version = coalesce(token_version, 0) + 1 where id = $1', [req.userId]),
      query('delete from device_tokens where user_id = $1', [req.userId]),
    ]);
    res.json({ ok: true });
  } catch (err) {
    console.error('Disconnect failed', err);
    res.status(500).json({ error: 'Disconnect failed' });
  }
});

/// Get the current authenticated user's profile.
///
/// Reads straight from the database: the avatar was persisted at
/// sign-in, so /me is one query and never burns GitHub rate limit.
///
/// @route GET /me
/// @returns {Object} User profile
authRouter.get('/me', requireAuth, async (req, res) => {
  try {
    const result = await query('select * from users where id = $1', [req.userId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const userRow = result.rows[0];
    res.json({
      id: userRow.id,
      github_id: Number(userRow.github_id),
      github_username: userRow.github_username,
      avatar_url: userRow.avatar_url,
      created_at: userRow.created_at,
    });
  } catch (err) {
    console.error('GET /me failed', err);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});