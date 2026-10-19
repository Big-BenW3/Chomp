import 'dotenv/config';
import { pool } from '../db.js';

const r = await pool.query(
  "select table_name from information_schema.tables where table_schema='public' order by 1",
);
console.log(r.rows.map((x) => x.table_name).join('\n') || '(no tables)');
await pool.end();
process.exit(0);
