import test from 'node:test';
import assert from 'node:assert/strict';
import { findings } from './check-secrets.mjs';

test('validation gate rejects a deliberate synthetic key and tracked local data', () => {
  const key = ['-----BEGIN ', 'PRIVATE KEY-----'].join('');
  assert.ok(findings('accidental.txt', key).includes('private key'));
  assert.ok(findings('apps/api/.env', 'placeholder').includes('environment file'));
  assert.ok(findings('audio/nightshift.sqlite', '').includes('database or key material'));
});

test('placeholder environment example is allowed', () => {
  assert.deepEqual(findings('.env.example', 'AGORA_APP_CERTIFICATE=\nDEV_ACCESS_KEY=replace-me'), []);
});
