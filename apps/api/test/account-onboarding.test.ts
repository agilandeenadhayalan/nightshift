import 'reflect-metadata';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { io } from 'socket.io-client';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { createApplication } from '../src/http';
import { Config } from '../src/config';
import { ApiError } from '../src/errors';
import { PhoneAuthDependencies } from '../src/identity/phone-auth';
import { isAdultOn, validateBirthDate } from '../src/identity/onboarding';
import { seed } from '../src/seed';

const schema = `accounts_${randomUUID().replaceAll('-', '')}`;
const issuer = 'nightshift-account-fixture';
const priorEnvironment = process.env.NODE_ENV;
let runtime: Awaited<ReturnType<typeof createApplication>>, admin: Database, base: string;
let now = Date.UTC(2026, 10, 20, 12), providerRevoked = false, verificationCalls = 0;
let verificationGate: { token: string; entered: () => void; wait: Promise<void> }|undefined;
const identities = new Map<string, { uid: string; issued: number; expires: number; authTime:number }>();
const tokenFor = (uid: string, issued = Math.floor(now / 1000), expires = issued + 3600, authTime=issued) => {
  const token = `fixture-${randomBytes(32).toString('hex')}`;
  identities.set(token, { uid, issued, expires, authTime }); return token;
};

before(async () => {
  process.env.NODE_ENV = 'test';
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a dedicated test database');
  const url = new URL(process.env.TEST_DATABASE_URL!);
  admin = new Database(url.toString()); await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  const config: Config = { databaseUrl: url.toString(), redisUrl: process.env.REDIS_URL!, port: 0,
    devAccessKey: 'synthetic-account-test-key-only', phoneAuth: { projectId: issuer,
      digestKey: randomBytes(32).toString('hex'), consentVersion: 'phone-signin-v1',
      msg91WidgetId: 'fixture-widget', msg91AuthKey: 'fixture-provider-key', dailySendLimit: 10 } };
  const db = new Database(config.databaseUrl); await migrate(db); await seed(db); await db.close();
  const deps: PhoneAuthDependencies = { otp: {
    async request() { throw new Error('No SMS in account tests'); },
    async verify() { throw new Error('No SMS in account tests'); },
  }, firebase: { async verifyIdToken(raw) {
    verificationCalls++;
    const identity = typeof raw === 'string' ? identities.get(raw) : undefined;
    if (!identity || providerRevoked || identity.expires * 1000 <= now) {
      throw new ApiError(401, providerRevoked ? 'ID_TOKEN_REVOKED' : 'INVALID_ID_TOKEN', 'Sign in again.');
    }
    if(verificationGate && verificationGate.token===raw){const gate=verificationGate;verificationGate=undefined;gate.entered();await gate.wait;}
    return { uid: identity.uid, issuer: `https://securetoken.google.com/${issuer}`, audience: issuer,
      authTime: identity.authTime, issuedAt: identity.issued, expiresAt: identity.expires };
  } } };
  runtime = await createApplication(config, () => now, deps);
  await runtime.app.listen(0, '127.0.0.1'); base = await runtime.app.getUrl();
});

after(async () => {
  if (runtime) await runtime.close();
  if (admin) { await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.close(); }
  if (priorEnvironment === undefined) delete process.env.NODE_ENV; else process.env.NODE_ENV = priorEnvironment;
});

async function account() {
  const id = randomUUID();
  await runtime.db.tx(async c => {
    await c.query("INSERT INTO users(id,display_name,adult_confirmed) VALUES($1,'New customer',false)", [id]);
    const identity = randomUUID();
    await c.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:msg91',$3,$4)", [identity,id,issuer,randomBytes(32).toString('hex')]);
    await c.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1", [identity]);
  }); return id;
}
async function request(path: string, method = 'GET', token?: string, body?: unknown) {
  const response = await fetch(`${base}/v1/${path}`, { method, headers: {
    ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}),
  }, body: body ? JSON.stringify(body) : undefined });
  return { status: response.status, body: await response.json() as any };
}
async function exchange(id: string, deviceId = 'phone-a', token = tokenFor(id)) {
  return { token, result: await request('auth/exchange', 'POST', undefined, { idToken: token, deviceId }) };
}
const profile = (dateOfBirth = '2008-11-20') => ({ dateOfBirth, displayName: 'நிலா Star', avatarCode: 'moon',
  interfaceLanguage: 'ta', languages: ['ta', 'en'], consentVersion: 'adult-onboarding-v1' });

