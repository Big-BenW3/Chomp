/// Database migrations runner.
///
/// Applies SQL files in `migrations/` in filename order. Each applied
/// migration is recorded in a `schema_migrations` table so it never
/// runs twice. Idempotent and ordered — the standard pattern.
///
/// Usage: `npm run migrate` (or `node migrations/run.js`)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import 'dotenv/config';
import { pool, query } from '../db.js';

const dir = path.dirname(fileURLToPath(import.meta.url));

/// Boots apply migrations and terminate.
export async function runMigrations() {
  await query(`create table if not exists schema_migrations (
    name text primary key,
    applied_at timestamptz default now()
  )`);

  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  const applied = new Set((await query('select name from schema_migrations')).rows.map((r) => r.name));

  let ran = 0;
  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = fs.readFileSync(path.join(dir, file), 'utf8');
    console.log(`Applying migration ${file}...`);
    try {
      await pool.query(sql); // one call per migration file

      await query('insert into schema_migrations (name) values ($1)', [file]);
      ran += 1;
    } catch (err) {
      console.error(`Migration ${file} failed`, err);
      process.exit(1);
    }
  }
  console.log(ran === 0 ? 'Migrations up to date.' : `Applied ${ran} migration(s).`);
}

// Run directly.
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  runMigrations()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
