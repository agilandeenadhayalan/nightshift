import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { OtpChallenges, OtpFailure, OtpLimits, OtpProvider, normalizeIndianPhone } from '../src/identity/otp';

// Synthetic identities; all provider operations in this file are in-memory fixtures.
const PHONE = '+919000000001', SECOND_PHONE = '+919000000002', CODE = '123456';
const DEVICE = 'fixture-device', IP = '192.0.2.1', CONSENT = 'otp-consent-v1';
const schema = `otp_${randomUUID().replaceAll('-', '')}`;
let admin: Database, db: Database;
before(async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'OTP tests require a dedicated TEST_DATABASE_URL');
  admin = new Database(process.env.TEST_DATABASE_URL!);
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  const url = new URL(process.env.TEST_DATABASE_URL!);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  db = new Database(url.toString());
  await migrate(db); await migrate(db);
});
after(async () => {
  if (db) await db.close();
  if (admin) { await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.close(); }
});

class FixtureProvider implements OtpProvider {
  sent = 0; verified = 0;
  sendFailure = false; verifyFailure = false;
  providerExpired = false;
  sendOverride?: () => Promise<{ reference: string }>;
  verifyOverride?: () => Promise<'valid' | 'wrong' | 'expired'>;
  async send(_phone: string) {
    this.sent++;
    if (this.sendOverride) return this.sendOverride();
    if (this.sendFailure) throw new Error(`Provider private detail ${PHONE} ${CODE}`);
    return { reference: `fixture-${randomUUID()}` };
  }
  async verify(_phone: string, code: string, _reference: string): Promise<'valid' | 'wrong' | 'expired'> {
    this.verified++;
    if (this.verifyOverride) return this.verifyOverride();
    if (this.verifyFailure) throw new Error(`Provider private detail ${PHONE} ${CODE}`);
    return this.providerExpired ? 'expired' : code === CODE ? 'valid' : 'wrong';
  }
}
function fixture(limits: Partial<OtpLimits> = {}, timeoutMs = 1000) {
  // Keep quota assertions away from real wall-clock window boundaries.
  let now = Date.parse('2026-01-01T12:10:00.000Z');
  const provider = new FixtureProvider(), issuer = `fixture-${randomUUID()}`;
  const options = { digestKey: randomBytes(32).toString('hex'), issuer, consentVersion: CONSENT, limits, providerTimeoutMs: timeoutMs };
  const tokens = { calls: 0, fail: false, async createCustomToken(uid: string) {
    this.calls++; if (this.fail) throw new Error(`Signer secret ${PHONE} ${CODE}`);
    return `synthetic-custom-token-${uid}`;
  } };
  const service = new OtpChallenges(db, provider, tokens, options, () => now);
  const request = (overrides: Record<string, unknown> = {}, ip = IP) => service.request({
    phone: PHONE, deviceId: DEVICE, consentVersion: CONSENT, idempotencyKey: randomUUID(), ...overrides,
  }, ip);
  const verify = (challengeId: string, overrides: Record<string, unknown> = {}, ip = IP) => service.verify({
    challengeId, phone: PHONE, deviceId: DEVICE, code: CODE, ...overrides,
  }, ip);
  return { provider, tokens, options, issuer, service, request, verify, now: () => now, advance: (ms: number) => { now += ms; } };
}
function failure(code: string, status?: number) {
  return (error: unknown) => {
    assert.equal((error as OtpFailure).code, code);
    if (status) assert.equal((error as OtpFailure).status, status);
    assert.ok(!(error as Error).message.includes(PHONE));
    assert.ok(!(error as Error).message.includes(CODE));
    return true;
  };
}
async function row(id: string) { return (await db.pool.query('SELECT * FROM otp_challenges WHERE id=$1', [id])).rows[0]; }

test('request concurrency and idempotency reserve exactly one provider send', async () => {
  const f = fixture(), key = randomUUID();
  const views = await Promise.all(Array.from({ length: 20 }, () => f.request({ idempotencyKey: key })));
  assert.equal(new Set(views.map(view => view.challengeId)).size, 1);
  assert.equal(f.provider.sent, 1);
  assert.equal((await row(views[0]!.challengeId)).state, 'sent');
  const replay = await f.request({ idempotencyKey: key });
  assert.equal(replay.challengeId, views[0]!.challengeId);
  assert.equal(replay.expiresAt, views[0]!.expiresAt);
  assert.equal(f.provider.sent, 1);
});