test('phone exchange creates a restricted device session without credits or listener approval', async () => {
  const id = await account(), { token, result } = await exchange(id);
  assert.equal(result.status, 201); assert.equal(result.body.token, token);
  assert.equal(result.body.needsOnboarding, true); assert.equal(result.body.user.listenerApproved, false);
  assert.equal(result.body.user.mode, 'customer');
  assert.equal((await runtime.db.pool.query('SELECT count(*) FROM wallet_accounts WHERE user_id=$1', [id])).rows[0].count, '0');
  const session = (await runtime.db.pool.query('SELECT * FROM auth_sessions WHERE user_id=$1', [id])).rows[0];
  assert.notEqual(session.token_hash, token); assert.equal(session.auth_kind, 'firebase');
  assert.equal((await runtime.db.pool.query('SELECT count(*) FROM devices WHERE user_id=$1', [id])).rows[0].count, '1');
  assert.equal((await request('me/onboarding', 'GET', token)).body.required, true);
  for (const path of ['snapshot', 'listeners', 'me', 'wallet', 'events']) {
    const response = await request(path, 'GET', token); assert.equal(response.status, 403, path);
    assert.equal(response.body.error.code, 'ONBOARDING_REQUIRED');
  }
});

test('only verified bound identities exchange, and caller role/owner fields cannot be injected', async () => {
  const unknown = randomUUID(), token = tokenFor(unknown);
  assert.equal((await request('auth/exchange', 'POST', undefined, { idToken: token, deviceId: 'phone-a' })).status, 401);
  const id = await account();
  const forged = await request('auth/exchange', 'POST', undefined, { idToken: tokenFor(id), deviceId: 'phone-a', role: 'admin' });
  assert.equal(forged.status, 400);
});

test('underage account cannot bypass isolated onboarding or enter the socket service', async () => {
  const id = await account(), { token } = await exchange(id);
  const response = await request('me/onboarding', 'PUT', token, profile('2008-11-21'));
  assert.equal(response.status, 403); assert.equal(response.body.error.code, 'ADULT_ONLY');
  assert.equal((await runtime.db.pool.query('SELECT adult_confirmed FROM users WHERE id=$1', [id])).rows[0].adult_confirmed, false);
  assert.equal((await request('me/onboarding', 'PUT', token, profile('2000-01-01'))).body.error.code,'DOB_IMMUTABLE');
  assert.equal((await request('me/onboarding', 'GET', token)).body.profile.dateOfBirth,'2008-11-21');
  const socket = io(base, { transports: ['websocket'], auth: { token }, reconnection: false });
  try {
    const outcome = await new Promise<string>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Socket guard timed out')), 2000);
      socket.on('connect', () => { clearTimeout(timeout); resolve('connected'); });
      socket.on('connect_error', () => { clearTimeout(timeout); resolve('denied'); });
    }); assert.equal(outcome, 'denied');
  } finally { socket.disconnect(); }
});

test('eighteenth birthday is accepted in UTC, DOB stays private and immutable, nickname awaits moderation', async () => {
  const id = await account(), { token } = await exchange(id);
  const completed = await request('me/onboarding', 'PUT', token, profile());
  assert.equal(completed.status, 200); assert.equal(completed.body.required, false);
  assert.equal(completed.body.profile.dateOfBirth, '2008-11-20');
  const me = await request('me', 'GET', token);
  assert.equal(me.status, 200); assert.equal(me.body.displayName, 'New customer');
  assert.ok(!JSON.stringify(me.body).includes('2008-11-20'));
  assert.ok(!JSON.stringify(me.body).includes('நிலா'));
  assert.equal((await request('me/onboarding', 'PUT', token, profile('2000-01-01'))).body.error.code, 'DOB_IMMUTABLE');
  const owner = (await request('me/onboarding', 'GET', token)).body;
  assert.equal(owner.profile.displayName, 'நிலா Star'); assert.equal(owner.profile.interfaceLanguage, 'ta');
  assert.deepEqual(owner.profile.languages, ['ta', 'en']);
  assert.equal((await runtime.db.pool.query('SELECT count(*) FROM consents WHERE user_id=$1', [id])).rows[0].count, '1');
  assert.equal((await request('me/onboarding', 'PUT', token, profile())).status, 200);
  assert.equal((await runtime.db.pool.query('SELECT count(*) FROM consents WHERE user_id=$1', [id])).rows[0].count, '1');
});

