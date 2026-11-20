import 'reflect-metadata';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { seed } from '../src/seed';
import { loadConfig } from '../src/config';
import { createApplication } from '../src/http';
import { Actor } from '../src/auth';
import { MICRO, TEST_RATE } from '@nightshift/backend-domain';

let runtime: Awaited<ReturnType<typeof createApplication>>, admin: Database;
let customer: Actor, listener: Actor, outsider: Actor, customerToken: string;
let now = Date.now(), base: string;
const schema = `video_${randomUUID().replaceAll('-', '')}`;
const idem = () => randomUUID();
before(async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Video tests require a dedicated TEST_DATABASE_URL');
  admin = new Database(process.env.TEST_DATABASE_URL!);
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  const url = new URL(process.env.TEST_DATABASE_URL!);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  const config = loadConfig({...process.env, NODE_ENV: 'test', DATABASE_URL: url.toString(),
    VIDEO_CALLS_ENABLED: 'true', AGORA_APP_ID: 'a'.repeat(32), AGORA_APP_CERTIFICATE: 'b'.repeat(32)});
  const db = new Database(config.databaseUrl);
  await migrate(db); await seed(db); await seed(db); await db.close();
  runtime = await createApplication(config, () => now);
  await runtime.app.listen(0, '127.0.0.1'); base = await runtime.app.getUrl();
  for (const handle of ['customer', 'listener', 'customer2']) {
    const login = await runtime.auth.login({handle, accessKey: config.devAccessKey, deviceId: `video-${handle}`}, schema);
    const actor = await runtime.auth.authenticate(login.token);
    if (handle === 'customer') { customer = actor; customerToken = login.token; }
    else if (handle === 'listener') listener = actor;
    else outsider = actor;
  }
});
after(async () => {
  if (runtime) await runtime.close();
  if (admin) { await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.close(); }
});
const videoBody = () => ({listenerId: listener.id, quoteId: 'test-video-v1', mediaType: 'video', videoConsent: true});
async function inviteVideo() {
  await runtime.service.availability(listener, {online: true});
  return runtime.service.createCall(customer, videoBody(), idem());
}
async function end(id: string) {
  const call = await runtime.service.call(customer.id, id);
  return runtime.service.action(customer, id, 'end', {expectedVersion: call.version}, idem());
}
async function videoReady(id: string, actor = customer) {
  await runtime.service.media(actor, id, {ready: true, videoReady: true});
  await runtime.service.media(listener, id, {ready: true, videoReady: true});
}
async function request(endpoint: string, token?: string) {
  const response = await fetch(`${base}/v1/${endpoint}`, {headers: token ? {Authorization: `Bearer ${token}`} : {}});
  return {status: response.status, body: await response.json() as any};
}

test('video preflight config is authenticated, explicitly gated and contains no certificate or token', async () => {
  assert.equal((await request('rtc/config')).status, 401);
  const enabled = await request('rtc/config', customerToken);
  assert.equal(enabled.status, 200);
  assert.deepEqual(enabled.body, {appId: 'a'.repeat(32), videoEnabled: true, testOnly: true});
  const config = runtime.service.config as unknown as {videoCallsEnabled: boolean; agoraAppCertificate?: string};
  config.videoCallsEnabled = false;
  assert.deepEqual((await request('rtc/config', customerToken)).body, {appId: null, videoEnabled: false, testOnly: true});
  await runtime.service.availability(listener, {online: true});
  await assert.rejects(() => runtime.service.createCall(customer, videoBody(), idem()), {code: 'VIDEO_UNAVAILABLE'});
  assert.equal((await runtime.service.listeners(customer.id)).items[0]?.videoRate, null);
  config.videoCallsEnabled = true;
  const certificate = config.agoraAppCertificate;
  config.agoraAppCertificate = undefined;
  assert.deepEqual((await request('rtc/config', customerToken)).body, {appId: null, videoEnabled: false, testOnly: true});
  config.agoraAppCertificate = certificate;
  assert.equal((await runtime.service.listeners(customer.id)).items[0]?.videoRate?.id, 'test-video-v1');
});

