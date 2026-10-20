import 'dotenv/config';
import { pool } from '../db.js';

const applied = await pool.query('select name from schema_migrations order by name');
console.log('migrations applied:', applied.rows.map((r) => r.name).join(', ') || '(none)');
await pool.end();
process.exit(0);
