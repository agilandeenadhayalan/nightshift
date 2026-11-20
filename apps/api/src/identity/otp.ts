import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { PoolClient } from 'pg';
import { Database } from '../db';
import { ApiError, fields, object, requireThat, string, uuid } from '../errors';

export interface OtpProvider {
  send(phone: string): Promise<{ reference: string }>;
  verify(phone: string, code: string, reference: string): Promise<'valid' | 'wrong' | 'expired'>;
}
export interface CustomTokenIssuer { createCustomToken(uid: string): Promise<string>; }
export type OtpChallengeState = 'sending' | 'sent' | 'verifying' | 'consumed' | 'expired' | 'locked' |
  'send_unknown' | 'verify_unknown' | 'superseded';
export interface OtpChallengeView { challengeId: string; state: OtpChallengeState; expiresAt: string; retryAt: string; }
export interface OtpLimits {
  requestIp: number; verifyIp: number; sendPhone: number; sendDevice: number; sendIp: number; sendGlobal: number;
}
export interface OtpOptions {
  digestKey: string; issuer: string; consentVersion: string; limits?: Partial<OtpLimits>;
  providerTimeoutMs?: number;
}
export class OtpFailure extends ApiError {
  constructor(status: number, code: string, message: string, public readonly retryAfterSeconds?: number) {
    super(status, code, message);
  }
}
type ChallengeRow = {
  id: string; issuer: string; phone_digest: string; device_digest: string; request_fingerprint: string;
  provider_reference: string | null; state: OtpChallengeState; attempts: number;
  created_at: Date; expires_at: Date; retry_at: Date;
};
const LIFE_MS = 300_000, COOLDOWN_MS = 60_000;
const ACTIVE = ['sending', 'sent', 'verifying', 'send_unknown', 'verify_unknown'];
const DEFAULT_LIMITS: OtpLimits = { requestIp: 120, verifyIp: 60, sendPhone: 3, sendDevice: 10, sendIp: 20, sendGlobal: 100 };

export function normalizeIndianPhone(value: unknown): string {
  const input = string(value, 'phone', 32).trim().replace(/[ -]/g, '');
  const phone = /^[6-9][0-9]{9}$/.test(input) ? `+91${input}` : /^91[6-9][0-9]{9}$/.test(input) ? `+${input}` : input;
  requireThat(/^\+91[6-9][0-9]{9}$/.test(phone), 400, 'OTP_INVALID_PHONE', 'Enter a valid Indian mobile number.');
  return phone;
}

