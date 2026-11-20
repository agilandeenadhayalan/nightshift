import { randomUUID } from 'node:crypto';
import { Database } from './db';
import { loadConfig } from './config';
import { TEST_RATE, MICRO } from '@nightshift/backend-domain';

export async function seed(db: Database) {
  await db.tx(async c => {
    await c.query('SELECT pg_advisory_xact_lock(981276)');
    await c.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true) ON CONFLICT DO NOTHING', [TEST_RATE.id, TEST_RATE]);
    await c.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES ('platform:test','TEST_MICROCREDIT','platform_test'),('subsidy:test','TEST_PAISE','subsidy_test') ON CONFLICT DO NOTHING");
    for (const handle of ['customer', 'customer2', 'listener']) {
      const approved = handle === 'listener';
      const { rows } = await c.query(`INSERT INTO users(id,test_handle,display_name,listener_approved,mode)
        VALUES($1,$2,$3,$4,$5) ON CONFLICT(test_handle) DO UPDATE SET test_handle=EXCLUDED.test_handle RETURNING id`,
      [randomUUID(), handle, approved ? 'Test Listener' : handle === 'customer' ? 'Test Customer' : 'Test Customer 2', approved, approved ? 'listener' : 'customer']);
      const id = rows[0].id;
      await c.query("INSERT INTO wallet_accounts(id,user_id,unit,kind) VALUES($1,$2,'TEST_MICROCREDIT','customer_test'),($3,$2,'TEST_PAISE','listener_test') ON CONFLICT DO NOTHING", [`customer:${id}`, id, `listener:${id}`]);
      const batch = `seed:${id}`;
      const inserted = await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'fictional_test_grant') ON CONFLICT DO NOTHING RETURNING id", [batch]);
      if (inserted.rowCount) {
        await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,$3),($1,$4,$5)', [batch, `customer:${id}`, 10_000 * MICRO, 'platform:test', -10_000 * MICRO]);
        if (approved) await c.query("INSERT INTO listener_reviews(id,user_id,reviewer,approved,reason) VALUES($1,$2,'local-seed',true,'Fictional adult fixture for consenting developer tests; not identity verified')", [randomUUID(), id]);
      }
    }
  });
}
if (require.main === module) {
  const config = loadConfig();
  const db = new Database(config.databaseUrl);
  seed(db).then(() => console.log('Fictional test identities seeded (customer, customer2, listener); no real money')).finally(() => db.close());
}