test('invalid calendar dates, contact-like nicknames, avatars, languages and outdated notice fail safely', async () => {
  const id = await account(), { token } = await exchange(id);
  const invalid = [ {dateOfBirth:'2000-02-30'}, {dateOfBirth:'2027-01-01'}, {displayName:'https://bad.example'},
    {displayName:'9000000001'}, {displayName:'bad\nname'}, {avatarCode:'https://avatar.example'},
    {languages:[]}, {languages:['fr']}, {languages:['ta','ta']}, {interfaceLanguage:'fr'}, {consentVersion:'old'},
    {avatarCode:['moon']}, {avatarCode:{value:'moon'}}, {interfaceLanguage:['ta']}, {interfaceLanguage:{value:'ta'}} ];
  for (const override of invalid) {
    const result = await request('me/onboarding', 'PUT', token, {...profile(),...override});
    assert.ok([400,403].includes(result.status), JSON.stringify(override));
  }
  const crossUser = await request('me/onboarding', 'PUT', token, {...profile(),userId:randomUUID()});
  assert.equal(crossUser.status, 400);
});

test('each phone request checks provider revocation and local account suspension', async () => {
  const id = await account(), { token } = await exchange(id);
  const beforeCalls = verificationCalls;
  await request('me/onboarding', 'GET', token); await request('me/onboarding', 'GET', token);
  assert.ok(verificationCalls >= beforeCalls + 2);
  providerRevoked = true;
  try { assert.equal((await request('me/onboarding', 'GET', token)).status, 401); }
  finally { providerRevoked = false; }
  await runtime.db.pool.query('UPDATE users SET suspended=true WHERE id=$1', [id]);
  assert.equal((await request('me/onboarding', 'GET', token)).status, 401);
});

test('same token retries are idempotent, cannot move devices, and logout cannot be replayed', async () => {
  const id = await account(), { token, result } = await exchange(id);
  assert.equal((await exchange(id, 'phone-a', token)).result.status, 201);
  assert.equal((await exchange(id, 'phone-b', token)).result.status, 409);
  assert.equal((await request('auth/logout', 'POST', token)).status, 201);
  assert.equal((await exchange(id, 'phone-a', token)).result.status, 401);
  assert.equal((await request('me/onboarding', 'GET', token)).status, 401);
  assert.equal(result.body.token, token);
});

test('same-device token refresh preserves availability, rejects stale tokens and invalidates predecessor', async () => {
  const id = await account(), first = await exchange(id);
  await request('me/onboarding', 'PUT', first.token, profile());
  await runtime.presence.heartbeat(id, 'prior-lease');
  now += 2000;
  const newer = tokenFor(id), refreshed = await exchange(id, 'phone-a', newer);
  assert.equal(refreshed.result.status, 201); assert.equal(await runtime.presence.isOnline(id), true);
  assert.equal((await request('me', 'GET', first.token)).status, 401);
  assert.equal((await exchange(id, 'phone-a', first.token)).result.status, 401);
  const older = tokenFor(id, Math.floor(now/1000)-1);
  assert.equal((await exchange(id, 'phone-a', older)).result.status, 409);
  assert.equal((await request('me', 'GET', newer)).status, 200);
  await runtime.presence.clear(id);
});

test('simultaneous refresh ordering never revives an older identity token', async () => {
  const id = await account(); await exchange(id); now += 2000;
  const older = tokenFor(id, Math.floor(now/1000)-1), newer = tokenFor(id);
  const attempts = await Promise.all([exchange(id,'phone-a',newer),exchange(id,'phone-a',older)]);
  assert.equal(attempts[0].result.status,201);
  assert.ok([201,409].includes(attempts[1].result.status));
  assert.equal((await request('me/onboarding','GET',older)).status,401);
  assert.equal((await request('me/onboarding','GET',newer)).status,200);
});