test('one device cannot reuse its request key for concurrent different phones', async () => {
  const f = fixture(), idempotencyKey = randomUUID();
  const results = await Promise.allSettled([f.request({ idempotencyKey }), f.request({ idempotencyKey, phone: SECOND_PHONE })]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const rejected = results.find(result => result.status === 'rejected') as PromiseRejectedResult;
  assert.equal(rejected.reason.code, 'IDEMPOTENCY_CONFLICT');
  assert.equal(f.provider.sent, 1);
});

test('an expired request-key replay reports expiry and never sends again', async () => {
  const f = fixture(), idempotencyKey = randomUUID();
  const first = await f.request({ idempotencyKey });
  f.advance(300_000);
  const replay = await f.request({ idempotencyKey });
  assert.equal(replay.challengeId, first.challengeId);
  assert.equal(replay.state, 'expired');
  assert.equal((await row(first.challengeId)).state, 'expired');
  assert.equal(f.provider.sent, 1);
});

test('consent and supported phone validation reject unknown claims without sending', async () => {
  const f = fixture();
  assert.equal(normalizeIndianPhone('90000 00001'), PHONE);
  assert.equal(normalizeIndianPhone('919000000001'), PHONE);
  await assert.rejects(f.request({ consentVersion: 'unaccepted' }), failure('OTP_INVALID_CONSENT', 400));
  await assert.rejects(f.request({ phone: '+12025550123' }), failure('OTP_INVALID_PHONE', 400));
  await assert.rejects(f.request({ adultConfirmed: true, mode: 'listener' }), failure('INVALID_FIELD', 400));
  assert.equal(f.provider.sent, 0);
});

test('resend cooldown supersedes the old challenge without making it reusable', async () => {
  const f = fixture(), first = await f.request();
  f.advance(59_000);
  await assert.rejects(f.request(), error => failure('OTP_COOLDOWN', 429)(error) && (error as OtpFailure).retryAfterSeconds === 1);
  f.advance(1000);
  const second = await f.request();
  assert.notEqual(first.challengeId, second.challengeId);
  assert.equal(f.provider.sent, 2);
  assert.equal((await row(first.challengeId)).state, 'superseded');
  await assert.rejects(f.verify(first.challengeId), failure('OTP_CONSUMED', 409));
  assert.equal(f.provider.verified, 0);
  await f.verify(second.challengeId);
  await assert.rejects(f.request(), failure('OTP_COOLDOWN', 429));
});

test('five incorrect attempts lock the challenge and cannot be reset by resend', async () => {
  const f = fixture(), challenge = await f.request();
  for (let attempt = 1; attempt <= 5; attempt++) {
    await assert.rejects(f.verify(challenge.challengeId, { code: '000000' }), failure(attempt === 5 ? 'OTP_LOCKED' : 'OTP_INVALID_CODE'));
  }
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_LOCKED', 429));
  f.advance(60_000);
  await assert.rejects(f.request(), failure('OTP_COOLDOWN', 429));
  assert.equal(f.provider.verified, 5);
  assert.equal((await row(challenge.challengeId)).attempts, 5);
  assert.equal((await row(challenge.challengeId)).state, 'locked');
  assert.equal(f.tokens.calls, 0);
});

test('local and provider expiry prevent identity or token issuance', async () => {
  const f = fixture(), challenge = await f.request();
  f.advance(300_000);
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_EXPIRED', 410));
  assert.equal(f.provider.verified, 0);
  assert.equal((await row(challenge.challengeId)).state, 'expired');
  const next = await f.request();
  f.provider.providerExpired = true;
  await assert.rejects(f.verify(next.challengeId), failure('OTP_EXPIRED', 410));
  assert.equal((await row(next.challengeId)).state, 'expired');
  assert.equal(f.tokens.calls, 0);
});

test('simultaneous verification consumes one proof and creates only one unapproved identity', async () => {
  const f = fixture(), challenge = await f.request();
  const outcomes = await Promise.allSettled(Array.from({ length: 20 }, () => f.verify(challenge.challengeId)));
  const successes = outcomes.filter(result => result.status === 'fulfilled') as PromiseFulfilledResult<Awaited<ReturnType<typeof f.verify>>>[];
  assert.equal(successes.length, 1);
  for (const rejected of outcomes.filter(result => result.status === 'rejected') as PromiseRejectedResult[]) {
    assert.ok(['OTP_IN_PROGRESS', 'OTP_CONSUMED'].includes(rejected.reason.code));
  }
  const result = successes[0]!.value;
  assert.equal(f.provider.verified, 1);
  assert.equal(f.tokens.calls, 1);
  assert.equal(result.needsOnboarding, true);
  assert.match(result.customToken, /^synthetic-custom-token-/);
  const user = (await db.pool.query('SELECT * FROM users WHERE id=$1', [result.userId])).rows[0];
  assert.equal(user.mode, 'customer'); assert.equal(user.adult_confirmed, false);
  assert.equal(user.listener_approved, false); assert.equal(user.desired_online, false);
  assert.equal(user.test_handle, null);
  assert.equal((await db.pool.query('SELECT * FROM auth_identities WHERE issuer=$1', [f.issuer])).rowCount, 1);
  assert.equal((await db.pool.query('SELECT * FROM auth_sessions WHERE user_id=$1', [result.userId])).rowCount, 0);
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_CONSUMED', 409));
});

test('later verification binds the existing UID without resetting approved account state', async () => {
  const f = fixture(), first = await f.request(), signedIn = await f.verify(first.challengeId);
  await db.pool.query("UPDATE users SET adult_confirmed=true,listener_approved=true,mode='listener' WHERE id=$1", [signedIn.userId]);
  f.advance(300_001);
  const next = await f.request(), again = await f.verify(next.challengeId);
  assert.equal(again.userId, signedIn.userId);
  assert.equal(again.needsOnboarding, false);
  const user = (await db.pool.query('SELECT mode,adult_confirmed,listener_approved FROM users WHERE id=$1', [again.userId])).rows[0];
  assert.deepEqual(user, { mode: 'listener', adult_confirmed: true, listener_approved: true });
  assert.equal((await db.pool.query('SELECT * FROM auth_identities WHERE issuer=$1', [f.issuer])).rowCount, 1);
});

for (const restriction of ['revoked', 'suspended']) {
  test(`${restriction} identity cannot obtain another custom token from a correct OTP`, async () => {
    const f = fixture(), first = await f.request(), signedIn = await f.verify(first.challengeId);
    if (restriction === 'revoked') await db.pool.query("UPDATE auth_identities SET state='revoked',revoked_at=$2 WHERE issuer=$1", [f.issuer, new Date(f.now())]);
    else await db.pool.query('UPDATE users SET suspended=true WHERE id=$1', [signedIn.userId]);
    f.advance(300_001);
    const next = await f.request();
    await assert.rejects(f.verify(next.challengeId), failure('ACCOUNT_RESTRICTED', 403));
    assert.equal(f.tokens.calls, 1);
    assert.equal((await row(next.challengeId)).state, 'consumed');
  });
}

test('failed custom-token signing never makes consumed proof replayable', async () => {
  const f = fixture(), challenge = await f.request();
  f.tokens.fail = true;
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_UNAVAILABLE', 503));
  const saved = await row(challenge.challengeId);
  assert.equal(saved.state, 'consumed');
  assert.ok(saved.user_id);
  f.tokens.fail = false;
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_CONSUMED', 409));
  assert.equal(f.tokens.calls, 1);
  await assert.rejects(f.request(), failure('OTP_COOLDOWN', 429));
  f.advance(300_001);
  const newChallenge = await f.request(), recovered = await f.verify(newChallenge.challengeId);
  assert.equal(recovered.userId, saved.user_id);
});

test('unknown send outcome is explicit and idempotent without blind resend', async () => {
  const f = fixture(), idempotencyKey = randomUUID();
  f.provider.sendFailure = true;
  const view = await f.request({ idempotencyKey });
  assert.equal(view.state, 'send_unknown'); assert.equal(view.retryAt, view.expiresAt);
  assert.equal(JSON.stringify(view).includes(PHONE), false);
  assert.deepEqual(await f.request({ idempotencyKey }), view);
  f.advance(60_000);
  await assert.rejects(f.request(), failure('OTP_COOLDOWN', 429));
  await assert.rejects(f.verify(view.challengeId), failure('OTP_UNKNOWN_OUTCOME', 503));
  assert.equal(f.provider.sent, 1); assert.equal(f.provider.verified, 0);
});

test('provider deadline leaves a durable unknown send instead of a hanging request', async () => {
  const f = fixture({}, 20);
  f.provider.sendOverride = () => new Promise(() => {});
  const view = await f.request();
  assert.equal(view.state, 'send_unknown');
  assert.equal((await row(view.challengeId)).state, 'send_unknown');
});

test('a provider response containing a phone cannot be persisted as an opaque reference', async () => {
  const f = fixture();
  f.provider.sendOverride = async () => ({ reference: `unexpected-${PHONE.slice(1)}` });
  const view = await f.request();
  assert.equal(view.state, 'send_unknown');
  assert.equal((await row(view.challengeId)).provider_reference, null);
});

test('unknown verification outcome cannot be retried or create an identity', async () => {
  const f = fixture(), challenge = await f.request();
  f.provider.verifyFailure = true;
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_UNKNOWN_OUTCOME', 503));
  f.provider.verifyFailure = false;
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_UNKNOWN_OUTCOME', 503));
  assert.equal((await row(challenge.challengeId)).state, 'verify_unknown');
  assert.equal(f.provider.verified, 1); assert.equal(f.tokens.calls, 0);
  assert.equal((await db.pool.query('SELECT * FROM auth_identities WHERE issuer=$1', [f.issuer])).rowCount, 0);
});

for (const scope of ['sendPhone', 'sendDevice', 'sendIp', 'sendGlobal'] as const) {
  test(`${scope} sending quota commits atomically before provider dispatch`, async () => {
    const f = fixture({ [scope]: 1 });
    await f.request();
    f.advance(300_001);
    const second = scope === 'sendPhone' ? {} : { phone: SECOND_PHONE, ...(scope === 'sendDevice' ? {} : { deviceId: 'another-device' }) };
    await assert.rejects(f.request(second, scope === 'sendGlobal' ? '192.0.2.2' : IP), failure('OTP_RATE_LIMITED', 429));
    assert.equal(f.provider.sent, 1);
  });
}

test('global quota is not exceeded by simultaneous requests on different phones', async () => {
  const f = fixture({ sendGlobal: 3 });
  const results = await Promise.allSettled(Array.from({ length: 20 }, (_, i) => f.request({
    phone: `+91900000${String(i).padStart(4, '0')}`, deviceId: `device-${i}`,
  })));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 3);
  assert.equal(f.provider.sent, 3);
  for (const rejected of results.filter(result => result.status === 'rejected') as PromiseRejectedResult[]) assert.equal(rejected.reason.code, 'OTP_RATE_LIMITED');
  assert.equal((await db.pool.query('SELECT * FROM otp_challenges WHERE issuer=$1', [f.issuer])).rowCount, 3);
});