/** Durable proof lifecycle. This service never grants an app role, adult status, wallet or session. */
export class OtpChallenges {
  #digestKey: Buffer;
  private readonly issuer: string;
  private readonly consentVersion: string;
  private readonly limits: OtpLimits;
  private readonly timeoutMs: number;
  constructor(private readonly db: Database, private readonly provider: OtpProvider,
    private readonly tokenIssuer: CustomTokenIssuer, options: OtpOptions, private readonly clock: () => number = Date.now) {
    requireThat(Buffer.byteLength(options.digestKey ?? '') >= 32, 503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
    requireThat(typeof options.issuer === 'string' && options.issuer.length > 0 && options.issuer.length <= 256,
      503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
    requireThat(typeof options.consentVersion === 'string' && /^[A-Za-z0-9._:-]{1,100}$/.test(options.consentVersion),
      503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
    this.#digestKey = Buffer.from(options.digestKey);
    this.issuer = options.issuer;
    this.consentVersion = options.consentVersion;
    this.limits = { ...DEFAULT_LIMITS, ...options.limits };
    requireThat(Object.values(this.limits).every(n => Number.isSafeInteger(n) && n > 0 && n <= 100_000),
      503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
    this.timeoutMs = options.providerTimeoutMs ?? 8000;
    requireThat(Number.isInteger(this.timeoutMs) && this.timeoutMs > 0 && this.timeoutMs <= 10_000,
      503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
  }

  async request(raw: unknown, ip: string): Promise<OtpChallengeView> {
    // This separate committed budget applies even to idempotent replays and invalid form bodies.
    await this.requestBudget('request_ip', ip, this.limits.requestIp);
    const body = object(raw); fields(body, ['phone', 'deviceId', 'consentVersion', 'idempotencyKey']);
    const phone = normalizeIndianPhone(body.phone);
    const device = string(body.deviceId, 'deviceId', 128), key = string(body.idempotencyKey, 'idempotencyKey', 128);
    requireThat(body.consentVersion === this.consentVersion, 400, 'OTP_INVALID_CONSENT', 'Accept the current phone sign-in consent.');
    const phoneDigest = this.digest('phone', phone), deviceDigest = this.digest('device', device);
    const keyDigest = this.digest('request', key), ipDigest = this.digest('ip', ip);
    const fingerprint = this.digest('fingerprint', JSON.stringify([phoneDigest, deviceDigest, this.consentVersion]));
    const now = this.clock();
    const reserved = await this.db.tx(async c => {
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [`otp-request:${this.issuer}:${deviceDigest}:${keyDigest}`]);
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [`otp:${this.issuer}:${phoneDigest}`]);
      const replay = await c.query<ChallengeRow>(`SELECT * FROM otp_challenges WHERE issuer=$1 AND device_digest=$2 AND request_key_digest=$3`,
        [this.issuer, deviceDigest, keyDigest]);
      if (replay.rowCount) {
        requireThat(replay.rows[0]!.request_fingerprint === fingerprint, 409, 'IDEMPOTENCY_CONFLICT', 'Use a new request key for changed sign-in details.');
        if (replay.rows[0]!.expires_at.getTime() <= now && ACTIVE.includes(replay.rows[0]!.state)) {
          const expired = await c.query<ChallengeRow>("UPDATE otp_challenges SET state='expired' WHERE id=$1 RETURNING *", [replay.rows[0]!.id]);
          return { row: expired.rows[0]!, send: false };
        }
        return { row: replay.rows[0]!, send: false };
      }
      await c.query(`UPDATE otp_challenges SET state='expired' WHERE issuer=$1 AND phone_digest=$2
        AND state=ANY($3::text[]) AND expires_at<=$4`, [this.issuer, phoneDigest, ACTIVE, new Date(now)]);
      const recent = await c.query<ChallengeRow>(`SELECT * FROM otp_challenges WHERE issuer=$1 AND phone_digest=$2 AND expires_at>$3
        AND state NOT IN ('expired','superseded') ORDER BY created_at DESC FOR UPDATE`, [this.issuer, phoneDigest, new Date(now)]);
      for (const row of recent.rows) {
        if (['consumed', 'locked', 'send_unknown', 'verify_unknown'].includes(row.state)) {
          throw new OtpFailure(429, 'OTP_COOLDOWN', 'Wait before requesting a new code.', this.secondsUntil(row.expires_at));
        }
        if (row.state === 'sending' || row.state === 'verifying') {
          throw new OtpFailure(409, 'OTP_IN_PROGRESS', 'The previous sign-in operation is still pending.', this.secondsUntil(row.expires_at));
        }
        if (row.retry_at.getTime() > now) {
          throw new OtpFailure(429, 'OTP_COOLDOWN', 'Wait before requesting a new code.', this.secondsUntil(row.retry_at));
        }
        await c.query("UPDATE otp_challenges SET state='superseded' WHERE id=$1 AND state='sent'", [row.id]);
      }
      await this.budget(c, 'send_phone', phoneDigest, this.limits.sendPhone, 3_600_000, now);
      await this.budget(c, 'send_device', deviceDigest, this.limits.sendDevice, 3_600_000, now);
      await this.budget(c, 'send_ip', ipDigest, this.limits.sendIp, 3_600_000, now);
      await this.budget(c, 'send_global', this.digest('global', 'send'), this.limits.sendGlobal, 86_400_000, now);
      const result = await c.query<ChallengeRow>(`INSERT INTO otp_challenges(id,issuer,consent_version,phone_digest,device_digest,ip_digest,
        request_key_digest,request_fingerprint,created_at,expires_at,retry_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
      [randomUUID(), this.issuer, this.consentVersion, phoneDigest, deviceDigest, ipDigest, keyDigest, fingerprint,
        new Date(now), new Date(now + LIFE_MS), new Date(now + COOLDOWN_MS)]);
      return { row: result.rows[0]!, send: true };
    });
    if (!reserved.send) return this.view(reserved.row);
    let reference: string;
    try {
      const sent = await this.deadline(this.provider.send(phone));
      requireThat(typeof sent?.reference === 'string' && /^[A-Za-z0-9._:-]{1,256}$/.test(sent.reference)
        && !sent.reference.includes(phone.slice(1)) && !sent.reference.includes(phone.slice(3)), 503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
      reference = sent.reference;
    } catch {
      await this.db.pool.query("UPDATE otp_challenges SET state='send_unknown' WHERE id=$1 AND state='sending'", [reserved.row.id]);
      return this.readView(reserved.row.id);
    }
    await this.db.pool.query(`UPDATE otp_challenges SET state=CASE WHEN expires_at>$2 THEN 'sent' ELSE 'expired' END,
      provider_reference=$3 WHERE id=$1 AND state='sending'`, [reserved.row.id, new Date(this.clock()), reference]);
    return this.readView(reserved.row.id);
  }

  async verify(raw: unknown, ip: string): Promise<{ customToken: string; userId: string; needsOnboarding: boolean }> {
    await this.requestBudget('verify_ip', ip, this.limits.verifyIp);
    const body = object(raw); fields(body, ['challengeId', 'phone', 'code', 'deviceId']);
    const id = uuid(body.challengeId), phone = normalizeIndianPhone(body.phone), device = string(body.deviceId, 'deviceId', 128);
    const code = string(body.code, 'code', 6);
    requireThat(/^[0-9]{6}$/.test(code), 400, 'OTP_INVALID_CODE', 'Enter the six-digit verification code.');
    const phoneDigest = this.digest('phone', phone), deviceDigest = this.digest('device', device);
    const claimed = await this.db.tx(async c => {
      const result = await c.query<ChallengeRow>(`SELECT * FROM otp_challenges WHERE id=$1 AND issuer=$2 AND phone_digest=$3 AND device_digest=$4 FOR UPDATE`,
        [id, this.issuer, phoneDigest, deviceDigest]);
      if (!result.rowCount) throw new OtpFailure(404, 'OTP_NOT_FOUND', 'This sign-in request is unavailable.');
      const row = result.rows[0]!;
      const failure = this.stateFailure(row);
      if (failure) {
        if (row.expires_at.getTime() <= this.clock() && ACTIVE.includes(row.state)) await c.query("UPDATE otp_challenges SET state='expired' WHERE id=$1", [id]);
        return { failure };
      }
      const changed = await c.query<ChallengeRow>("UPDATE otp_challenges SET state='verifying',attempts=attempts+1 WHERE id=$1 RETURNING *", [id]);
      return { row: changed.rows[0]! };
    });
    if (claimed.failure) throw claimed.failure;
    const row = claimed.row!;
    let outcome: 'valid' | 'wrong' | 'expired';
    try {
      outcome = await this.deadline(this.provider.verify(phone, code, row.provider_reference!));
      requireThat(['valid', 'wrong', 'expired'].includes(outcome), 503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
    } catch {
      await this.db.pool.query("UPDATE otp_challenges SET state='verify_unknown' WHERE id=$1 AND state='verifying' AND attempts=$2", [id, row.attempts]);
      throw new OtpFailure(503, 'OTP_UNKNOWN_OUTCOME', 'Verification status is unknown. Wait before requesting a new code.', this.secondsUntil(row.expires_at));
    }
    const resolution = await this.db.tx(async c => {
      const current = (await c.query<ChallengeRow>('SELECT * FROM otp_challenges WHERE id=$1 FOR UPDATE', [id])).rows[0];
      requireThat(current, 404, 'OTP_NOT_FOUND', 'This sign-in request is unavailable.');
      if (current.state !== 'verifying' || current.attempts !== row.attempts) {
        return { failure: new OtpFailure(409, 'OTP_CONSUMED', 'This sign-in request is no longer usable.') };
      }
      if (this.clock() >= current.expires_at.getTime() || outcome === 'expired') {
        await c.query("UPDATE otp_challenges SET state='expired' WHERE id=$1", [id]);
        return { failure: new OtpFailure(410, 'OTP_EXPIRED', 'The verification code has expired. Request a new code.') };
      }
      if (outcome === 'wrong') {
        const locked = current.attempts >= 5;
        await c.query('UPDATE otp_challenges SET state=$2 WHERE id=$1', [id, locked ? 'locked' : 'sent']);
        return { failure: new OtpFailure(locked ? 429 : 400, locked ? 'OTP_LOCKED' : 'OTP_INVALID_CODE',
          locked ? 'Too many incorrect codes. Wait before requesting another code.' : 'The verification code is incorrect.', locked ? this.secondsUntil(current.expires_at) : undefined) };
      }
      const verifiedAt = new Date(this.clock());
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [`identity:${this.issuer}:${phoneDigest}`]);
      const identity = await c.query(`SELECT i.user_id,i.state,u.suspended,u.adult_confirmed FROM auth_identities i JOIN users u ON u.id=i.user_id
        WHERE i.provider='phone:msg91' AND i.issuer=$1 AND i.subject_digest=$2 FOR UPDATE OF i,u`, [this.issuer, phoneDigest]);
      let userId: string, restricted = false, needsOnboarding = true;
      if (identity.rowCount) {
        userId = identity.rows[0].user_id;
        restricted = identity.rows[0].state !== 'verified' || identity.rows[0].suspended;
        needsOnboarding = !identity.rows[0].adult_confirmed;
      } else {
        userId = randomUUID();
        await c.query(`INSERT INTO users(id,display_name,mode,listener_approved,adult_confirmed,desired_online,created_at)
          VALUES($1,'New customer','customer',false,false,false,$2)`, [userId, verifiedAt]);
        const identityId = randomUUID();
        await c.query(`INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest,created_at)
          VALUES($1,$2,'phone:msg91',$3,$4,$5)`, [identityId, userId, this.issuer, phoneDigest, verifiedAt]);
        await c.query("UPDATE auth_identities SET state='verified',verified_at=$2 WHERE id=$1", [identityId, verifiedAt]);
      }
      await c.query("UPDATE otp_challenges SET state='consumed',user_id=$2,verified_at=$3 WHERE id=$1", [id, userId, verifiedAt]);
      return { userId, restricted, needsOnboarding };
    });
    if (resolution.failure) throw resolution.failure;
    if (resolution.restricted) throw new OtpFailure(403, 'ACCOUNT_RESTRICTED', 'This account is unavailable.');
    // Consumed proof cannot be replayed if custom-token signing fails or its result is lost.
    try {
      const token = await this.deadline(this.tokenIssuer.createCustomToken(resolution.userId!));
      requireThat(typeof token === 'string' && token.length > 0 && token.length <= 16_384, 503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
      return { customToken: token, userId: resolution.userId!, needsOnboarding: resolution.needsOnboarding! };
    } catch {
      throw new OtpFailure(503, 'OTP_UNAVAILABLE', 'Sign-in could not be completed. Request a new code after the current code expires.', this.secondsUntil(row.expires_at));
    }
  }

  private stateFailure(row: ChallengeRow): OtpFailure | undefined {
    if (row.state === 'consumed' || row.state === 'superseded') return new OtpFailure(409, 'OTP_CONSUMED', 'This sign-in request is no longer usable.');
    if (row.expires_at.getTime() <= this.clock() || row.state === 'expired') return new OtpFailure(410, 'OTP_EXPIRED', 'The verification code has expired. Request a new code.');
    if (row.state === 'locked') return new OtpFailure(429, 'OTP_LOCKED', 'Too many incorrect codes. Wait before requesting another code.', this.secondsUntil(row.expires_at));
    if (row.state === 'send_unknown' || row.state === 'verify_unknown') return new OtpFailure(503, 'OTP_UNKNOWN_OUTCOME', 'The previous operation has an unknown outcome. Wait before requesting a new code.', this.secondsUntil(row.expires_at));
    if (row.state !== 'sent') return new OtpFailure(409, 'OTP_IN_PROGRESS', 'The previous sign-in operation is still pending.', this.secondsUntil(row.expires_at));
    return undefined;
  }
  private async requestBudget(scope: 'request_ip' | 'verify_ip', ip: string, limit: number) {
    const address = string(ip, 'request address', 100), now = this.clock();
    await this.db.tx(async c => {
      const keyCheck = this.digest('key-check', 'nightshift-otp-v1');
      await c.query('INSERT INTO otp_identity_namespaces(issuer,digest_key_check) VALUES($1,$2) ON CONFLICT DO NOTHING', [this.issuer, keyCheck]);
      const stored = (await c.query('SELECT digest_key_check FROM otp_identity_namespaces WHERE issuer=$1', [this.issuer])).rows[0].digest_key_check;
      requireThat(timingSafeEqual(Buffer.from(stored), Buffer.from(keyCheck)), 503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.');
      await this.budget(c, scope, this.digest('ip', address), limit, 300_000, now);
    });
  }
  private async budget(c: PoolClient, scope: string, digest: string, limit: number, windowMs: number, now: number) {
    const start = Math.floor(now / windowMs) * windowMs;
    const result = await c.query(`INSERT INTO otp_rate_limits(issuer,scope,subject_digest,window_start,attempts) VALUES($1,$2,$3,$4,1)
      ON CONFLICT(issuer,scope,subject_digest,window_start) DO UPDATE SET attempts=otp_rate_limits.attempts+1
      WHERE otp_rate_limits.attempts<$5 RETURNING attempts`, [this.issuer, scope, digest, new Date(start), limit]);
    if (!result.rowCount) throw new OtpFailure(429, 'OTP_RATE_LIMITED', 'Too many attempts. Try again later.', Math.max(1, Math.ceil((start + windowMs - now) / 1000)));
  }
  private digest(label: string, value: string) { return createHmac('sha256', this.#digestKey).update(`${this.issuer}\0${label}\0${value}`).digest('hex'); }
  private secondsUntil(date: Date) { return Math.max(1, Math.ceil((date.getTime() - this.clock()) / 1000)); }
  private view(row: ChallengeRow): OtpChallengeView {
    const waitForExpiry = ['consumed', 'locked', 'send_unknown', 'verify_unknown', 'sending', 'verifying'].includes(row.state);
    return { challengeId: row.id, state: row.state, expiresAt: row.expires_at.toISOString(), retryAt: (waitForExpiry ? row.expires_at : row.retry_at).toISOString() };
  }
  private async readView(id: string) {
    const row = (await this.db.pool.query<ChallengeRow>('SELECT * FROM otp_challenges WHERE id=$1', [id])).rows[0];
    requireThat(row, 404, 'OTP_NOT_FOUND', 'This sign-in request is unavailable.');
    return this.view(row);
  }
  private async deadline<T>(operation: Promise<T>): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([operation, new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new OtpFailure(503, 'OTP_UNAVAILABLE', 'Phone sign-in is unavailable.')), this.timeoutMs);
      })]);
    } finally { if (timer) clearTimeout(timer); }
  }
}
