import { createHmac } from 'node:crypto';
import { Config } from '../config';
import { Database } from '../db';
import { Presence } from '../presence';
import { ApiError, fields, object, requireThat, string } from '../errors';
import { createFirebaseIdentityProvider, VerifiedFirebaseIdentity } from './firebase';
import { Msg91OtpProvider } from './msg91';
import { OtpChallenges } from './otp';

export interface PhoneAuthDependencies {
  otp: Pick<OtpChallenges, 'request' | 'verify'>;
  firebase: { verifyIdToken(token: unknown): Promise<VerifiedFirebaseIdentity> };
  close?(): Promise<void>;
}

/** Validates identity only. Adult onboarding and app-session permissions are separate. */
export class PhoneAuthentication {
  constructor(private readonly db: Database, private readonly presence: Presence,
    private readonly config?: Config['phoneAuth'], private readonly dependencies?: PhoneAuthDependencies) {}

  private ready(): PhoneAuthDependencies {
    if (!this.config || !this.dependencies) {
      throw new ApiError(503, 'PHONE_AUTH_UNAVAILABLE', 'Phone sign-in is not available on this server.');
    }
    return this.dependencies;
  }

  async request(raw: unknown, ip: string, key: unknown) {
    const dependencies = this.ready();
    const body = object(raw);
    fields(body, ['phone', 'deviceId', 'consentVersion']);
    return dependencies.otp.request({ ...body, idempotencyKey: string(key, 'request key', 128) }, ip);
  }

  async verify(raw: unknown, ip: string) {
    return this.ready().otp.verify(raw, ip);
  }

  async verifyIdentity(raw: unknown, ip: string) {
    this.ready();
    const digest = createHmac('sha256', this.config!.digestKey).update(`firebase-verify-ip:${ip}`).digest('hex');
    requireThat(await this.presence.rateLimit(`identity:${digest}`, 30, 60),
      429, 'RATE_LIMITED', 'Wait before verifying another identity token.');
    const body = object(raw);
    fields(body, ['idToken']);
    const identity = await this.sessionIdentity(body.idToken);
    const { rows } = await this.db.pool.query('SELECT adult_confirmed FROM users WHERE id=$1', [identity.uid]);
    return { userId: identity.uid, needsOnboarding: !rows[0].adult_confirmed };
  }

  /** Every protected phone request checks provider revocation and the durable binding. */
  async sessionIdentity(token: unknown): Promise<VerifiedFirebaseIdentity> {
    const identity = await this.ready().firebase.verifyIdToken(token);
    // A valid JWT from this Firebase project alone cannot enroll arbitrary users.
    // It must refer to our server-verified MSG91 binding, with no caller role claims.
    const { rows } = await this.db.pool.query(`SELECT u.id,u.adult_confirmed FROM users u
      JOIN auth_identities i ON i.user_id=u.id
      WHERE u.id::text=$1 AND NOT u.suspended AND i.provider='phone:msg91'
        AND i.issuer=$2 AND i.state='verified'`, [identity.uid, this.config!.projectId]);
    requireThat(rows.length > 0, 401, 'INVALID_ID_TOKEN', 'Sign in again with a verified identity.');
    return identity;
  }

  async close() { await this.dependencies?.close?.(); }
}

export async function createPhoneAuthentication(db: Database, presence: Presence, config: Config,
  clock: () => number, injected?: PhoneAuthDependencies) {
  if (injected && process.env.NODE_ENV !== 'test') {
    throw new Error('Identity test adapters are restricted to isolated test processes');
  }
  if (!config.phoneAuth) return new PhoneAuthentication(db, presence);
  if (injected) return new PhoneAuthentication(db, presence, config.phoneAuth, injected);
  const firebase = createFirebaseIdentityProvider(config.phoneAuth.projectId);
  const provider = new Msg91OtpProvider({ authKey: config.phoneAuth.msg91AuthKey, widgetId: config.phoneAuth.msg91WidgetId });
  const otp = new OtpChallenges(db, provider, firebase, {
    digestKey: config.phoneAuth.digestKey, issuer: config.phoneAuth.projectId, consentVersion: config.phoneAuth.consentVersion,
    limits: { sendGlobal: config.phoneAuth.dailySendLimit },
  }, clock);
  return new PhoneAuthentication(db, presence, config.phoneAuth, { otp, firebase, close: () => firebase.close() });
}