test('video requires both explicit consents, the matching quote and participant-only RTC access', async () => {
  await runtime.service.availability(listener, {online: true});
  await assert.rejects(() => runtime.service.createCall(customer, {...videoBody(), videoConsent: false}, idem()), {code: 'VIDEO_CONSENT_REQUIRED'});
  await assert.rejects(() => runtime.service.createCall(customer, {...videoBody(), quoteId: 'test-audio-v1'}, idem()), {code: 'QUOTE_EXPIRED'});
  const call = await inviteVideo();
  assert.equal(call.mediaType, 'video'); assert.equal(call.rate.id, 'test-video-v1');
  await assert.rejects(() => runtime.service.rtcToken(customer, call.id), {code: 'CALL_NOT_ACTIVE'});
  await assert.rejects(() => runtime.service.action(listener, call.id, 'accept', {expectedVersion: call.version}, idem()), {code: 'VIDEO_CONSENT_REQUIRED'});
  const accepted = await runtime.service.action(listener, call.id, 'accept', {expectedVersion: call.version, videoConsent: true}, idem());
  assert.equal(accepted.state, 'connecting');
  await assert.rejects(() => runtime.service.rtcToken(outsider, call.id), {code: 'CALL_NOT_FOUND'});
  assert.equal((await runtime.service.rtcToken(customer, call.id)).mediaType, 'video');
  const consents = (await runtime.db.pool.query('SELECT customer_video_consent_at,listener_video_consent_at FROM call_sessions WHERE id=$1', [call.id])).rows[0];
  assert.ok(consents.customer_video_consent_at); assert.ok(consents.listener_video_consent_at);
  await end(call.id);
  await assert.rejects(() => runtime.service.rtcToken(customer, call.id), {code: 'CALL_NOT_ACTIVE'});
});

