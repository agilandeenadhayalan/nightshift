import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { Database } from './db';
import { Config } from './config';
import { Presence } from './presence';
import { requireThat, fields, object, string } from './errors';
export const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');
export interface Actor { id: string; sessionHash: string; }
export class Auth {
  constructor(private readonly db: Database, private readonly presence: Presence, private readonly config: Config) {}
  async login(raw: unknown, ip: string) {
    requireThat(await this.presence.rateLimit(`login:${tokenHash(ip)}`, 20, 60), 429, 'RATE_LIMITED', 'Wait before trying again');
    const body = object(raw); fields(body, ['handle','accessKey','deviceId']);
    const key = string(body.accessKey, 'accessKey', 500);
    requireThat(timingSafeEqual(Buffer.from(tokenHash(key)), Buffer.from(tokenHash(this.config.devAccessKey))), 401, 'INVALID_CREDENTIALS', 'Invalid test credentials');
    const handle = string(body.handle, 'handle'); const device = string(body.deviceId, 'deviceId', 128);
    const result = await this.db.pool.query('SELECT id FROM users WHERE test_handle=$1 AND NOT suspended AND adult_confirmed', [handle]);
    requireThat(result.rowCount, 401, 'INVALID_CREDENTIALS', 'Invalid test credentials');
    const userId = result.rows[0].id;
    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + 12*60*60*1000);
    await this.db.tx(async c => {
      await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE', [userId]);
      const busy = await c.query('SELECT call_id FROM active_participant_claims WHERE user_id=$1', [userId]);
      requireThat(!busy.rowCount, 409, 'CALL_ACTIVE', 'End the active call before signing in on another device');
      await c.query('UPDATE auth_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL', [userId]);
      await c.query('UPDATE users SET desired_online=false WHERE id=$1', [userId]);
      await c.query('INSERT INTO auth_sessions(token_hash,user_id,device_id,expires_at) VALUES($1,$2,$3,$4)', [tokenHash(token),userId,device,expiresAt]);
    });
    await this.presence.clear(userId);
    return { token, userId, expiresAt: expiresAt.toISOString() };
  }
  async authenticate(token?: string): Promise<Actor> {
    requireThat(token && token.length <= 200, 401, 'UNAUTHENTICATED', 'Sign in again');
    const hash = tokenHash(token);
    const { rows } = await this.db.pool.query(`SELECT u.id FROM auth_sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=$1 AND s.revoked_at IS NULL AND s.expires_at>now() AND NOT u.suspended AND u.adult_confirmed`, [hash]);
    requireThat(rows.length, 401, 'UNAUTHENTICATED', 'Sign in again');
    return { id: rows[0].id, sessionHash: hash };
  }
  async logout(actor: Actor) {
    await this.db.pool.query('UPDATE auth_sessions SET revoked_at=now() WHERE token_hash=$1', [actor.sessionHash]);
    await this.db.pool.query('UPDATE users SET desired_online=false WHERE id=$1', [actor.id]);
    await this.presence.clear(actor.id);
  }
}
