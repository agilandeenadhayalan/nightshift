import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const { TEST_RATE, TEST_VIDEO_RATE, MICRO, testCharge, testEarning } =
  createRequire(import.meta.url)('@nightshift/backend-domain');

test('video is a distinct immutable test rate and preserves audio billing', () => {
  assert.ok(TEST_VIDEO_RATE, 'A separately versioned video rate is required');
  assert.equal(TEST_VIDEO_RATE.id, 'test-video-v1');
  assert.equal(TEST_VIDEO_RATE.coinsPerMinute, 120);
  assert.equal(TEST_VIDEO_RATE.microcreditsPerSecond, 2 * MICRO);
  assert.equal(TEST_VIDEO_RATE.testOnly, true);
  assert.ok(Object.isFrozen(TEST_VIDEO_RATE));
  assert.throws(() => { TEST_VIDEO_RATE.coinsPerMinute = 60; }, TypeError);
  for (const [ms, coins] of [[0, 0], [40000, 0], [40001, 120], [60000, 120], [60001, 122], [61000, 122], [600000, 1200]]) {
    assert.equal(testCharge(ms, TEST_VIDEO_RATE), coins * MICRO);
    assert.equal(testCharge(ms), testCharge(ms, TEST_RATE));
    assert.equal(testCharge(ms, TEST_VIDEO_RATE), 2 * testCharge(ms));
  }
});

test('video illustrative earnings stay fixed-point and independent of the doubled customer price', () => {
  assert.ok(TEST_VIDEO_RATE);
  assert.equal(testEarning(360000, TEST_VIDEO_RATE), 5000);
  assert.equal(testEarning(40000, TEST_VIDEO_RATE), 556);
  assert.equal(testEarning(35, TEST_VIDEO_RATE), 0);
  assert.equal(testEarning(36, TEST_VIDEO_RATE), 1);
});