test('request IP quota counts idempotent replays and verify quota counts foreign challenges', async () => {
  const f = fixture({ requestIp: 2, verifyIp: 2 }), idempotencyKey = randomUUID();
  const challenge = await f.request({ idempotencyKey });
  await f.request({ idempotencyKey });
  await assert.rejects(f.request({ idempotencyKey }), failure('OTP_RATE_LIMITED', 429));
  await assert.rejects(f.verify(challenge.challengeId, { deviceId: 'foreign' }), failure('OTP_NOT_FOUND', 404));
  await assert.rejects(f.verify(challenge.challengeId, { phone: SECOND_PHONE }), failure('OTP_NOT_FOUND', 404));
  await assert.rejects(f.verify(challenge.challengeId), failure('OTP_RATE_LIMITED', 429));
  assert.equal(f.provider.sent, 1); assert.equal(f.provider.verified, 0);
  assert.equal((await row(challenge.challengeId)).attempts, 0);
});

test('phone, device, IP, request key, OTP and custom token are not stored as raw identity data', async () => {
  const f = fixture(), idempotencyKey = randomUUID(), challenge = await f.request({ idempotencyKey });
  const signedIn = await f.verify(challenge.challengeId);
  const stored = await row(challenge.challengeId);
  for (const value of [PHONE, DEVICE, IP, idempotencyKey, CODE, signedIn.customToken]) assert.ok(!Object.values(stored).includes(value));
  for (const key of ['phone_digest', 'device_digest', 'ip_digest', 'request_key_digest', 'request_fingerprint']) assert.match(stored[key], /^[0-9a-f]{64}$/);
  assert.equal(stored.consent_version, CONSENT); assert.equal(stored.purpose, 'signin');
  assert.equal(stored.user_id, signedIn.userId);
  const identity = (await db.pool.query('SELECT * FROM auth_identities WHERE issuer=$1', [f.issuer])).rows[0];
  assert.match(identity.subject_digest, /^[0-9a-f]{64}$/);
  assert.equal(identity.provider, 'phone:msg91');
  assert.equal(JSON.stringify(identity).includes(PHONE), false);
});

