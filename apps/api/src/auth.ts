import { createHash, createHmac, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import { Database } from './db';
import { Config } from './config';
import { Presence } from './presence';
import { requireThat, fields, object, string } from './errors';
import { PhoneAuthentication } from './identity/phone-auth';
export const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');
export interface Actor { id: string; sessionHash: string; identityAuthTime?: number; }
export class Auth {
  constructor(private readonly db: Database, private readonly presence: Presence, private readonly config: Config,
    private readonly phone?: PhoneAuthentication, private readonly clock: () => number = Date.now) {}
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
    const expiresAt = new Date(this.clock() + 12*60*60*1000);
    await this.db.tx(async c => {
      await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE', [userId]);
      const busy = await c.query('SELECT call_id FROM active_participant_claims WHERE user_id=$1', [userId]);
      requireThat(!busy.rowCount, 409, 'CALL_ACTIVE', 'End the active call before signing in on another device');
      await c.query('UPDATE auth_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL', [userId]);
      await c.query('UPDATE devices SET active=false,revoked_at=now() WHERE user_id=$1 AND active', [userId]);
      await c.query('UPDATE users SET desired_online=false WHERE id=$1', [userId]);
      await c.query('INSERT INTO auth_sessions(token_hash,user_id,device_id,expires_at) VALUES($1,$2,$3,$4)', [tokenHash(token),userId,device,expiresAt]);
    });
    await this.presence.clear(userId);
    return { token, userId, expiresAt: expiresAt.toISOString() };
  }
  async exchange(raw: unknown, ip: string) {
    requireThat(this.phone,503,'PHONE_AUTH_UNAVAILABLE','Phone sign-in is not available on this server.');
    const ipDigest=createHmac('sha256',this.config.phoneAuth?.digestKey??this.config.devAccessKey).update(`exchange:${ip}`).digest('hex');
    requireThat(await this.presence.rateLimit(`exchange:${ipDigest}`,60,60),429,'RATE_LIMITED','Wait before trying again.');
    const body=object(raw); fields(body,['idToken','deviceId']);
    const token=string(body.idToken,'idToken',16384), device=string(body.deviceId,'deviceId',128);
    requireThat(device.trim() === device && !/[\x00-\x1f\x7f]/.test(device),400,'INVALID_FIELD','Invalid deviceId');
    const identity=await this.phone.sessionIdentity(token), hash=tokenHash(token);
    const expiresAt=new Date(identity.expiresAt*1000);
    let switchingDevice=false;
    await this.db.tx(async c=>{
      const account=await c.query('SELECT suspended,identity_revoked_before,identity_last_issued_at,identity_last_auth_time FROM users WHERE id=$1 FOR NO KEY UPDATE',[identity.uid]);
      requireThat(account.rows.length && !account.rows[0].suspended,401,'UNAUTHENTICATED','Sign in again.');
      requireThat(account.rows[0].identity_revoked_before===null || identity.authTime>Number(account.rows[0].identity_revoked_before),
        401,'SESSION_REVOKED','Sign in again with a fresh phone verification.');
      const binding=await c.query(`SELECT id FROM auth_identities WHERE user_id=$1 AND provider='phone:msg91'
        AND issuer=$2 AND state='verified' FOR SHARE`,[identity.uid,this.config.phoneAuth!.projectId]);
      requireThat(binding.rows.length,401,'INVALID_ID_TOKEN','Sign in again with a verified identity.');
      // Locking the user serializes device takeover, refresh and revocation.
      const same=await c.query('SELECT * FROM auth_sessions WHERE token_hash=$1',[hash]);
      if(same.rows.length){
        const row=same.rows[0];
        requireThat(row.user_id===identity.uid && row.revoked_at===null && new Date(row.expires_at).getTime()>this.clock(),401,'SESSION_REVOKED','Sign in again.');
        requireThat(row.device_id===device,409,'TOKEN_DEVICE_MISMATCH','This sign-in belongs to another device.');
        return;
      }
      requireThat(account.rows[0].identity_last_issued_at===null || identity.issuedAt>Number(account.rows[0].identity_last_issued_at),
        409,'SESSION_SUPERSEDED','Refresh your identity token before trying again.');
      requireThat(account.rows[0].identity_last_auth_time===null || identity.authTime>=Number(account.rows[0].identity_last_auth_time),
        401,'SESSION_REVOKED','Sign in again with a fresh phone verification.');
      const deviceRow=await c.query('SELECT * FROM devices WHERE user_id=$1 AND device_id=$2',[identity.uid,device]);
      const existing=deviceRow.rows[0];
      requireThat(!existing || identity.issuedAt>Number(existing.last_identity_issued_at),409,'SESSION_SUPERSEDED','Refresh your identity token before trying again.');
      requireThat(!existing?.revoked_at || identity.issuedAt*1000>new Date(existing.revoked_at).getTime(),401,'SESSION_REVOKED','Sign in again with a fresh identity token.');
      const current=await c.query('SELECT device_id FROM devices WHERE user_id=$1 AND active',[identity.uid]);
      switchingDevice=current.rows.length===0 || current.rows[0].device_id!==device;
      requireThat(!switchingDevice || account.rows[0].identity_last_auth_time===null || identity.authTime>Number(account.rows[0].identity_last_auth_time),
        401,'FRESH_SIGN_IN_REQUIRED','Verify your phone again before changing devices.');
      const active=await c.query('SELECT 1 FROM active_participant_claims WHERE user_id=$1',[identity.uid]);
      requireThat(!active.rows.length || !switchingDevice,409,'CALL_ACTIVE','End the active call before signing in on another device.');
      await c.query('UPDATE auth_sessions SET revoked_at=$2 WHERE user_id=$1 AND revoked_at IS NULL',[identity.uid,new Date(this.clock())]);
      await c.query('UPDATE devices SET active=false,updated_at=now() WHERE user_id=$1 AND active',[identity.uid]);
      const deviceRecord=existing?.id??randomUUID();
      await c.query(`INSERT INTO devices(id,user_id,device_id,last_identity_issued_at,last_token_hash)
        VALUES($1,$2,$3,$4,$5) ON CONFLICT(user_id,device_id) DO UPDATE SET
        active=true,last_identity_issued_at=EXCLUDED.last_identity_issued_at,last_token_hash=EXCLUDED.last_token_hash,
        revoked_at=NULL,updated_at=now()`,[deviceRecord,identity.uid,device,identity.issuedAt,hash]);
      await c.query(`INSERT INTO auth_sessions(token_hash,user_id,device_id,expires_at,auth_kind,device_record_id,identity_issued_at)
        VALUES($1,$2,$3,$4,'firebase',$5,$6)`,[hash,identity.uid,device,expiresAt,deviceRecord,identity.issuedAt]);
      await c.query('UPDATE users SET identity_last_issued_at=$2,identity_last_auth_time=$3 WHERE id=$1',[identity.uid,identity.issuedAt,identity.authTime]);
      if(switchingDevice)await c.query('UPDATE users SET desired_online=false WHERE id=$1',[identity.uid]);
    });
    // A same-device refresh must not interrupt its active call or availability.
    if(switchingDevice)await this.presence.clear(identity.uid);
    const account=await this.db.pool.query('SELECT adult_confirmed FROM users WHERE id=$1',[identity.uid]);
    return {token,userId:identity.uid,expiresAt:expiresAt.toISOString(),needsOnboarding:!account.rows[0].adult_confirmed};
  }
  async authenticate(token?: string, allowOnboarding=false): Promise<Actor> {
    requireThat(token && token.length <= 16384, 401, 'UNAUTHENTICATED', 'Sign in again');
    const hash = tokenHash(token);
    const read=()=>this.db.pool.query(`SELECT u.id,u.adult_confirmed,u.identity_revoked_before,s.auth_kind FROM auth_sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=$1 AND s.revoked_at IS NULL AND s.expires_at>$2 AND NOT u.suspended`, [hash,new Date(this.clock())]);
    let { rows } = await read();
    let identityAuthTime:number|undefined;
    requireThat(rows.length, 401, 'UNAUTHENTICATED', 'Sign in again');
    if(rows[0].auth_kind==='firebase'){
      requireThat(this.phone,401,'UNAUTHENTICATED','Sign in again.');
      const identity=await this.phone.sessionIdentity(token);
      identityAuthTime=identity.authTime;
      requireThat(identity.uid===rows[0].id,401,'UNAUTHENTICATED','Sign in again.');
      // Provider verification is asynchronous; do not authorize a session that
      // was revoked locally while the provider lookup was in flight.
      ({rows}=await read());
      requireThat(rows.length,401,'UNAUTHENTICATED','Sign in again.');
      requireThat(rows[0].identity_revoked_before===null || identity.authTime>Number(rows[0].identity_revoked_before),
        401,'SESSION_REVOKED','Sign in again with a fresh phone verification.');
    }
    requireThat(allowOnboarding || rows[0].adult_confirmed,403,'ONBOARDING_REQUIRED','Complete adult onboarding first.');
    return { id: rows[0].id, sessionHash: hash, ...(identityAuthTime===undefined?{}:{identityAuthTime}) };
  }
  async logout(actor: Actor) {
    await this.db.tx(async c=>{
      await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[actor.id]);
      await c.query('UPDATE auth_sessions SET revoked_at=$2 WHERE user_id=$1 AND revoked_at IS NULL',[actor.id,new Date(this.clock())]);
      await c.query(`UPDATE devices SET active=false,revoked_at=$2,updated_at=now()
        WHERE user_id=$1 AND active`,[actor.id,new Date(this.clock())]);
      await c.query('UPDATE users SET desired_online=false,identity_revoked_before=GREATEST(COALESCE(identity_revoked_before,0),$2) WHERE id=$1',
        [actor.id,Math.floor(this.clock()/1000)]);
    });
    await this.presence.clear(actor.id);
  }
}
