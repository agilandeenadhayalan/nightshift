import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { coins } from '../../../audio/billing.mjs';

// Resolve the package's public exports, just as the CommonJS NestJS build does.
const { testCharge, testEarning, MICRO, TEST_RATE } = createRequire(import.meta.url)('@nightshift/backend-domain');

test('reference-only tariff boundaries and cumulative rounding', () => {
  for (const [ms, expectedCoins] of [[0, 0], [1000, 0], [40000, 0], [40001, 60], [59000, 60], [60000, 60], [60001, 61], [61000, 61], [90000, 90]]) {
    assert.equal(testCharge(ms), expectedCoins * MICRO);
  }
  for (let ms = 0; ms < 600000; ms += 137) {
    assert.ok(Number.isSafeInteger(testCharge(ms)));
    assert.ok(testCharge(ms) >= 0);
  }
});

test('customer charges retain parity with the runnable browser reference', () => {
  for (let ms = 0; ms <= 3600000; ms += 137) {
    assert.equal(testCharge(ms), coins(ms) * MICRO, `duration ${ms}ms`);
  }
  for (const ms of [39999.9, 40000, 40000.1, 59999.9, 60000, 60000.1]) {
    assert.equal(testCharge(ms), coins(ms) * MICRO, `boundary ${ms}ms`);
  }
});

test('illustrative earnings accrue delivered time once, six minutes is 50 rupees', () => {
  assert.equal(testEarning(0), 0);
  assert.equal(testEarning(360000), 5000);
  assert.equal(testEarning(3600000), 50000);
  // Connected time earns independently of the customer's free window and floor.
  assert.equal(testCharge(40000), 0);
  assert.equal(testEarning(40000), 556);
  assert.equal(testEarning(40001), 556);
});

test('illustrative earnings round once at settlement and floor fractional milliseconds', () => {
  assert.equal(testEarning(35), 0);
  assert.equal(testEarning(36), 1);
  assert.equal(testEarning(35.99), 0);
  assert.equal(testEarning(36.99), 1);
  assert.equal(testEarning(108), 2);
  assert.equal(testEarning(36) * 3, 3);
});

test('the shared rate snapshot is immutable and explicitly uses test credits', () => {
  assert.deepEqual(TEST_RATE, {
    id: 'test-audio-v1', coinsPerMinute: 60, microcreditsPerCoin: MICRO,
    microcreditsPerSecond: MICRO, freeThroughSeconds: 40, minimumChargedSeconds: 60,
    listenerPaisePerHour: 50000, testOnly: true,
  });
  assert.ok(Object.isFrozen(TEST_RATE));
  assert.throws(() => { TEST_RATE.coinsPerMinute = 1; }, TypeError);
});
