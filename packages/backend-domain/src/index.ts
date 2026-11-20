export const MICRO = 60_000;
export const TEST_RATE = Object.freeze({ id: 'test-audio-v1', coinsPerMinute: 60,
  microcreditsPerCoin: MICRO, microcreditsPerSecond: MICRO, freeThroughSeconds: 40,
  minimumChargedSeconds: 60, listenerPaisePerHour: 50_000, testOnly: true });

// Preserve audio/billing.mjs's reference-only test policy; not an approved paid tariff.
export function testCharge(ms: number): number {
  if (ms <= 40_000) return 0;
  return Math.max(60, Math.ceil(ms / 1000)) * MICRO;
}
export function testEarning(ms: number): number {
  // Earnings use delivered milliseconds, not the customer's minimum-charge floor.
  return Number((BigInt(Math.floor(ms)) * 50_000n + 1_800_000n) / 3_600_000n);
}
