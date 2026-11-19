import { createClient } from 'redis';
export class Presence {
  private readonly client;
  constructor(url: string) {
    this.client = createClient({ url, disableOfflineQueue: true, commandOptions: { timeout: 5000 }, socket: { connectTimeout: 5000, reconnectStrategy: retries => Math.min(1000, retries * 100) } });
    // Never log connection URLs; they may contain secrets.
    this.client.on('error', () => {});
  }
  async connect() { await this.client.connect(); }
  async heartbeat(userId: string, sessionHash: string) { await this.client.set(`presence:${userId}`, sessionHash, { EX: 45 }); }
  async clear(userId: string) { await this.client.del(`presence:${userId}`); }
  async isOnline(userId: string) { return Boolean(await this.client.get(`presence:${userId}`)); }
  async online(ids: string[]) {
    if (!ids.length) return [];
    const values = await this.client.mGet(ids.map(id => `presence:${id}`));
    return ids.filter((_, i) => values[i]);
  }
  async rateLimit(key: string, limit: number, seconds: number) {
    const count = await this.client.eval("local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n", {keys:[`limit:${key}`],arguments:[String(seconds)]});
    return Number(count) <= limit;
  }
  async healthy() { return (await this.client.ping()) === 'PONG'; }
  async close() { if (this.client.isOpen) await this.client.quit(); }
}
