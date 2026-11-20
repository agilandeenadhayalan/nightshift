import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import { Config, loadConfig } from '../src/config';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { createApplication } from '../src/http';
import { ApiError } from '../src/errors';
import { OtpChallenges, OtpProvider } from '../src/identity/otp';
import { createPhoneAuthentication, PhoneAuthDependencies } from '../src/identity/phone-auth';

const schema = `phone_http_${randomUUID().replaceAll('-', '')}`;
let admin: Database, db: Database, config: Config, runtime: Awaited<ReturnType<typeof createApplication>>;
let base: string, dependencies: PhoneAuthDependencies, now = Date.now(), signedUid = '';
const initialEnvironment = process.env.NODE_ENV;
const phone = '+919000000001', deviceId = 'synthetic-phone-device';
let sends = 0;
let contract: any, ajv: Ajv;

before(async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a dedicated TEST_DATABASE_URL');
  process.env.NODE_ENV = 'test';
  const url = new URL(process.env.TEST_DATABASE_URL!);
  admin = new Database(url.toString());
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  config = loadConfig({ NODE_ENV: 'test', DATABASE_URL: url.toString(), REDIS_URL: process.env.REDIS_URL,
    DEV_AUTH_ENABLED: 'true', DEV_ACCESS_KEY: 'isolated-http-fixture-key-only' });
  db = new Database(config.databaseUrl);
  await migrate(db);
  runtime = await createApplication(config, () => now);
  await runtime.app.listen(0, '127.0.0.1');
  base = await runtime.app.getUrl();
  contract = JSON.parse(await readFile(path.resolve(__dirname, '../../../../packages/contracts/openapi.json'), 'utf8'));
  ajv = new Ajv({ strict: false });
  addFormats(ajv);
  ajv.addSchema(contract, 'contract');
});

after(async () => {
  if (runtime) await runtime.close();
  if (db) await db.close();
  if (admin) { await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.close(); }
  if (initialEnvironment === undefined) delete process.env.NODE_ENV;
  else process.env.NODE_ENV = initialEnvironment;
});

async function request(endpoint: string, body: unknown, key?: string) {
  const response = await fetch(`${base}/v1/${endpoint}`, { method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(key ? { 'Idempotency-Key': key } : {}) }, body: JSON.stringify(body) });
  return { response, body: await response.json() as any };
}
function conforms(name: string, value: unknown) {
  const validate = ajv.compile({ $ref: `contract#/components/schemas/${name}` });
  assert.ok(validate(value), JSON.stringify(validate.errors));
}

test('identity endpoints are present but disabled by default without provider traffic', async () => {
  for (const endpoint of ['auth/otp/request', 'auth/otp/verify', 'auth/firebase/verify']) {
    const result = await request(endpoint, {});
    assert.equal(result.response.status, 503);
    assert.equal(result.body.error.code, 'PHONE_AUTH_UNAVAILABLE');
    assert.equal(result.response.headers.get('cache-control'), 'no-store');
    conforms('Error', result.body);
  }
  assert.equal((await db.pool.query('SELECT count(*) FROM otp_challenges')).rows[0].count, '0');
});

test('enabled test wiring requires consent and an idempotency header without leaking validation inputs', async () => {
  await runtime.close();
  config.phoneAuth = { projectId: 'nightshift-http-fixture', digestKey: randomBytes(32).toString('hex'),
    consentVersion: 'phone-signin-v1', msg91AuthKey: 'unused-fixture-key-only', msg91WidgetId: 'unused-widget', dailySendLimit: 10 };
  const provider: OtpProvider = {
    async send() { sends++; return { reference: randomUUID().replaceAll('-', '') }; },
    async verify(_phone, code) { return code === '123456' ? 'valid' : 'wrong'; },
  };
  const otp = new OtpChallenges(db, provider, {
    async createCustomToken(uid) { signedUid = uid; return `custom-token-fixture-${uid}`; },
  }, { digestKey: config.phoneAuth.digestKey, issuer: config.phoneAuth.projectId, consentVersion: config.phoneAuth.consentVersion }, () => now);
  dependencies = { otp, firebase: {
    async verifyIdToken(token) {
      if (token !== `id-token-fixture-${signedUid}`) throw new ApiError(401, 'INVALID_ID_TOKEN', 'Sign in again.');
      return { uid: signedUid, issuer: `https://securetoken.google.com/${config.phoneAuth!.projectId}`,
        audience: config.phoneAuth!.projectId, authTime: Math.floor(now / 1000), issuedAt: Math.floor(now / 1000), expiresAt: Math.floor(now / 1000) + 3600 };
    },
  } };
  runtime = await createApplication(config, () => now, dependencies);
  await runtime.app.listen(0, '127.0.0.1');
  base = await runtime.app.getUrl();
  const missingKey = await request('auth/otp/request', { phone, deviceId, consentVersion: 'phone-signin-v1' });
  assert.equal(missingKey.response.status, 400);
  const invalidConsent = await request('auth/otp/request', { phone, deviceId, consentVersion: 'outdated' }, randomUUID());
  assert.equal(invalidConsent.body.error.code, 'OTP_INVALID_CONSENT');
  assert.equal(sends, 0);
  assert.ok(!JSON.stringify(invalidConsent.body).includes(phone));
});

