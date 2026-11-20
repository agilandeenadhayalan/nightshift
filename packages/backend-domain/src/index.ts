export const MICRO = 60_000;
export interface TestRate {
  readonly id: 'test-audio-v1' | 'test-video-v1';
  readonly coinsPerMinute: number;
  readonly microcreditsPerCoin: number;
  readonly microcreditsPerSecond: number;
  readonly freeThroughSeconds: number;
  readonly minimumChargedSeconds: number;
  readonly listenerPaisePerHour: number;
  readonly testOnly: true;
}
export const TEST_RATE: TestRate = Object.freeze({ id: 'test-audio-v1', coinsPerMinute: 60,
  microcreditsPerCoin: MICRO, microcreditsPerSecond: MICRO, freeThroughSeconds: 40,
  minimumChargedSeconds: 60, listenerPaisePerHour: 50_000, testOnly: true });
export const TEST_VIDEO_RATE: TestRate = Object.freeze({ ...TEST_RATE,
  id: 'test-video-v1', coinsPerMinute: 120, microcreditsPerSecond: 2 * MICRO });

// Preserve audio/billing.mjs's reference-only test policy; not an approved paid tariff.
export function testCharge(ms: number, rate: TestRate = TEST_RATE): number {
  if (ms <= rate.freeThroughSeconds * 1000) return 0;
  return Math.max(rate.minimumChargedSeconds, Math.ceil(ms / 1000)) * rate.microcreditsPerSecond;
}
export function testEarning(ms: number, rate: TestRate = TEST_RATE): number {
  // Earnings use delivered milliseconds, not the customer's minimum-charge floor.
  return Number((BigInt(Math.floor(ms)) * BigInt(rate.listenerPaisePerHour) + 1_800_000n) / 3_600_000n);
}
