-- Migration 001: Production foundations.
--
-- 1. Tenancy fix: repos were unique on github_repo_id GLOBALLY, so if two
--    users shared the same repository (org repos, collaborator repos),
--    the second user's silent sync would hit the other user's row and
--    the repo would vanish from their list. Uniqueness is now per-user.
-- 2. AI reasoning persistence: groqClient returns docs_reasoning /
--    tests_reasoning but they were discarded — now stored for the client
--    to display as "why this rating".
-- 3. Profile avatar: /me used to call the GitHub API on every fetch,
--    burning rate limit. avatar_url is persisted at sign-in instead.
-- 4. Server-backed notification settings: the app's toggles and the
--    alert threshold slider were client-only and never enforced.
--    user_settings makes them real: the scan pipeline reads from here.

-- 1. Per-user repo uniqueness -------------------------------------------
alter table repos drop constraint if exists repos_github_repo_id_key;
alter table repos add unique (user_id, github_repo_id);
create index if not exists idx_repos_user_github_id on repos(user_id, github_repo_id);

-- 2. AI reasoning --------------------------------------------------------
alter table scan_results add column if not exists docs_reasoning text;
alter table scan_results add column if not exists tests_reasoning text;

-- 2b. Alert resolution timestamp (alerts resolve/unresolve endpoints).
alter table alerts add column if not exists resolved_at timestamptz;

-- 3. Profile avatar ------------------------------------------------------
alter table users add column if not exists avatar_url text;

-- 4. Notification settings ----------------------------------------------
create table if not exists user_settings (
  user_id uuid primary key references users(id) on delete cascade,
  notify_enabled boolean not null default true,
  notify_on_new_issue boolean not null default true,
  notify_on_score_drop boolean not null default true,
  alert_threshold int not null default 10,
  updated_at timestamptz not null default now()
);