test('expired tokens cannot establish or maintain app sessions', async () => {
  const id = await account(), expired = tokenFor(id, Math.floor(now/1000)-3601,Math.floor(now/1000)-1);
  assert.equal((await exchange(id,'phone-a',expired)).result.status,401);
  const short = tokenFor(id,Math.floor(now/1000),Math.floor(now/1000)+1);
  assert.equal((await exchange(id,'phone-a',short)).result.status,201);
  now += 2000; assert.equal((await request('me/onboarding','GET',short)).status,401);
});

test('device takeover is blocked during a call but same-device refresh preserves its reservation',async()=>{
  const id=await account(), initial=await exchange(id);await request('me/onboarding','PUT',initial.token,profile());
  const other=await account(), call=randomUUID();
  await runtime.db.tx(async c=>{
    await c.query(`INSERT INTO call_sessions(id,customer_id,listener_id,state,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at)
      SELECT $1,$2,$3,'ringing',id,policy,600,$4,$5 FROM rate_versions WHERE id='test-audio-v1'`,[call,id,other,new Date(now),new Date(now+30000)]);
    await c.query('INSERT INTO active_participant_claims(user_id,call_id) VALUES($1,$2)',[id,call]);
  });
  now+=2000;
  const same=await exchange(id,'phone-a');assert.equal(same.result.status,201);
  now+=1000;
  assert.equal((await exchange(id,'phone-b')).result.body.error.code,'CALL_ACTIVE');
  assert.equal((await runtime.db.pool.query('SELECT call_id FROM active_participant_claims WHERE user_id=$1',[id])).rows[0].call_id,call);
  assert.equal((await request('me/onboarding','PUT',same.token,profile())).body.error.code,'CALL_ACTIVE');
  await runtime.db.pool.query('DELETE FROM active_participant_claims WHERE call_id=$1',[call]);
  await runtime.db.pool.query("UPDATE call_sessions SET state='ended',ended_at=$2,reason='test-cleanup' WHERE id=$1",[call,new Date(now)]);
});

test('logout wins over a provider verification already in flight',async()=>{
  const id=await account(), {token}=await exchange(id), actor=await runtime.auth.authenticate(token,true);
  let entered!:()=>void, release!:()=>void;
  const arrived=new Promise<void>(resolve=>{entered=resolve;}), wait=new Promise<void>(resolve=>{release=resolve;});
  verificationGate={token,entered,wait};
  const pending=runtime.auth.authenticate(token,true);
  const observed=assert.rejects(pending,{code:'UNAUTHENTICATED'});
  await arrived;await runtime.auth.logout(actor);release();await observed;
});

test('UTC leap-day adulthood and invalid day validation do not depend on local timezone',()=>{
  assert.equal(isAdultOn('2008-02-29',Date.UTC(2026,1,28,23,59,59)),false);
  assert.equal(isAdultOn('2008-02-29',Date.UTC(2026,2,1)),true);
  assert.equal(isAdultOn('2008-11-20',Date.UTC(2026,10,19,23,59,59)),false);
  assert.equal(isAdultOn('2008-11-20',Date.UTC(2026,10,20)),true);
  assert.throws(()=>validateBirthDate('2007-02-29',()=>now),{code:'INVALID_BIRTH_DATE'});
});

test('database protects the recorded age and consent against mutation',async()=>{
  const id=await account(), {token}=await exchange(id);await request('me/onboarding','PUT',token,profile());
  await assert.rejects(runtime.db.pool.query("UPDATE profiles SET date_of_birth='2000-01-01' WHERE user_id=$1",[id]),{code:'23514'});
  await assert.rejects(runtime.db.pool.query("UPDATE age_declarations SET date_of_birth='2000-01-01' WHERE user_id=$1",[id]),{code:'23514'});
  await assert.rejects(runtime.db.pool.query("UPDATE consents SET granted=false WHERE user_id=$1",[id]),{code:'23514'});
  const stranger=await account(), strangerSession=await exchange(stranger);
  const own=(await request('me/onboarding','GET',strangerSession.token)).body.profile;
  assert.equal(own.dateOfBirth,null);assert.equal(own.displayName,'New customer');
  const actor=await runtime.auth.authenticate(token,true);
  assert.equal(actor.identityAuthTime,identities.get(token)!.issued);
});