test('audio and video reserve the same participants and legacy audio requests stay unchanged', async () => {
  await runtime.service.availability(listener, {online: true});
  const results = await Promise.allSettled([
    runtime.service.createCall(customer, {listenerId: listener.id, quoteId: 'test-audio-v1'}, idem()),
    runtime.service.createCall(customer, videoBody(), idem()),
  ]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const won = (results.find(result => result.status === 'fulfilled') as PromiseFulfilledResult<any>).value;
  const lost = results.find(result => result.status === 'rejected') as PromiseRejectedResult;
  assert.equal(lost.reason.code, 'LISTENER_BUSY'); await end(won.id);
  const audio = await runtime.service.createCall(customer, {listenerId: listener.id, quoteId: 'test-audio-v1'}, idem());
  assert.equal(audio.mediaType, 'audio'); assert.equal(audio.rate.id, 'test-audio-v1');
  await runtime.service.action(listener, audio.id, 'accept', {expectedVersion: audio.version}, idem());
  await runtime.service.media(customer, audio.id, {ready: true});
  await runtime.service.media(listener, audio.id, {ready: true});
  assert.equal((await runtime.service.call(customer.id, audio.id)).state, 'connected'); await end(audio.id);
});

test('video requires camera readiness and pauses billing during a camera gap before balanced single settlement', async () => {
  const call = await inviteVideo();
  await runtime.service.action(listener, call.id, 'accept', {expectedVersion: call.version, videoConsent: true}, idem());
  await assert.rejects(() => runtime.service.media(customer, call.id, {ready: true}), {code: 'VIDEO_READINESS_REQUIRED'});
  await assert.rejects(() => runtime.service.media(customer, call.id, {ready: true, videoReady: true, elapsedMs: 600000}), {code: 'INVALID_FIELD'});
  await runtime.service.media(customer, call.id, {ready: true, videoReady: false});
  await runtime.service.media(listener, call.id, {ready: true, videoReady: true});
  assert.equal((await runtime.service.call(customer.id, call.id)).connectedMs, 0);
  await videoReady(call.id);
  for (let second = 0; second < 41; second++) { now += 1000; await videoReady(call.id); }
  const beforeGap = await runtime.service.call(customer.id, call.id);
  assert.equal(beforeGap.chargeMicrocredits, 120 * MICRO);
  await runtime.service.media(customer, call.id, {ready: true, videoReady: false});
  now += 10000; await runtime.service.recover();
  assert.equal((await runtime.service.call(customer.id, call.id)).connectedMs, beforeGap.connectedMs);
  await videoReady(call.id);
  for (let second = 0; second < 20; second++) { now += 1000; await videoReady(call.id); }
  const ended = await end(call.id); await end(call.id);
  assert.equal(ended.connectedMs, 61000); assert.equal(ended.chargeMicrocredits, 122 * MICRO);
  const journal = await runtime.db.pool.query('SELECT b.id,count(l.id)::int lines,sum(l.amount)::text total FROM journal_batches b JOIN journal_lines l ON l.batch_id=b.id WHERE b.call_id=$1 GROUP BY b.id', [call.id]);
  assert.equal(journal.rows.length, 2); assert.ok(journal.rows.every(row => row.lines === 2 && row.total === '0'));
  assert.equal((await runtime.db.pool.query('SELECT count(*)::int total FROM active_participant_claims WHERE call_id=$1', [call.id])).rows[0].total, 0);
  assert.ok((await runtime.db.pool.query('SELECT released_at FROM spend_holds WHERE call_id=$1', [call.id])).rows[0].released_at);
});

test('video rate and consent terms cannot change in place and old Call event JSON still validates', async () => {
  const call = await inviteVideo();
  for (const sql of ["UPDATE call_sessions SET media_type='audio' WHERE id=$1", "UPDATE call_sessions SET rate_snapshot='{}' WHERE id=$1", "UPDATE call_sessions SET customer_video_consent_at=NULL WHERE id=$1"]) {
    await assert.rejects(runtime.db.pool.query(sql, [call.id]), {code: '23514'});
  }
  await end(call.id);
  const legacy = {...call, rate: TEST_RATE} as Record<string, unknown>; delete legacy.mediaType;
  const contract = JSON.parse(await readFile(path.resolve(__dirname, '../../../../packages/contracts/openapi.json'), 'utf8'));
  const definitions = JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/', '#/$defs/'));
  const ajv = new Ajv({strict: false}); addFormats(ajv);
  const validate = ajv.compile({$defs: definitions, $ref: '#/$defs/Call'});
  assert.equal(validate(legacy), true, JSON.stringify(validate.errors));
});

test('video spend authorization uses the video rate and cannot overspend the final 120 coins', async () => {
  const wallet = await runtime.service.wallet(outsider.id);
  const drain = wallet.balanceMicrocredits - 120 * MICRO;
  await runtime.db.tx(async c => {
    const batch = `video-drain:${idem()}`;
    await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'test-fixture')", [batch]);
    await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,$3),($1,$4,$5)',
      [batch, `customer:${outsider.id}`, -drain, 'platform:test', drain]);
  });
  await runtime.service.availability(listener, {online: true});
  const call = await runtime.service.createCall(outsider, videoBody(), idem());
  assert.equal(call.maxDurationSeconds, 60);
  assert.equal((await runtime.db.pool.query('SELECT amount FROM spend_holds WHERE call_id=$1', [call.id])).rows[0].amount, String(120 * MICRO));
  await runtime.service.action(listener, call.id, 'accept', {expectedVersion: call.version, videoConsent: true}, idem());
  await videoReady(call.id, outsider);
  for (let second = 0; second < 60; second++) { now += 1000; await videoReady(call.id, outsider); }
  const ended = await runtime.service.call(outsider.id, call.id);
  assert.equal(ended.state, 'ended'); assert.equal(ended.reason, 'test_credit_limit');
  assert.equal(ended.chargeMicrocredits, 120 * MICRO);
  assert.equal((await runtime.service.wallet(outsider.id)).availableMicrocredits, 0);
  await assert.rejects(() => runtime.service.createCall(outsider, videoBody(), idem()), {code: 'INSUFFICIENT_BALANCE'});
});

test('turning off private video ends an existing call and releases its claims', async () => {
  const call = await inviteVideo();
  await runtime.service.action(listener, call.id, 'accept', {expectedVersion: call.version, videoConsent: true}, idem());
  await videoReady(call.id);
  const config = runtime.service.config as unknown as {videoCallsEnabled: boolean};
  config.videoCallsEnabled = false;
  try {
    await runtime.service.recover();
    const ended = await runtime.service.call(customer.id, call.id);
    assert.equal(ended.state, 'ended'); assert.equal(ended.reason, 'video_unavailable');
    assert.equal(ended.chargeMicrocredits, 0);
    assert.equal((await runtime.db.pool.query('SELECT count(*)::int total FROM active_participant_claims WHERE call_id=$1', [call.id])).rows[0].total, 0);
    await assert.rejects(() => runtime.service.rtcToken(customer, call.id), {code: 'CALL_NOT_ACTIVE'});
  } finally { config.videoCallsEnabled = true; }
});
