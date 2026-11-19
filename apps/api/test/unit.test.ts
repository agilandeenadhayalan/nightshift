import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config';
import { testCharge, testEarning, MICRO } from '../src/billing';
import { fields, uuid } from '../src/errors';

test('reference-only tariff boundaries and cumulative rounding',()=>{
  for(const [ms,coins] of [[0,0],[1000,0],[40000,0],[40001,60],[59000,60],[60000,60],[60001,61],[61000,61],[90000,90]])
    assert.equal(testCharge(ms!),coins!*MICRO);
  for(let ms=0;ms<600000;ms+=137){assert.ok(Number.isSafeInteger(testCharge(ms)));assert.ok(testCharge(ms)>=0);}
});
test('illustrative earnings accrue delivered time once, six minutes is 50 rupees',()=>{
  assert.equal(testEarning(0),0);assert.equal(testEarning(360000),5000);assert.equal(testEarning(3600000),50000);
});
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