test('HTTP request retry returns one challenge and correct cooldown/error metadata', async () => {
  const key = randomUUID(), body = { phone, deviceId, consentVersion: 'phone-signin-v1' };
  const first = await request('auth/otp/request', body, key);
  const replay = await request('auth/otp/request', body, key);
  assert.equal(first.response.status, 201);
  assert.deepEqual(first.body, replay.body);
  assert.equal(sends, 1);
  conforms('OtpChallenge', first.body);
  const cooldown = await request('auth/otp/request', body, randomUUID());
  assert.equal(cooldown.response.status, 429);
  assert.equal(cooldown.body.error.code, 'OTP_COOLDOWN');
  assert.equal(cooldown.body.error.retryAfterSeconds, 60);
  assert.equal(cooldown.response.headers.get('retry-after'), '60');
  conforms('Error', cooldown.body);
});

test('wrong/valid/reused OTP HTTP flow binds one unapproved identity with no app session', async () => {
  const id = (await db.pool.query('SELECT id FROM otp_challenges')).rows[0].id;
  const wrong = await request('auth/otp/verify', { challengeId: id, phone, deviceId, code: '000000' });
  assert.equal(wrong.response.status, 400);
  assert.equal(wrong.body.error.code, 'OTP_INVALID_CODE');
  conforms('Error', wrong.body);
  const verified = await request('auth/otp/verify', { challengeId: id, phone, deviceId, code: '123456' });
  assert.equal(verified.response.status, 201);
  assert.equal(verified.body.customToken, `custom-token-fixture-${signedUid}`);
  assert.equal(verified.body.needsOnboarding, true);
  assert.equal(verified.response.headers.get('cache-control'), 'no-store');
  conforms('OtpProof', verified.body);
  const user = (await db.pool.query('SELECT mode,adult_confirmed,listener_approved FROM users WHERE id=$1', [signedUid])).rows[0];
  assert.deepEqual(user, { mode: 'customer', adult_confirmed: false, listener_approved: false });
  assert.equal((await db.pool.query('SELECT count(*) FROM auth_sessions')).rows[0].count, '0');
  assert.equal((await db.pool.query('SELECT count(*) FROM wallet_accounts WHERE user_id=$1', [signedUid])).rows[0].count, '0');
  const reused = await request('auth/otp/verify', { challengeId: id, phone, deviceId, code: '123456' });
  assert.equal(reused.response.status, 409);
  assert.equal(reused.body.error.code, 'OTP_CONSUMED');
});

test('Firebase ID receipt requires verified binding and cannot be used as an app session', async () => {
  const custom = await request('auth/firebase/verify', { idToken: `custom-token-fixture-${signedUid}` });
  assert.equal(custom.response.status, 401);
  const token = `id-token-fixture-${signedUid}`;
  const identity = await request('auth/firebase/verify', { idToken: token });
  assert.equal(identity.response.status, 201);
  assert.deepEqual(identity.body, { userId: signedUid, needsOnboarding: true });
  conforms('PhoneIdentity', identity.body);
  const app = await fetch(`${base}/v1/me`, { headers: { Authorization: `Bearer ${token}` } });
  assert.equal(app.status, 401);
  await app.body?.cancel();
  await db.pool.query('UPDATE users SET suspended=true WHERE id=$1', [signedUid]);
  assert.equal((await request('auth/firebase/verify', { idToken: token })).response.status, 401);
  await db.pool.query('UPDATE users SET suspended=false,adult_confirmed=true WHERE id=$1', [signedUid]);
  const existing = await request('auth/firebase/verify', { idToken: token });
  assert.equal(existing.body.needsOnboarding, false);
  conforms('PhoneIdentity', existing.body);
  await db.pool.query("UPDATE auth_identities SET state='revoked',revoked_at=now() WHERE user_id=$1", [signedUid]);
  assert.equal((await request('auth/firebase/verify', { idToken: token })).response.status, 401);
});

test('test adapters cannot be injected when the process is configured for production', async () => {
  process.env.NODE_ENV = 'production';
  try {
    await assert.rejects(createPhoneAuthentication(db, runtime.presence, config, () => now, dependencies), /restricted to isolated test/);
  } finally { process.env.NODE_ENV = 'test'; }
});

test('expired OTP HTTP response uses stable error schema and never echoes code or phone', async () => {
  const fresh = await request('auth/otp/request', { phone: '+919000000002', deviceId, consentVersion: 'phone-signin-v1' }, randomUUID());
  now += 300_001;
  const expired = await request('auth/otp/verify', { challengeId: fresh.body.challengeId, phone: '+919000000002', deviceId, code: '123456' });
  assert.equal(expired.response.status, 410);
  assert.equal(expired.body.error.code, 'OTP_EXPIRED');
  conforms('Error', expired.body);
  assert.ok(!JSON.stringify(expired.body).includes('123456'));
  assert.ok(!JSON.stringify(expired.body).includes('+919000000002'));
});
