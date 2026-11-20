import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config';
import { fields, uuid } from '../src/errors';

test('production cannot boot fictional authentication even with a valid key',()=>{
  const env={NODE_ENV:'production',DEV_AUTH_ENABLED:'true',DEV_ACCESS_KEY:'x'.repeat(32),DATABASE_URL:'postgres://localhost/test',REDIS_URL:'redis://localhost'};
  assert.throws(()=>loadConfig(env),/PRODUCTION_NOT_READY/);
  assert.throws(()=>loadConfig({...env,NODE_ENV:'development',DEV_AUTH_ENABLED:'false'}),/DEV_AUTH_ENABLED/);
  assert.throws(()=>loadConfig({...env,NODE_ENV:'test',DEV_ACCESS_KEY:'short'}),/DEV_ACCESS_KEY/);
});
test('unknown client billing/role fields and invalid IDs are rejected',()=>{
  assert.throws(()=>fields({ready:true,elapsedMs:10000},['ready']),/unsupported/);
  assert.throws(()=>uuid('bad-id'),/Invalid/);
});

const localEnv = { NODE_ENV: 'test', DEV_AUTH_ENABLED: 'true', DEV_ACCESS_KEY: 'x'.repeat(32),
  DATABASE_URL: 'postgres://localhost/test', REDIS_URL: 'redis://localhost' };

test('private video requires an explicit boolean flag and never bypasses production refusal', () => {
  const videoFlag = (env: NodeJS.ProcessEnv) => (loadConfig(env) as unknown as {videoCallsEnabled: boolean}).videoCallsEnabled;
  assert.equal(videoFlag(localEnv), false);
  assert.equal(videoFlag({...localEnv, VIDEO_CALLS_ENABLED: 'false'}), false);
  assert.equal(videoFlag({...localEnv, VIDEO_CALLS_ENABLED: 'true'}), true);
  assert.throws(() => loadConfig({...localEnv, VIDEO_CALLS_ENABLED: 'yes'}), /VIDEO_CALLS_ENABLED/);
  assert.throws(() => loadConfig({...localEnv, NODE_ENV: 'production', VIDEO_CALLS_ENABLED: 'true'}), /PRODUCTION_NOT_READY/);
});
const phoneEnv = { ...localEnv, PHONE_AUTH_ENABLED: 'true', FIREBASE_PROJECT_ID: 'nightshift-fixture',
  PHONE_AUTH_DIGEST_KEY: 'test-fixture-only-'.repeat(3), PHONE_AUTH_CONSENT_VERSION: 'signin-v1',
  MSG91_WIDGET_ID: 'fixture-widget', MSG91_AUTH_KEY: 'fixture-auth-key-only', PHONE_AUTH_DAILY_SEND_LIMIT: '10' };

test('phone identity is off unless explicitly configured and never enables production', () => {
  assert.equal(loadConfig(localEnv).phoneAuth, undefined);
  assert.equal(loadConfig({ ...phoneEnv, PHONE_AUTH_ENABLED: 'false' }).phoneAuth, undefined);
  assert.equal(loadConfig(phoneEnv).phoneAuth?.projectId, 'nightshift-fixture');
  assert.throws(() => loadConfig({ ...phoneEnv, NODE_ENV: 'production' }), /PRODUCTION_NOT_READY/);
  assert.throws(() => loadConfig({ ...localEnv, PHONE_AUTH_ENABLED: 'yes' }), /PHONE_AUTH_ENABLED/);
});

test('phone validation requires complete config and rejects emulator bypass', () => {
  for (const key of ['FIREBASE_PROJECT_ID', 'PHONE_AUTH_DIGEST_KEY', 'PHONE_AUTH_CONSENT_VERSION', 'MSG91_WIDGET_ID', 'MSG91_AUTH_KEY', 'PHONE_AUTH_DAILY_SEND_LIMIT']) {
    assert.throws(() => loadConfig({ ...phoneEnv, [key]: '' }), /requires valid/);
  }
  assert.throws(() => loadConfig({ ...phoneEnv, FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099' }), /cannot use/);
  assert.throws(() => loadConfig({ ...phoneEnv, FIREBASE_AUTH_EMULATOR_HOST: '' }), /cannot use/);
  for (const limit of ['0', '-1', 'NaN', '1001', '1.5']) {
    assert.throws(() => loadConfig({ ...phoneEnv, PHONE_AUTH_DAILY_SEND_LIMIT: limit }), /requires valid/);
  }
  assert.throws(() => loadConfig({ ...phoneEnv, FIREBASE_PROJECT_ID: 'wrong project' }), /requires valid/);
});
