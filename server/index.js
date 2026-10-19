/// Chomp Server - Main Entry Point
///
/// Express server that provides the backend API for the Chomp app.
/// Handles:
/// - GitHub OAuth authentication
/// - Repository synchronization
/// - Manual scan triggers via SSE
/// - Feed and alerts retrieval
/// - FCM device token registration
/// - Internal cron endpoint for hourly scans
///
/// Requires Node 18+ (uses global fetch).

import express from 'express';
import cors from 'cors';
import 'dotenv/config';
import { authRouter } from './routes/auth.js';
import { reposRouter } from './routes/repos.js';
import { scanRouter } from './routes/scan.js';
import { feedRouter } from './routes/feed.js';
import { notificationsRouter } from './routes/notifications.js';
import { settingsRouter } from './routes/settings.js';
import { internalCronRouter } from './routes/internalCron.js';
import { webhookRouter } from './routes/webhooks.js';
import { generalLimiter, authLimiter, scanLimiter } from './middleware/rateLimiter.js';
import { assertRequiredSecrets } from './lib/constants.js';

// Fail fast if required secrets/env are missing so misconfiguration is
// obvious instead of surfacing as undefined-comparison auth bypasses.
assertRequiredSecrets();

const app = express();

// Trust the proxy in front of the server (Render, Nginx, etc.) so rate
// limiting keys off the real client IP rather than the proxy's.
app.set('trust proxy', 1);

// CORS. Native mobile clients are unaffected (no Origin header). In
// production, origins must be explicitly allowed via CORS_ORIGIN
// (comma-separated); with none configured, browser requests are rejected,
// which is the safe default (no reflected-origin-with-credentials hole).
const corsOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((s) => s.trim()).filter(Boolean)
  : [];
app.use(cors({ origin: corsOrigins.length > 0 ? corsOrigins : false, credentials: true }));

// Parse JSON request bodies (limit to bound memory usage).
app.use(express.json({ limit: '1mb' }));

// Apply general rate limiting to all routes
app.use(generalLimiter);

// Stricter rate limiting for auth and scan endpoints
app.use('/github/oauth/exchange', authLimiter);
app.use('/scan', scanLimiter);

// Mount route handlers
app.use(authRouter);
app.use(reposRouter);
app.use(scanRouter);
app.use(feedRouter);
app.use(notificationsRouter);
app.use(settingsRouter);
app.use(internalCronRouter);
// Webhook needs the RAW body to verify GitHub's HMAC signature, so the
// raw parser must run for this path (it overwrites the JSON parse above).
app.use('/github/webhook', express.raw({ type: 'application/json' }));
app.use(webhookRouter);

// Health check endpoint
app.get('/health', (req, res) => res.json({ ok: true }));

// Start server
const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Chomp server listening on :${port}`));