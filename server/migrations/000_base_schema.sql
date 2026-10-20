-- Migration 000: Base schema (bootstrap).
--
-- Fresh databases get the full schema here. Fully idempotent so it can
-- also run against a database that already has the original tables —
-- existing tables/columns/indexes are simply skipped by the IF NOT
-- EXISTS guards, and the foundation migrations (001, 002) upgrade any
-- pre-existing differences.

create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  github_id bigint unique not null,
  github_username text not null,
  access_token_encrypted text not null,
  avatar_url text,
  token_version int not null default 0,
  created_at timestamptz default now()
);

create table if not exists repos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  -- Unique per user: two accounts may legitimately sync the same repo
  -- (orgs, collaborator repos). A global unique here caused cross-tenant
  -- loss — releases later than this migration fix older databases via
  -- migrations/001_foundations.sql.
  github_repo_id bigint not null,
  name text not null,
  full_name text not null,
  description text,
  language text,
  default_branch text default 'main',
  is_auto_watched boolean default false,
  is_manually_watched boolean default false,
  last_pushed_at timestamptz,
  created_at timestamptz default now(),
  unique (user_id, github_repo_id)
);

create index if not exists idx_repos_user_id on repos(user_id);
create index if not exists idx_repos_user_github_id on repos(user_id, github_repo_id);

create table if not exists scan_results (
  id uuid primary key default gen_random_uuid(),
  repo_id uuid references repos(id) on delete cascade,
  security_score int,
  code_quality_score int,
  docs_rating text,
  docs_reasoning text,
  tests_rating text,
  tests_reasoning text,
  findings jsonb default '[]',
  scanned_at timestamptz default now()
);

create index if not exists idx_scan_results_repo_id on scan_results(repo_id, scanned_at desc);

create table if not exists alerts (
  id uuid primary key default gen_random_uuid(),
  repo_id uuid references repos(id) on delete cascade,
  scan_result_id uuid references scan_results(id) on delete cascade,
  message text not null,
  severity text default 'warning',
  resolved boolean default false,
  resolved_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists feed_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  repo_id uuid references repos(id) on delete cascade,
  type text not null,
  title text not null,
  github_url text,
  created_at timestamptz default now()
);

create index if not exists idx_feed_items_user_id on feed_items(user_id, created_at desc);

create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  fcm_token text unique not null,
  created_at timestamptz default now()
);

-- Server-backed notification preferences.
create table if not exists user_settings (
  user_id uuid primary key references users(id) on delete cascade,
  notify_enabled boolean not null default true,
  notify_on_new_issue boolean not null default true,
  notify_on_score_drop boolean not null default true,
  alert_threshold int not null default 10,
  updated_at timestamptz not null default now()
);
