export function coins(ms) {
  if (ms <= 40000) return 0;
  return Math.max(60, Math.ceil(ms / 1000));
}
export function payoutPaise(totalCoins) {
  return Math.round(totalCoins * 50000 / 3600);
}
