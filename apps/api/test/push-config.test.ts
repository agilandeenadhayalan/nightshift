import {test} from 'node:test';
import assert from 'node:assert/strict';
import {resolve} from 'node:path';
import {loadConfig} from '../src/config';
const base={NODE_ENV:'test',DEV_AUTH_ENABLED:'true',DEV_ACCESS_KEY:'synthetic-development-key-123456',DATABASE_URL:'postgresql://unused.invalid/test',REDIS_URL:'redis://unused.invalid',PHONE_AUTH_ENABLED:'true',PHONE_AUTH_PROVIDER:'firebase',FIREBASE_PROJECT_ID:'isolated-push-project',PHONE_AUTH_DIGEST_KEY:'synthetic-phone-digest-key-123456789',PHONE_AUTH_CONSENT_VERSION:'phone-signin-v1',PHONE_AUTH_DAILY_ADMISSION_LIMIT:'10'};
const enabled={...base,FCM_SEND_ENABLED:'true',FCM_PROJECT_ID:'isolated-push-project',FCM_SENDER_CREDENTIALS_FILE:resolve('synthetic-private-credential.json'),FCM_TOKEN_DIGEST_KEY:'synthetic-push-digest-key-123456789',FCM_TOKEN_ENCRYPTION_KEY:'1'.repeat(64)};
test('push is unavailable by default and enabling it requires explicit separate credential and encryption configuration',()=>{
  assert.equal(loadConfig(base).push,undefined);
  assert.throws(()=>loadConfig({...base,FCM_SEND_ENABLED:'true'}));
  const config=loadConfig(enabled).push!;assert.equal(config.projectId,'isolated-push-project');assert.equal(config.packageName,'com.agilandeenadhayalan.nightshift');assert.equal(config.credentialFile,enabled.FCM_SENDER_CREDENTIALS_FILE);
});
test('push rejects project mismatch, relative credentials, weak or reused keys and ambiguous enable flags',()=>{
  for(const patch of [{FCM_SEND_ENABLED:'yes'},{FCM_PROJECT_ID:'another-project'},{FCM_SENDER_CREDENTIALS_FILE:'relative.json'},{FCM_TOKEN_ENCRYPTION_KEY:'short'},{FCM_TOKEN_DIGEST_KEY:'short'},{FCM_TOKEN_DIGEST_KEY:'1'.repeat(64)}])assert.throws(()=>loadConfig({...enabled,...patch}));
  assert.throws(()=>loadConfig({...enabled,PHONE_AUTH_ENABLED:'false'}));
});
