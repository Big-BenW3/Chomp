import 'dotenv/config';
import { pool } from '../db.js';

const tables = await pool.query(
  "select table_name from information_schema.tables where table_schema='public' order by 1",
);
console.log('TABLES:', tables.rows.map((r) => r.table_name).join(', '));

const cols = await pool.query(
  `select table_name, column_name from information_schema.columns
    where table_schema='public'
      and table_name in ('users','repos','scan_results','alerts','user_settings')
      and column_name in ('avatar_url','token_version','docs_reasoning','tests_reasoning','resolved_at','alert_threshold')
    order by table_name, column_name`,
);
console.log('KEY COLUMNS:', cols.rows.map((r) => `${r.table_name}.${r.column_name}`).join(', '));

const cons = await pool.query(
  `select conname from pg_constraint where conrelid = 'repos'::regclass and contype = 'u'`,
);
console.log('REPOS UNIQUE:', cons.rows.map((r) => r.conname).join(', '));

const mig = await pool.query('select name from schema_migrations order by name');
console.log('RECORDED:', mig.rows.map((r) => r.name).join(', '));

await pool.end();
process.exit(0);
