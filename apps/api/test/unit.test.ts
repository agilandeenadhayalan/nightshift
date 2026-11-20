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
