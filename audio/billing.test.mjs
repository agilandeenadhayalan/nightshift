import test from 'node:test';
import assert from 'node:assert/strict';
import {coins,payoutPaise} from './billing.mjs';
test('first minute threshold and subsequent connected seconds',()=>{
 for(const [ms,want] of [[0,0],[40000,0],[40001,60],[60000,60],[60001,61],[3600000,3600]])assert.equal(coins(ms),want);
});
test('total listener conversion rounds only the cumulative payout',()=>{
 assert.equal(payoutPaise(60),833);
 assert.equal(payoutPaise(3600),50000);
});