test('underage declaration removes legacy adult entitlement and Listener availability',async()=>{
  const id=await account();
  await runtime.db.pool.query("UPDATE users SET adult_confirmed=true,listener_approved=true,mode='listener',desired_online=true WHERE id=$1",[id]);
  const {token}=await exchange(id);await runtime.presence.heartbeat(id,'legacy');
  const denied=await request('me/onboarding','PUT',token,profile('2008-11-21'));
  assert.equal(denied.status,403);assert.equal(denied.body.error.code,'ADULT_ONLY');
  assert.equal((await request('snapshot','GET',token)).status,403);
  const user=(await runtime.db.pool.query('SELECT adult_confirmed,listener_approved,desired_online FROM users WHERE id=$1',[id])).rows[0];
  assert.deepEqual(user,{adult_confirmed:false,listener_approved:false,desired_online:false});
  assert.equal(await runtime.presence.isOnline(id),false);
});

test('logout rejects refreshed old authentication lineage even with a new device identifier',async()=>{
  const id=await account(), {token}=await exchange(id), initialAuthTime=identities.get(token)!.authTime;
  await request('auth/logout','POST',token);now+=2000;
  const issued=Math.floor(now/1000), refreshed=tokenFor(id,issued,issued+3600,initialAuthTime);
  assert.equal((await exchange(id,'phone-a',refreshed)).result.body.error.code,'SESSION_REVOKED');
  assert.equal((await exchange(id,'new-device-bypass-attempt',refreshed)).result.body.error.code,'SESSION_REVOKED');
  const freshPhoneSignIn=tokenFor(id,issued,issued+3600,issued);
  assert.equal((await exchange(id,'phone-a',freshPhoneSignIn)).result.status,201);
});

test('phone session identity metadata is mandatory at the database boundary',async()=>{
  const id=await account(), {token}=await exchange(id);
  await assert.rejects(runtime.db.pool.query('UPDATE auth_sessions SET identity_issued_at=NULL WHERE user_id=$1',[id]),{code:'23514'});
  assert.equal((await request('me/onboarding','GET',token)).status,200);
});

test('stale authenticated logout invalidates a newer same-lineage token',async()=>{
  const id=await account(), first=await exchange(id), actor=await runtime.auth.authenticate(first.token,true);
  const authTime=identities.get(first.token)!.authTime;now+=2000;
  const issued=Math.floor(now/1000), newer=tokenFor(id,issued,issued+3600,authTime);
  assert.equal((await exchange(id,'phone-a',newer)).result.status,201);
  await runtime.auth.logout(actor);
  assert.equal((await request('me/onboarding','GET',newer)).status,401);
});

test('unexchanged stale tokens and retained old lineages cannot take over through a new device ID',async()=>{
  const id=await account(), first=await exchange(id), authTime=identities.get(first.token)!.authTime;
  const unused=tokenFor(id,authTime+1,authTime+3601,authTime);now+=4000;
  const issued=Math.floor(now/1000), current=tokenFor(id,issued,issued+3600,authTime);
  assert.equal((await exchange(id,'phone-a',current)).result.status,201);
  assert.equal((await exchange(id,'new-device',unused)).result.body.error.code,'SESSION_SUPERSEDED');
  now+=2000;const refreshed=tokenFor(id,Math.floor(now/1000),Math.floor(now/1000)+3600,authTime);
  assert.equal((await exchange(id,'new-device',refreshed)).result.body.error.code,'FRESH_SIGN_IN_REQUIRED');
  const fresh=tokenFor(id);
  assert.equal((await exchange(id,'new-device',fresh)).result.status,201);
  assert.equal((await request('me/onboarding','GET',current)).status,401);
  now+=2000;
  const oldLineage=tokenFor(id,Math.floor(now/1000),Math.floor(now/1000)+3600,authTime);
  assert.equal((await exchange(id,'phone-a',oldLineage)).result.body.error.code,'SESSION_REVOKED');
});
