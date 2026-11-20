import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { copyFile, mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { seed } from '../src/seed';

const migrationDirectory = path.resolve(__dirname, '../../../../db/migrations');
const schemaPrefix = `foundation_${randomUUID().replaceAll('-', '')}`;
const schemas: string[] = [];
let admin: Database, db: Database, user: string, other: string;
const digest = () => createHash('sha256').update(randomUUID()).digest('hex');
const code = (expected: string) => (error: unknown) => {
  assert.equal((error as { code?: string }).code, expected);
  return true;
};

async function isolatedDatabase(suffix: string) {
  const schema = `${schemaPrefix}_${suffix}`;
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  schemas.push(schema);
  const url = new URL(process.env.TEST_DATABASE_URL!);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  return new Database(url.toString());
}

before(async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Schema tests require an explicit dedicated TEST_DATABASE_URL');
  admin = new Database(process.env.TEST_DATABASE_URL!);
  db = await isolatedDatabase('fresh');
  await migrate(db);
  await migrate(db);
  await seed(db);
  const rows = await db.pool.query("SELECT id FROM users WHERE test_handle IN ('customer','customer2') ORDER BY test_handle");
  [user, other] = rows.rows.map(row => row.id);
});

after(async () => {
  if (db) await db.close();
  if (admin) {
    for (const schema of schemas) await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await admin.close();
  }
});

async function purchase(owner = user, amount = 10000, provider = 'fixture-store') {
  const id = randomUUID();
  await db.pool.query(`INSERT INTO purchases(id,user_id,provider,purchase_token_digest,sku,amount_paise,credit_microcredits)
    VALUES($1,$2,$3,$4,'fixture-sku',$5,600000)`, [id, owner, provider, digest(), amount]);
  return id;
}

async function account(owner = user, provider = 'fixture-payout', verify = true) {
  const id = randomUUID();
  await db.pool.query('INSERT INTO payout_accounts(id,user_id,provider,account_digest) VALUES($1,$2,$3,$4)', [id, owner, provider, digest()]);
  if (verify) await db.pool.query("UPDATE payout_accounts SET state='verified',verified_at=now() WHERE id=$1", [id]);
  return id;
}

async function payout(accountId: string, owner = user, provider = 'fixture-payout', amount = 10000, fee = 100) {
  const id = randomUUID();
  await db.pool.query(`INSERT INTO payout_requests(id,user_id,payout_account_id,provider,request_key,request_fingerprint,amount_paise,fee_paise)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8)`, [id, owner, accountId, provider, randomUUID(), digest(), amount, fee]);
  return id;
}

async function event(provider = 'fixture-payout', kind = 'payout', eventDigest = digest()) {
  const id = randomUUID();
  await db.pool.query(`INSERT INTO provider_events(id,provider,event_digest,payload_digest,kind,occurred_at)
    VALUES($1,$2,$3,$4,$5,now())`, [id, provider, eventDigest, digest(), kind]);
  return id;
}

