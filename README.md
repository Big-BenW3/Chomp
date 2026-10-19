# Chomp

GitHub analytics, watched by AI, on your phone.

Chomp is a Flutter mobile app that connects to your GitHub account and uses AI (NVIDIA + Groq) to analyze your repositories for security, code quality, documentation, and test coverage. Repos are automatically rescanned hourly, and you get a clean feed of findings and score changes.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.3+, Dart 3.x |
| **State** | Riverpod (StateNotifier + FutureProvider) |
| **Auth** | GitHub OAuth (FlutterWebAuth2) |
| **Backend** | Node.js, Express |
| **Database** | Neon Postgres (serverless PostgreSQL) |
| **AI** | NVIDIA (code quality + security scoring), Groq (docs + tests evaluation) |
| **Push** | Firebase Cloud Messaging |
| **Deployment** | Render (Node server), Flutter (Android/iOS) |

## Project Structure

```
dev_watch/
├── lib/                          # Flutter client
│   ├── core/                     # Theme, env, constants
│   ├── models/                   # Data models (User, Repo, ScanResult, etc.)
│   ├── providers/                # Riverpod state management
│   ├── screens/                  # UI screens
│   │   ├── feed/                 # Activity feed
│   │   ├── home/                 # Main tab shell + repo list
│   │   ├── onboarding/           # Welcome + GitHub connect
│   │   ├── profile/              # Profile, settings, watchlist manager
│   │   ├── repo_detail/          # Repo detail with scan results
│   │   └── splash/               # Cold-start splash
│   ├── services/                 # API client, auth, data fetching
│   ├── utils/                    # Utility helpers
│   └── widgets/                  # Reusable UI components
├── server/                       # Node.js backend
│   ├── lib/                      # Crypto, scan engine, AI clients
│   ├── middleware/               # Auth middleware, rate limiting
│   ├── migrations/               # SQL migrations + runner (`npm run migrate`)
│   └── routes/                   # API route handlers
└── web/                          # Flutter web scaffold
```

## Setup

### Prerequisites

- Flutter SDK 3.3+
- Node.js 18+
- A Neon Postgres database (or any PostgreSQL instance)
- GitHub OAuth App credentials
- NVIDIA API key
- Groq API key
- Firebase project (for push notifications)

### Client Setup (.env)

Create `dev_watch/.env`:

```env
CHOMP_API_BASE_URL=https://your-backend-domain.com
GITHUB_CLIENT_ID=your_github_oauth_client_id
GITHUB_CALLBACK_SCHEME=chomp
```

### Server Setup (.env)

Create `dev_watch/server/.env`:

```env
PORT=3000
NEON_DATABASE_URL=postgres://user:pass@ep-xxx.us-east-2.aws.neon.tech/db

GITHUB_CLIENT_ID=your_github_oauth_client_id
GITHUB_CLIENT_SECRET=your_github_oauth_client_secret

SESSION_JWT_SECRET=a-random-256-bit-jwt-secret
CRYPTO_SECRET=a-random-256-bit-crypto-secret
CRON_SECRET=a-random-cron-secret
GITHUB_WEBHOOK_SECRET=a-random-webhook-secret

CORS_ORIGIN=https://your-web-frontend.com   # optional; native clients unaffected

NVIDIA_API_KEY=your_nvidia_api_key
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_MODEL=meta/llama-3.1-8b-instruct

GROQ_API_KEY=your_groq_api_key
GROQ_BASE_URL=https://api.groq.com/openai/v1
GROQ_MODEL=llama-3.1-8b-instant

FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

All ten variables above are validated at startup (`server/lib/constants.js`); the server refuses to boot if any are missing.

### Running

**Server:**
```bash
cd dev_watch/server
npm install
npm run migrate   # applies server/migrations/*.sql to NEON_DATABASE_URL
npm start
```

**Client (Flutter):**
```bash
cd dev_watch
flutter pub get
flutter run
```

## Features

### Authentication
- GitHub OAuth flow via system browser (FlutterWebAuth2)
- Session tokens (JWT, 30-day expiry) stored in FlutterSecureStorage
- User profile persisted across app restarts via GET /me endpoint
- Disconnect clears session and redirects to welcome screen

### Repository Watching
- **Auto-watched**: Top 3 most recently active repos are watched automatically
- **Manual watchlist**: Add up to 4 additional repos
- Watch/unwatch toggles sync with the backend
- Repos synced from GitHub on app open and pull-to-refresh

### AI Scanning
- Triggered manually per repo from the detail screen, plus hourly auto-scans of watched repos
- Pipeline: GitHub fetch -> NVIDIA (security + code quality) -> Groq (docs + tests)
- Results shown as radial gauges and rating badges, with the Groq reasoning surfaced under the badges
- Scan log streams in real-time via Server-Sent Events (with proxy-safe keepalive)
- Concurrent manual + scheduled scans of the same repo are de-duplicated

### Commit Activity
- Real commit history from GitHub (`GET /repos/:id/commits`), bucketed by day
- Rendered as the brand's activity strip with tooltips per day

### Activity Feed
- Chronological log of scan completions
- GitHub webhooks land commits, pull requests and issues into the feed
- Pull-to-refresh support
- Empty states guide the user when no activity exists

### Notifications
- Firebase Cloud Messaging integration
- Server-enforced preferences: master push switch, new issues, score drops, threshold picker (10/20/30 pts)
- Stale FCM tokens clean themselves up on delivery failure
- Dead tokens on sign-out are removed via the disconnect endpoint

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/github/oauth/exchange` | No | Exchange GitHub OAuth code for session token |
| GET | `/me` | Yes | Get current authenticated user profile (no GitHub call) |
| POST | `/auth/disconnect` | Yes | Revoke session server-side + remove device tokens |
| GET | `/settings` | Yes | Get server-backed notification preferences |
| PUT | `/settings` | Yes | Upsert notification preferences |
| POST | `/github/sync-repos` | Yes | Sync repositories from GitHub |
| GET | `/repos` | Yes | List user's repositories with watch status |
| POST | `/repos/:id/watch` | Yes | Add repo to manual watchlist |
| POST | `/repos/:id/unwatch` | Yes | Remove repo from manual watchlist |
| GET | `/repos/:id/scans` | Yes | Get scan history for a repo |
| GET | `/repos/:id/alerts` | Yes | Get alerts for a repo |
| POST | `/repos/:id/alerts/:alertId/resolve` | Yes | Mark an alert resolved |
| POST | `/repos/:id/alerts/:alertId/unresolve` | Yes | Re-open an alert |
| GET | `/repos/:id/commits` | Yes | Recent commit activity (day buckets) |
| POST | `/scan/:repoId` | Yes | Trigger a manual scan (SSE stream) |
| GET | `/feed` | Yes | Get activity feed |
| POST | `/notifications/register-device` | Yes | Register FCM device token |
| GET | `/health` | No | Health check |
| POST | `/internal/hourly-scan` | No | Cron-triggered scan of all watched repos (secret header) |
| POST | `/github/webhook` | No | GitHub webhook receiver (commits/PRs/issues, HMAC-verified) |

