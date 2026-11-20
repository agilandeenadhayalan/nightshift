import { randomUUID } from 'node:crypto';
import { applicationDefault, deleteApp, initializeApp } from 'firebase-admin/app';
import { Auth, getAuth } from 'firebase-admin/auth';
import { ApiError } from '../errors';

export interface VerifiedFirebaseIdentity {
  readonly uid: string;
  readonly issuer: string;
  readonly audience: string;
  readonly authTime: number;
  readonly issuedAt: number;
  readonly expiresAt: number;
}

type FirebaseAuthClient = Pick<Auth, 'verifyIdToken' | 'createCustomToken'>;

export interface FirebaseVerificationLimits {
  timeoutMs?: number;
  maxInFlight?: number;
}

function configurationGuard(projectId: string): void {
  // The emulator deliberately accepts unsigned JWTs. It must never be an
  // alternate verification path for this server, including after startup.
  if (process.env.FIREBASE_AUTH_EMULATOR_HOST !== undefined ||
      !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
    throw new ApiError(503, 'IDENTITY_CONFIGURATION', 'Identity verification is not configured.');
  }
}

function invalidToken(): ApiError {
  return new ApiError(401, 'INVALID_ID_TOKEN', 'Sign in again with a valid identity token.');
}

function unavailable(): ApiError {
  return new ApiError(503, 'IDENTITY_UNAVAILABLE', 'Identity verification is temporarily unavailable.');
}

function safeProviderError(error: unknown): ApiError {
  const code = typeof error === 'object' && error !== null && 'code' in error
    ? error.code : undefined;
  switch (code) {
    case 'auth/id-token-expired':
      return new ApiError(401, 'ID_TOKEN_EXPIRED', 'Your identity token has expired. Sign in again.');
    case 'auth/id-token-revoked':
      return new ApiError(401, 'ID_TOKEN_REVOKED', 'Your session was revoked. Sign in again.');
    case 'auth/user-disabled':
      return new ApiError(401, 'IDENTITY_DISABLED', 'This identity is unavailable.');
    case 'auth/argument-error':
    case 'auth/invalid-argument':
    case 'auth/invalid-id-token':
    case 'auth/user-not-found':
    case 'auth/tenant-id-mismatch':
      return invalidToken();
    default:
      // Do not propagate SDK messages/cause: they can include provider payloads,
      // claim contents, phone numbers, URLs or credentials.
      return unavailable();
  }
}

/**
 * Server-only Firebase boundary. The production factory always uses the Admin
 * SDK; injection exists for isolated tests, never through an environment bypass.
 * Mapping this verified UID to a NightShift user and adult/listener entitlement
 * remains a separate database authorization decision.
 */
export class FirebaseIdentityProvider {
  private inFlight = 0;
  private readonly timeoutMs: number;
  private readonly maxInFlight: number;

  constructor(
    private readonly auth: FirebaseAuthClient,
    private readonly projectId: string,
    private readonly clock: () => number = Date.now,
    private readonly disposeClient: () => Promise<void> = async () => {},
    limits: FirebaseVerificationLimits = {},
  ) {
    configurationGuard(projectId);
    this.timeoutMs = limits.timeoutMs ?? 6000;
    this.maxInFlight = limits.maxInFlight ?? 16;
    if (!Number.isInteger(this.timeoutMs) || this.timeoutMs < 1 || this.timeoutMs > 6000 ||
        !Number.isInteger(this.maxInFlight) || this.maxInFlight < 1 || this.maxInFlight > 64) {
      throw new ApiError(503, 'IDENTITY_CONFIGURATION', 'Identity verification is not configured.');
    }
  }

  async verifyIdToken(token: unknown): Promise<VerifiedFirebaseIdentity> {
    configurationGuard(this.projectId);
    if (typeof token !== 'string' || token.length === 0 || token.length > 16384 || token.trim() !== token) {
      throw invalidToken();
    }
    if (this.inFlight >= this.maxInFlight) throw unavailable();
    this.inFlight++;
    // Admin SDK verification has no public AbortSignal. A timed-out request
    // stays counted until its actual SDK work settles, preventing unlimited
    // abandoned certificate/ADC/revocation lookups from accumulating.
    const verification = Promise.resolve().then(() => {
      configurationGuard(this.projectId);
      return this.auth.verifyIdToken(token, true);
    });
    void verification.then(() => { this.inFlight--; }, () => { this.inFlight--; });
    let decoded;
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      // true makes Firebase check revoked refresh sessions and disabled users.
      // This is an ID token from the client exchange, never our custom token.
      decoded = await Promise.race([
        verification,
        new Promise<never>((_, reject) => { timer = setTimeout(() => reject(unavailable()), this.timeoutMs); }),
      ]);
    } catch (error) {
      throw safeProviderError(error);
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
    const now = Math.floor(this.clock() / 1000);
    const validTime = (value: unknown): value is number =>
      typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
    // The SDK checks signature, issuer, audience and expiration. Enforce the
    // documented required timestamps too: absent auth_time must not bypass its
    // revoked-session comparison, and future issuance cannot be accepted.
    if (decoded.aud !== this.projectId ||
        decoded.iss !== `https://securetoken.google.com/${this.projectId}` ||
        typeof decoded.uid !== 'string' || decoded.uid.length === 0 || decoded.uid.length > 128 ||
        decoded.uid !== decoded.sub ||
        !validTime(decoded.iat) || decoded.iat > now ||
        !validTime(decoded.auth_time) || decoded.auth_time > decoded.iat ||
        !validTime(decoded.exp) || decoded.exp <= now || decoded.exp <= decoded.iat ||
        decoded.firebase?.tenant !== undefined) {
      throw invalidToken();
    }
    // No phone, email, roles, arbitrary custom claims or bearer token cross this
    // boundary. MSG91-backed sign-in uses Firebase's 'custom' provider.
    return Object.freeze({
      uid: decoded.uid,
      issuer: decoded.iss,
      audience: decoded.aud,
      authTime: decoded.auth_time,
      issuedAt: decoded.iat,
      expiresAt: decoded.exp,
    });
  }

  async createCustomToken(uid: string): Promise<string> {
    configurationGuard(this.projectId);
    // NightShift user IDs are opaque UUIDs, never a raw phone number.
    if (!/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(uid)) {
      throw unavailable();
    }
    try {
      // Deliberately no role, adult or approval claims. The database owns those.
      return await this.auth.createCustomToken(uid);
    } catch {
      throw unavailable();
    }
  }

  close(): Promise<void> { return this.disposeClient(); }
}

/** ADC/service-account credentials are resolved on the server, outside Git. */
export function createFirebaseIdentityProvider(projectId: string): FirebaseIdentityProvider {
  configurationGuard(projectId);
  try {
    const app = initializeApp({ projectId, credential: applicationDefault() }, `nightshift-identity-${randomUUID()}`);
    return new FirebaseIdentityProvider(getAuth(app), projectId, Date.now, () => deleteApp(app));
  } catch {
    throw new ApiError(503, 'IDENTITY_CONFIGURATION', 'Identity verification is not configured.');
  }
}