test('empty migration is repeatable and commerce cannot bypass test-only boundaries', async () => {
  const migrations = await db.pool.query('SELECT name FROM schema_migrations ORDER BY name');
  assert.deepEqual(migrations.rows.map(row => row.name), [
    '001_android_test_milestone.sql', '002_durable_event_sequence.sql', '003_identity_commerce_foundation.sql', '004_otp_challenges.sql',
  ]);
  const id = await purchase();
  await assert.rejects(db.pool.query('UPDATE purchases SET test_only=false WHERE id=$1', [id]), code('23514'));
  await assert.rejects(db.pool.query(`INSERT INTO purchases(id,user_id,provider,environment,purchase_token_digest,sku,amount_paise,credit_microcredits)
    VALUES($1,$2,'fixture','production',$3,'sku',1,1)`, [randomUUID(), user, digest()]), code('23514'));
  await assert.rejects(db.pool.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES($1,'INR','listener_test')", [randomUUID()]), code('23514'));
});

test('forward migration preserves representative users, review, history, journal and outbox data', async () => {
  const upgrade = await isolatedDatabase('upgrade');
  const temporaryDirectory = await mkdtemp(path.join(os.tmpdir(), 'nightshift-prior-migrations-'));
  try {
    for (const file of ['001_android_test_milestone.sql', '002_durable_event_sequence.sql']) {
      await copyFile(path.join(migrationDirectory, file), path.join(temporaryDirectory, file));
    }
    await migrate(upgrade, temporaryDirectory);
    await seed(upgrade);
    const ids = (await upgrade.pool.query('SELECT id,test_handle FROM users')).rows;
    const customer = ids.find(row => row.test_handle === 'customer')!.id;
    const listener = ids.find(row => row.test_handle === 'listener')!.id;
    const callId = randomUUID(), eventId = randomUUID();
    await upgrade.pool.query(`INSERT INTO call_sessions(id,customer_id,listener_id,state,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at,ended_at,reason)
      SELECT $1,$2,$3,'ended',id,policy,60,now(),now()+interval '45 seconds',now(),'cancelled' FROM rate_versions`, [callId, customer, listener]);
    await upgrade.pool.query(`INSERT INTO call_events(id,call_id,version,kind,payload,created_at) VALUES($1,$2,1,'call.state_changed','{}',now())`, [eventId, callId]);
    await upgrade.pool.query('INSERT INTO outbox_events(id,event_id,recipient_id) VALUES($1,$2,$3)', [randomUUID(), eventId, listener]);
    const snapshot = async () => {
      const tables = ['users', 'listener_reviews', 'call_sessions', 'call_events', 'outbox_events', 'wallet_accounts', 'journal_batches', 'journal_lines'];
      const values: Record<string, unknown> = {};
      for (const table of tables) {
        values[table] = (await upgrade.pool.query(`SELECT to_jsonb(t) - 'application_id' AS record FROM ${table} t ORDER BY id`)).rows;
      }
      return values;
    };
    const beforeRows = await snapshot();
    const beforeChecksums = (await upgrade.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name')).rows;
    await migrate(upgrade);
    await migrate(upgrade);
    await seed(upgrade);
    assert.deepEqual(await snapshot(), beforeRows);
    assert.deepEqual((await upgrade.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name LIMIT 2')).rows, beforeChecksums);
    assert.equal((await upgrade.pool.query('SELECT application_id FROM listener_reviews')).rows[0].application_id, null);
  } finally {
    await upgrade.close();
    assert.equal(path.dirname(path.resolve(temporaryDirectory)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(temporaryDirectory).startsWith('nightshift-prior-migrations-'));
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

test('provider identity belongs to one immutable owner and cannot be revived after revocation', async () => {
  const id = randomUUID(), subject = digest();
  await db.pool.query(`INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'fixture-idp','fixture-issuer',$3)`, [id, user, subject]);
  await assert.rejects(db.pool.query(`INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'fixture-idp','fixture-issuer',$3)`, [randomUUID(), other, subject]), code('23505'));
  await assert.rejects(db.pool.query('UPDATE auth_identities SET user_id=$2 WHERE id=$1', [id, other]), code('23514'));
  await db.pool.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1", [id]);
  await db.pool.query("UPDATE auth_identities SET state='revoked',revoked_at=now() WHERE id=$1", [id]);
  await assert.rejects(db.pool.query('UPDATE auth_identities SET verified_at=NULL WHERE id=$1', [id]), code('23514'));
  await assert.rejects(db.pool.query("UPDATE auth_identities SET state='verified',revoked_at=NULL WHERE id=$1", [id]), code('23514'));
});

test('listener review linkage and application transitions preserve the applicant identity', async () => {
  const id = randomUUID();
  await db.pool.query('INSERT INTO listener_applications(id,user_id) VALUES($1,$2)', [id, user]);
  await assert.rejects(db.pool.query('INSERT INTO listener_applications(id,user_id) VALUES($1,$2)', [randomUUID(), user]), code('23505'));
  await assert.rejects(db.pool.query(`INSERT INTO listener_reviews(id,user_id,reviewer,approved,reason,application_id)
    VALUES($1,$2,'fixture-reviewer',true,'fixture only',$3)`, [randomUUID(), other, id]), code('23503'));
  await assert.rejects(db.pool.query("UPDATE listener_applications SET state='approved',submitted_at=now(),decided_at=now() WHERE id=$1", [id]), code('23514'));
  await db.pool.query("UPDATE listener_applications SET state='submitted',submitted_at=now() WHERE id=$1", [id]);
  await db.pool.query("UPDATE listener_applications SET state='needs_information' WHERE id=$1", [id]);
  await db.pool.query("UPDATE listener_applications SET state='submitted' WHERE id=$1", [id]);
  await db.pool.query("UPDATE listener_applications SET state='approved',decided_at=now() WHERE id=$1", [id]);
  await db.pool.query(`INSERT INTO listener_reviews(id,user_id,reviewer,approved,reason,application_id)
    VALUES($1,$2,'fixture-reviewer',true,'fixture only',$3)`, [randomUUID(), user, id]);
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1', [user])).rows[0].listener_approved, false);
  await assert.rejects(db.pool.query("UPDATE listener_applications SET state='draft',decided_at=NULL WHERE id=$1", [id]), code('23514'));
});

test('purchase uniqueness, immutable snapshots and positive fixed-point units reject invalid records', async () => {
  for (const amount of [0, -1]) await assert.rejects(purchase(user, amount), code('23514'));
  await assert.rejects(purchase(user, 1.5), code('22P02'));
  const id = await purchase();
  const original = (await db.pool.query('SELECT * FROM purchases WHERE id=$1', [id])).rows[0];
  await assert.rejects(db.pool.query(`INSERT INTO purchases(id,user_id,provider,purchase_token_digest,sku,amount_paise,credit_microcredits)
    VALUES($1,$2,$3,$4,'fixture-sku',10000,600000)`, [randomUUID(), other, original.provider, original.purchase_token_digest]), code('23505'));
  await assert.rejects(db.pool.query('UPDATE purchases SET user_id=$2 WHERE id=$1', [id, other]), code('23514'));
  await assert.rejects(db.pool.query('UPDATE purchases SET amount_paise=1 WHERE id=$1', [id]), code('23514'));
  await assert.rejects(db.pool.query('DELETE FROM purchases WHERE id=$1', [id]), code('23514'));
  await assert.rejects(db.pool.query("UPDATE purchases SET state='fulfilled' WHERE id=$1", [id]), code('23514'));
  await db.pool.query("UPDATE purchases SET state='verified' WHERE id=$1", [id]);
  await db.pool.query("UPDATE purchases SET state='fulfilled' WHERE id=$1", [id]);
  await db.pool.query("UPDATE purchases SET state='revoked' WHERE id=$1", [id]);
  await assert.rejects(db.pool.query("UPDATE purchases SET state='verified' WHERE id=$1", [id]), code('23514'));
});

test('refunds cannot target another owner or over-reserve a purchase under concurrent requests', async () => {
  const id = await purchase(user, 10000);
  const insert = (amount: number, owner = user, requestKey = randomUUID()) => db.pool.query(`INSERT INTO refunds(id,purchase_id,user_id,provider,request_key,amount_paise)
    VALUES($1,$2,$3,'fixture-store',$4,$5) RETURNING id`, [randomUUID(), id, owner, requestKey, amount]);
  await assert.rejects(insert(1), code('23514'));
  await db.pool.query("UPDATE purchases SET state='verified' WHERE id=$1", [id]);
  await assert.rejects(insert(1, other), code('23503'));
  for (const amount of [0, -1, 10001]) await assert.rejects(insert(amount), code('23514'));
  const competing = await Promise.allSettled([insert(6000), insert(6000)]);
  assert.equal(competing.filter(result => result.status === 'fulfilled').length, 1);
  const rejected = competing.find(result => result.status === 'rejected') as PromiseRejectedResult;
  assert.equal(rejected.reason.code, '23514');
  const won = competing.find(result => result.status === 'fulfilled') as PromiseFulfilledResult<Awaited<ReturnType<typeof insert>>>;
  const refundId = won.value.rows[0].id;
  await assert.rejects(db.pool.query('DELETE FROM refunds WHERE id=$1', [refundId]), code('23514'));
  await db.pool.query("UPDATE refunds SET state='processing' WHERE id=$1", [refundId]);
  await db.pool.query("UPDATE refunds SET state='unknown' WHERE id=$1", [refundId]);
  await assert.rejects(insert(5000), code('23514'));
  await db.pool.query("UPDATE refunds SET state='succeeded' WHERE id=$1", [refundId]);
  await assert.rejects(db.pool.query("UPDATE refunds SET state='failed' WHERE id=$1", [refundId]), code('23514'));
  const key = randomUUID();
  await insert(4000, user, key);
  await assert.rejects(insert(4000, user, key), error => {
    assert.ok(['23505', '23514'].includes((error as { code: string }).code));
    return true;
  });
});

test('repeatable-read refund races abort a stale snapshot before over-reserving', async () => {
  const id = await purchase(user, 10000);
  await db.pool.query("UPDATE purchases SET state='verified' WHERE id=$1", [id]);
  const first = await db.pool.connect(), second = await db.pool.connect();
  let firstOpen = false, secondOpen = false;
  const sql = `INSERT INTO refunds(id,purchase_id,user_id,provider,request_key,amount_paise)
    VALUES($1,$2,$3,'fixture-store',$4,6000)`;
  try {
    await first.query('BEGIN ISOLATION LEVEL REPEATABLE READ'); firstOpen = true;
    await second.query('BEGIN ISOLATION LEVEL REPEATABLE READ'); secondOpen = true;
    // Establish both snapshots before either refund exists. A lock without an
    // actual parent-row update is insufficient to refresh the second snapshot.
    for (const client of [first, second]) {
      assert.equal((await client.query('SELECT count(*) FROM refunds WHERE purchase_id=$1', [id])).rows[0].count, '0');
    }
    await first.query(sql, [randomUUID(), id, user, randomUUID()]);
    const competing = second.query(sql, [randomUUID(), id, user, randomUUID()])
      .then(() => ({ status: 'fulfilled' as const }))
      .catch((reason: { code: string }) => ({ status: 'rejected' as const, reason }));
    await first.query('COMMIT'); firstOpen = false;
    const result = await competing;
    await second.query(result.status === 'fulfilled' ? 'COMMIT' : 'ROLLBACK'); secondOpen = false;
    assert.equal(result.status, 'rejected', 'both stale snapshots must not reserve 6000 from a 10000 purchase');
    if (result.status === 'rejected') assert.equal(result.reason.code, '40001');
    assert.equal((await db.pool.query('SELECT SUM(amount_paise) AS total FROM refunds WHERE purchase_id=$1', [id])).rows[0].total, '6000');
    // Retrying the complete operation gets a fresh snapshot and the amount cap.
    await assert.rejects(db.pool.query(sql, [randomUUID(), id, user, randomUUID()]), code('23514'));
  } finally {
    if (firstOpen) await first.query('ROLLBACK');
    if (secondOpen) await second.query('ROLLBACK');
    first.release(); second.release();
  }
});

test('payouts require a verified account owned by the requester and valid integer amounts', async () => {
  const pending = await account(user, 'fixture-payout', false);
  await assert.rejects(payout(pending), code('23514'));
  const verified = await account();
  await assert.rejects(payout(verified, other), code('23503'));
  await assert.rejects(payout(verified, user, 'different-provider'), code('23503'));
  for (const [amount, fee] of [[0, 0], [-1, 0], [100, -1], [100, 100], [100, 101]]) {
    await assert.rejects(payout(verified, user, 'fixture-payout', amount!, fee!), code('23514'));
  }
  const id = await payout(verified);
  await assert.rejects(db.pool.query('DELETE FROM payout_requests WHERE id=$1', [id]), code('23514'));
  assert.equal((await db.pool.query('SELECT net_paise FROM payout_requests WHERE id=$1', [id])).rows[0].net_paise, '9900');
  await assert.rejects(db.pool.query('UPDATE payout_requests SET payout_account_id=$2 WHERE id=$1', [id, pending]), code('23514'));
  await assert.rejects(db.pool.query(`INSERT INTO payout_requests(id,user_id,payout_account_id,provider,request_key,request_fingerprint,amount_paise,fee_paise)
    SELECT $2,user_id,payout_account_id,provider,request_key,request_fingerprint,amount_paise,fee_paise FROM payout_requests WHERE id=$1`, [id, randomUUID()]), code('23505'));
});

test('payout unknown outcomes reconcile after account disablement without regressing terminal states', async () => {
  const accountId = await account(), requestId = await payout(accountId);
  await assert.rejects(db.pool.query("UPDATE payout_requests SET state='paid' WHERE id=$1", [requestId]), code('23514'));
  await db.pool.query("UPDATE payout_requests SET state='approved' WHERE id=$1", [requestId]);
  await db.pool.query("UPDATE payout_requests SET state='processing' WHERE id=$1", [requestId]);
  await db.pool.query("UPDATE payout_requests SET state='unknown' WHERE id=$1", [requestId]);
  await db.pool.query("UPDATE payout_accounts SET state='disabled' WHERE id=$1", [accountId]);
  await assert.rejects(payout(accountId), code('23514'));
  await db.pool.query("UPDATE payout_requests SET state='paid' WHERE id=$1", [requestId]);
  await assert.rejects(db.pool.query("UPDATE payout_requests SET state='processing' WHERE id=$1", [requestId]), code('23514'));
  await db.pool.query("UPDATE payout_requests SET state='reversed' WHERE id=$1", [requestId]);
  await assert.rejects(db.pool.query("UPDATE payout_requests SET state='paid' WHERE id=$1", [requestId]), code('23514'));
});

test('provider events and payout event links are deduplicated, provider-bound and append-only', async () => {
  const accountId = await account(), requestId = await payout(accountId), eventDigest = digest();
  const eventId = await event('fixture-payout', 'payout', eventDigest);
  await assert.rejects(event('fixture-payout', 'payout', eventDigest), code('23505'));
  await assert.rejects(db.pool.query('UPDATE provider_events SET payload_digest=$2 WHERE id=$1', [eventId, digest()]), code('23514'));
  await assert.rejects(db.pool.query('DELETE FROM provider_events WHERE id=$1', [eventId]), code('23514'));
  const wrongProviderEvent = await event('other-provider');
  await assert.rejects(db.pool.query(`INSERT INTO payout_events(id,payout_request_id,provider_event_id,provider,outcome)
    VALUES($1,$2,$3,'fixture-payout','processing')`, [randomUUID(), requestId, wrongProviderEvent]), code('23503'));
  const wrongKindEvent = await event('fixture-payout', 'purchase');
  await assert.rejects(db.pool.query(`INSERT INTO payout_events(id,payout_request_id,provider_event_id,provider,outcome)
    VALUES($1,$2,$3,'fixture-payout','processing')`, [randomUUID(), requestId, wrongKindEvent]), code('23503'));
  const link = randomUUID();
  await db.pool.query(`INSERT INTO payout_events(id,payout_request_id,provider_event_id,provider,outcome)
    VALUES($1,$2,$3,'fixture-payout','processing')`, [link, requestId, eventId]);
  await assert.rejects(db.pool.query(`INSERT INTO payout_events(id,payout_request_id,provider_event_id,provider,outcome)
    VALUES($1,$2,$3,'fixture-payout','paid')`, [randomUUID(), requestId, eventId]), code('23505'));
  await assert.rejects(db.pool.query("UPDATE payout_events SET outcome='paid' WHERE id=$1", [link]), code('23514'));
  await assert.rejects(db.pool.query('DELETE FROM payout_events WHERE id=$1', [link]), code('23514'));
});
