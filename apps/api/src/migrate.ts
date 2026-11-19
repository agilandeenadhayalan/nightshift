import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { Database } from './db';

export async function migrate(db: Database, directory = path.resolve(__dirname, '../../../../db/migrations')) {
  await db.tx(async client => {
    await client.query('SELECT pg_advisory_xact_lock(981275)');
    await client.query('CREATE TABLE IF NOT EXISTS schema_migrations(name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())');
    for (const name of (await readdir(directory)).filter(n => n.endsWith('.sql')).sort()) {
      const sql = await readFile(path.join(directory, name), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      const { rows } = await client.query('SELECT checksum FROM schema_migrations WHERE name=$1', [name]);
      if (rows.length) { if (rows[0].checksum !== checksum) throw new Error(`Migration modified after application: ${name}`); continue; }
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations(name, checksum) VALUES($1,$2)', [name, checksum]);
    }
  });
}
if (require.main === module) {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL required');
  const db = new Database(process.env.DATABASE_URL);
  migrate(db).then(() => console.log('Migrations applied')).finally(() => db.close());
}
