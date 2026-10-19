-- Migration 002: JWT revocation.
--
-- Session JWTs are stateless and were previously valid for 30 days
-- no matter what — "Disconnect GitHub" in the app cleared only the
-- client's stored token, leaving the JWT and its embedded session
-- valid until expiry. token_version bumps on disconnect; the auth
-- middleware rejects JWTs whose `ver` claim no longer matches.

alter table users add column if not exists token_version int not null default 0;
