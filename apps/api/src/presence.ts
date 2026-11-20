import { createClient } from 'redis';
export class Presence {
  private readonly client;
  constructor(url: string) {
    this.client = createClient({ url, disableOfflineQueue: true, commandOptions: { timeout: 5000 }, socket: { connectTimeout: 5000, reconnectStrategy: retries => Math.min(1000, retries * 100) } });
    // Never log connection URLs; they may contain secrets.
    this.client.on('error', () => {});
  }
  async connect(timeoutMs = 6000) {
    if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 6000) throw new Error('Invalid Redis startup deadline');
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      await Promise.race([this.client.connect(), new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('Presence is unavailable')), timeoutMs);
      })]);
    } catch {
      // A wrong startup address must not leave an endless reconnect task alive.
      if (this.client.isOpen) this.client.destroy();
      throw new Error('Presence is unavailable');
    } finally { if (timer) clearTimeout(timer); }
  }
  private version(value: string) {
    if (!/^(0|[1-9]\d*)$/.test(value)) throw new Error('Invalid presence version');
    return value;
  }
  async heartbeat(userId: string, version: string) {
    // Compare decimal strings without Lua floating-point rounding of bigint.
    // A lease can outlive a delayed sender, but cannot replace a newer intent.
    return Number(await this.client.eval(`local old=redis.call('GET',KEYS[1]); local next=ARGV[1]
      if old and (not string.match(old,'^%d+$') or (string.len(old)>1 and string.sub(old,1,1)=='0')) then old=nil end
      if old and (string.len(old)>string.len(next) or (string.len(old)==string.len(next) and old>next)) then return 0 end
      redis.call('SET',KEYS[1],next,'EX',45); return 1`,
    {keys:[`presence:${userId}`],arguments:[this.version(version)]})) === 1;
  }
  async clear(userId: string, throughVersion?: string) {
    // Unconditional deletion is reserved for isolated test/maintenance cleanup.
    // Runtime callers always supply the durable transition's version.
    if (throughVersion === undefined) { await this.client.del(`presence:${userId}`); return; }
    await this.client.eval(`local old=redis.call('GET',KEYS[1]); local upto=ARGV[1]
      if old and (not string.match(old,'^%d+$') or (string.len(old)>1 and string.sub(old,1,1)=='0')) then return redis.call('DEL',KEYS[1]) end
      if old and (string.len(old)<string.len(upto) or (string.len(old)==string.len(upto) and old<=upto)) then return redis.call('DEL',KEYS[1]) end
      return 0`,{keys:[`presence:${userId}`],arguments:[this.version(throughVersion)]});
  }
  async isOnline(userId: string, version?: string) {
    const value = await this.client.get(`presence:${userId}`);
    return version === undefined ? value !== null : value === this.version(version);
  }
  async online(ids: string[], versions: ReadonlyMap<string,string>) {
    if (!ids.length) return [];
    const values = await this.client.mGet(ids.map(id => `presence:${id}`));
    return ids.filter((id, i) => values[i] !== null && values[i] === versions.get(id));
  }
  async rateLimit(key: string, limit: number, seconds: number) {
    const count = await this.client.eval("local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n", {keys:[`limit:${key}`],arguments:[String(seconds)]});
    return Number(count) <= limit;
  }
  async healthy() { return (await this.client.ping()) === 'PONG'; }
  async close() { if (this.client.isOpen) await this.client.quit(); }
}