test('accidental HMAC-key rotation fails closed rather than creating a duplicate identity', async () => {
  const f = fixture(), first = await f.request();
  await f.verify(first.challengeId);
  const changed = new OtpChallenges(db, f.provider, f.tokens, { ...f.options, digestKey: randomBytes(32).toString('hex') });
  await assert.rejects(changed.request({ phone: PHONE, deviceId: DEVICE, consentVersion: CONSENT, idempotencyKey: randomUUID() }, IP), failure('OTP_UNAVAILABLE', 503));
  assert.equal((await db.pool.query('SELECT * FROM auth_identities WHERE issuer=$1', [f.issuer])).rowCount, 1);
  assert.equal(f.provider.sent, 1);
});

test('database prevents direct challenge ownership changes and consumed-proof revival', async () => {
  const f = fixture(), challenge = await f.request();
  const pgFailure = (error: unknown) => (error as { code?: string }).code === '23514';
  await assert.rejects(db.pool.query('UPDATE otp_challenges SET phone_digest=$2 WHERE id=$1', [challenge.challengeId, 'f'.repeat(64)]), pgFailure);
  await f.verify(challenge.challengeId);
  await assert.rejects(db.pool.query("UPDATE otp_challenges SET state='sent',user_id=NULL,verified_at=NULL WHERE id=$1", [challenge.challengeId]), pgFailure);
});
