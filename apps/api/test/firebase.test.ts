import { test, TestContext } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, randomUUID, sign, verify } from 'node:crypto';
import { cert, deleteApp, initializeApp } from 'firebase-admin/app';
import { DecodedIdToken, getAuth, UserRecord } from 'firebase-admin/auth';
import { ApiError } from '../src/errors';
import { createFirebaseIdentityProvider, FirebaseIdentityProvider } from '../src/identity/firebase';

const projectId = 'nightshift-identity-test';
const uid = 'f16ff1da-8af1-4a7a-b6d6-aaf6c6f492fa';
// Keys exist only in this test process. No fixed private key or real provider
// credential is checked in, written to disk, logged or sent over the network.
const keys = generateKeyPairSync('rsa', { modulusLength: 2048 });
const otherKeys = generateKeyPairSync('rsa', { modulusLength: 2048 });
const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');

function token(changes: Record<string, unknown> = {}, header: Record<string, unknown> = {}, signingKey = keys.privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const content = `${encode({ alg: 'RS256', kid: 'fixture-key', typ: 'JWT', ...header })}.${encode({
    aud: projectId, iss: `https://securetoken.google.com/${projectId}`, sub: uid,
    iat: now - 10, auth_time: now - 20, exp: now + 3600,
    firebase: { sign_in_provider: 'custom', identities: {} }, ...changes,
  })}`;
  return `${content}.${sign('RSA-SHA256', Buffer.from(content), signingKey).toString('base64url')}`;
}

function fixture(t: TestContext, record: Partial<UserRecord> = {}) {
  const app = initializeApp({
    projectId,
    credential: cert({ projectId, clientEmail: `fixture@${projectId}.iam.gserviceaccount.com`,
      privateKey: keys.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString() }),
  }, `firebase-test-${randomUUID()}`);
  t.after(() => deleteApp(app));
  const auth = getAuth(app);
  // Only SDK network boundaries are replaced. Signature, JWT content, expiry,
  // revocation and disabled-user validation execute in the pinned real SDK.
  // This private SDK lookup is confined to tests; an SDK layout change fails
  // the fixture instead of silently weakening the production verifier.
  const verifier = Reflect.get(auth, 'idTokenVerifier') as {
    signatureVerifier: { keyFetcher: { fetchPublicKeys(): Promise<Record<string, string>> } };
  };
  assert.equal(typeof verifier?.signatureVerifier?.keyFetcher?.fetchPublicKeys, 'function');
  t.mock.method(verifier.signatureVerifier.keyFetcher, 'fetchPublicKeys', async () => ({
    'fixture-key': keys.publicKey.export({ type: 'spki', format: 'pem' }).toString(),
  }));
  const userLookup = t.mock.method(auth, 'getUser', async () => ({
    uid, disabled: false, tokensValidAfterTime: new Date(0).toUTCString(), ...record,
  }) as UserRecord);
  return { auth, userLookup, provider: new FirebaseIdentityProvider(auth, projectId) };
}

function safeFailure(code: string, status = 401) {
  return (error: unknown) => {
    assert.ok(error instanceof ApiError);
    assert.equal(error.code, code);
    assert.equal(error.status, status);
    assert.equal('cause' in error, false);
    assert.doesNotMatch(error.message, /eyJ|sensitive-provider-detail|\+919876543210/);
    return true;
  };
}

test('real SDK validates signed custom-provider ID token and returns only identity metadata', async t => {
  const { provider, userLookup } = fixture(t);
  const result = await provider.verifyIdToken(token({ phone_number: '+919876543210', admin: true, listenerApproved: true }));
  assert.deepEqual(Object.keys(result).sort(), ['audience', 'authTime', 'expiresAt', 'issuedAt', 'issuer', 'uid']);
  assert.equal(result.uid, uid);
  assert.equal(result.audience, projectId);
  assert.equal(Object.isFrozen(result), true);
  assert.equal(userLookup.mock.callCount(), 1, 'revocation lookup must be enabled');
  assert.equal(userLookup.mock.calls[0]?.arguments[0], uid);
});

test('real SDK verifies native phone proof without exposing arbitrary claims',async t=>{
  const {provider,userLookup}=fixture(t),phone='+919876543210';
  const result=await provider.verifyIdToken(token({phone_number:phone,firebase:{sign_in_provider:'phone',identities:{phone:[phone]}},admin:true}));
  assert.equal(result.signInProvider,'phone');assert.equal(result.phoneNumber,phone);assert.ok(!('admin' in result));
  assert.equal(userLookup.mock.callCount(),1);
});

test('signed phone provider tokens require one matching canonical phone identity',async t=>{
  const {provider}=fixture(t),phone='+919876543210';
  for(const claims of [
    {firebase:{sign_in_provider:'phone',identities:{phone:[phone]}}},
    {phone_number:phone,firebase:{sign_in_provider:'phone',identities:{}}},
    {phone_number:phone,firebase:{sign_in_provider:'phone',identities:{phone:['+919000000000']}}},
    {phone_number:phone,firebase:{sign_in_provider:'phone',identities:{phone:[phone,phone]}}},
    {phone_number:'919876543210',firebase:{sign_in_provider:'phone',identities:{phone:['919876543210']}}},
  ])await assert.rejects(provider.verifyIdToken(token(claims)),safeFailure('INVALID_ID_TOKEN'));
});

for (const [name, changes] of [
  ['wrong audience', { aud: 'different-project' }],
  ['wrong issuer', { iss: 'https://attacker.invalid/project' }],
  ['missing subject', { sub: undefined }],
  ['empty subject', { sub: '' }],
  ['overlong subject', { sub: 'x'.repeat(129) }],
  ['missing issuance time', { iat: undefined }],
  ['future issuance time', { iat: Math.floor(Date.now() / 1000) + 3600 }],
  ['missing authentication time', { auth_time: undefined }],
  ['future authentication time', { auth_time: Math.floor(Date.now() / 1000) + 3600 }],
  ['missing expiry', { exp: undefined }],
  ['unsupported tenant identity', { firebase: { sign_in_provider: 'custom', tenant: 'other-tenant', identities: {} } }],
] as const) {
  test(`signed ID token rejects ${name}`, async t => {
    const { provider } = fixture(t);
    await assert.rejects(provider.verifyIdToken(token(changes)), safeFailure('INVALID_ID_TOKEN'));
  });
}

test('real SDK rejects expired tokens before user lookup', async t => {
  const { provider, userLookup } = fixture(t);
  await assert.rejects(provider.verifyIdToken(token({ exp: Math.floor(Date.now() / 1000) - 1 })), safeFailure('ID_TOKEN_EXPIRED'));
  assert.equal(userLookup.mock.callCount(), 0);
});

test('real SDK rejects signatures made with a different private key', async t => {
  const { provider, userLookup } = fixture(t);
  await assert.rejects(provider.verifyIdToken(token({}, {}, otherKeys.privateKey)), safeFailure('INVALID_ID_TOKEN'));
  assert.equal(userLookup.mock.callCount(), 0);
});

test('real SDK rejects unknown signing keys and unsigned algorithms', async t => {
  const { provider } = fixture(t);
  await assert.rejects(provider.verifyIdToken(token({}, { kid: 'unknown-key' })), safeFailure('INVALID_ID_TOKEN'));
  await assert.rejects(provider.verifyIdToken(token({}, { alg: 'none' })), safeFailure('INVALID_ID_TOKEN'));
});

test('real SDK rejects a revoked session even when its ID token has not expired', async t => {
  const { provider } = fixture(t, { tokensValidAfterTime: new Date().toUTCString() });
  await assert.rejects(provider.verifyIdToken(token()), safeFailure('ID_TOKEN_REVOKED'));
});

test('real SDK rejects disabled identities', async t => {
  const { provider } = fixture(t, { disabled: true });
  await assert.rejects(provider.verifyIdToken(token()), safeFailure('IDENTITY_DISABLED'));
});

test('malformed and oversized token inputs never reach provider verification', async t => {
  const { provider, auth } = fixture(t);
  const sdkVerify = t.mock.method(auth, 'verifyIdToken', async () => { throw new Error('Must not reach SDK'); });
  for (const value of [undefined, null, 9, '', ' ', 'x'.repeat(16385), ' leading-space']) {
    await assert.rejects(provider.verifyIdToken(value), safeFailure('INVALID_ID_TOKEN'));
  }
  assert.equal(sdkVerify.mock.callCount(), 0);
});

test('Firebase provider failures have safe constant errors without raw cause', async t => {
  const { provider, auth } = fixture(t);
  t.mock.method(auth, 'getUser', async () => {
    throw Object.assign(new Error('sensitive-provider-detail +919876543210 eyJ-secret'), { code: 'auth/internal-error' });
  });
  await assert.rejects(provider.verifyIdToken(token()), safeFailure('IDENTITY_UNAVAILABLE', 503));
});

test('custom token contains only the opaque UID and is not accepted as an ID token', async t => {
  const { provider } = fixture(t);
  const customToken = await provider.createCustomToken(uid);
  const [header, body, signature] = customToken.split('.');
  assert.ok(header && body && signature);
  assert.equal(verify('RSA-SHA256', Buffer.from(`${header}.${body}`), keys.publicKey, Buffer.from(signature, 'base64url')), true);
  const payload = JSON.parse(Buffer.from(body, 'base64url').toString()) as Record<string, unknown>;
  assert.equal(payload.uid, uid);
  assert.equal(payload.claims, undefined);
  assert.equal(payload.phone_number, undefined);
  await assert.rejects(provider.verifyIdToken(customToken), safeFailure('INVALID_ID_TOKEN'));
});

test('custom-token mint rejects phone-number UID and redacts signing errors', async t => {
  const { provider, auth } = fixture(t);
  const mint = t.mock.method(auth, 'createCustomToken', async () => {
    throw new Error('sensitive-provider-detail +919876543210');
  });
  await assert.rejects(provider.createCustomToken('+919876543210'), safeFailure('IDENTITY_UNAVAILABLE', 503));
  assert.equal(mint.mock.callCount(), 0);
  await assert.rejects(provider.createCustomToken(uid), safeFailure('IDENTITY_UNAVAILABLE', 503));
  assert.equal(mint.mock.callCount(), 1);
  assert.deepEqual(mint.mock.calls[0]?.arguments, [uid], 'no entitlement claims may be passed');
});

test('Firebase emulator configuration cannot bypass verification or signing', async t => {
  const { provider } = fixture(t);
  const original = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
  try {
    assert.throws(() => createFirebaseIdentityProvider(projectId), safeFailure('IDENTITY_CONFIGURATION', 503));
    await assert.rejects(provider.verifyIdToken(token()), safeFailure('IDENTITY_CONFIGURATION', 503));
    await assert.rejects(provider.createCustomToken(uid), safeFailure('IDENTITY_CONFIGURATION', 503));
  } finally {
    if (original === undefined) delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
    else process.env.FIREBASE_AUTH_EMULATOR_HOST = original;
  }
});

test('Firebase factory requires an explicit valid project ID without network lookup', () => {
  for (const value of ['', '   ', 'https://project.example', 'project\nname']) {
    assert.throws(() => createFirebaseIdentityProvider(value), safeFailure('IDENTITY_CONFIGURATION', 503));
  }
});

test('verification deadline fails closed and holds its slot until late SDK completion', async t => {
  const { auth } = fixture(t);
  const validToken = token();
  const decoded = { ...JSON.parse(Buffer.from(validToken.split('.')[1]!, 'base64url').toString()), uid } as DecodedIdToken;
  let complete!: (value: DecodedIdToken) => void;
  const stalled = new Promise<DecodedIdToken>(resolve => { complete = resolve; });
  const verifyCall = t.mock.method(auth, 'verifyIdToken', () => stalled);
  const provider = new FirebaseIdentityProvider(auth, projectId, Date.now, undefined,
    { timeoutMs: 10, maxInFlight: 1 });
  const first = provider.verifyIdToken(validToken);
  let authorized = false;
  void first.then(() => { authorized = true; }, () => {});
  await assert.rejects(first, safeFailure('IDENTITY_UNAVAILABLE', 503));
  await assert.rejects(provider.verifyIdToken(validToken), safeFailure('IDENTITY_UNAVAILABLE', 503));
  assert.equal(verifyCall.mock.callCount(), 1, 'timed-out SDK work still occupies its capacity slot');
  complete(decoded);
  await stalled;
  await Promise.resolve();
  assert.equal(authorized, false, 'late completion cannot authorize the timed-out caller');
  const later = await provider.verifyIdToken(validToken);
  assert.equal(later.uid, uid);
  assert.equal(verifyCall.mock.callCount(), 2, 'settled SDK work releases the slot');
});

test('late SDK rejection releases capacity without leaking its error or rejecting unhandled', async t => {
  const { auth } = fixture(t);
  let reject!: (error: Error) => void;
  const stalled = new Promise<DecodedIdToken>((_, rejectPromise) => { reject = rejectPromise; });
  const verifyCall = t.mock.method(auth, 'verifyIdToken', () => stalled);
  const provider = new FirebaseIdentityProvider(auth, projectId, Date.now, undefined,
    { timeoutMs: 10, maxInFlight: 1 });
  await assert.rejects(provider.verifyIdToken(token()), safeFailure('IDENTITY_UNAVAILABLE', 503));
  reject(new Error('sensitive-provider-detail +919876543210'));
  await Promise.resolve();
  await Promise.resolve();
  await assert.rejects(provider.verifyIdToken(token()), safeFailure('IDENTITY_UNAVAILABLE', 503));
  assert.equal(verifyCall.mock.callCount(), 2, 'late rejection releases the previous slot');
});

test('verification limits cannot disable the deadline or capacity bound', t => {
  const { auth } = fixture(t);
  for (const limits of [
    { timeoutMs: 0 }, { timeoutMs: 6001 }, { timeoutMs: Number.POSITIVE_INFINITY },
    { maxInFlight: 0 }, { maxInFlight: 65 }, { maxInFlight: 1.5 },
  ]) {
    assert.throws(() => new FirebaseIdentityProvider(auth, projectId, Date.now, undefined, limits),
      safeFailure('IDENTITY_CONFIGURATION', 503));
  }
});