## Database Schema

The schema targets live in `server/schema.sql` (fresh installs) and are applied to running databases via `server/migrations/*.sql` (`npm run migrate` — files are applied once, tracked in `schema_migrations`). Key tables:
- `users` - GitHub-authenticated users with encrypted access tokens + `token_version` for session revocation
- `repos` - Repositories with auto/manual watch flags (unique per user + GitHub repo)
- `scan_results` - Scan outputs with scores, findings, and docs/tests reasoning
- `alerts` - Scan-generated alerts per repo, resolvable by the user
- `user_settings` - Server-enforced notification preferences
- `feed_items` - Activity feed entries
- `device_tokens` - FCM push notification tokens

## Security

- **GitHub access tokens are never stored in plain text** — encrypted with AES-256-GCM
- **The raw GitHub token never reaches the client** — all API calls go through our backend
- **Session tokens are JWT-based** (30-day expiry) with server-side revocation via `token_version` — "Disconnect GitHub" kills every outstanding session immediately
- **Scan history, alerts, and commits are scoped to the caller** — every query joins through `repos.user_id`, so cross-user reads are refused
- **Webhooks are HMAC-SHA256 verified** over the raw body and never crash the process on handler errors
- **Rate limiting** (express-rate-limit): 100 req/15min general, 10 req/15min auth, 20 req/hr scan
- **CORS is allowlist-only** — set `CORS_ORIGIN`; with none configured browser origins are rejected (native mobile clients are unaffected)
- **Startup env validation** — all ten required secrets checked at boot; partial-configuration environments fail fast
- **AI error messages are sanitized** — upstream API response bodies never leak through the SSE stream

## Rate Limiting

Introduced in `server/middleware/rateLimiter.js`:

| Limiter | Window | Max Requests |
|---------|--------|--------------|
| General | 15 minutes | 100 |
| Auth | 15 minutes | 10 |
| Scan | 1 hour | 20 |

These are applied in `server/index.js` and can be tuned per environment.

## Known Issues

1. **Session restore**: If the stored token is expired or revoked, the user is silently signed out and redirected to the welcome screen.
2. **Watchlist limits**: Auto-watched (3) + manual (4) = 7 total max. Both client and server enforce this.
3. **Release signing**: `android/key.properties` (gitignored) must point at your release keystore for Play builds — see the comment in `android/app/build.gradle.kts`. Debug signing is used as fallback.
4. **`repo` OAuth scope**: GitHub's classic OAuth has no read-only scope covering private repositories, so `repo` is required (see comment in `lib/services/auth_service.dart`).

## Future Improvements

- Test coverage (crypto round-trip, alert diffing, SSE parser)
- Structured logging and CI
- GitHub webhook handling for releases/checks
- iOS platform support