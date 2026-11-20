import 'reflect-metadata';
import { after,before,test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync,randomBytes,randomUUID,sign,verify,createHash } from 'node:crypto';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { createApplication } from '../src/http';
import { StaffAuthority,StaffPermission } from '../src/staff/authority';
import { StaffController,STAFF_COOKIE,STAFF_CHALLENGE_COOKIE } from '../src/staff/http';
import { StaffIdentityVerifier,StaffPolicy,StaffIdentityReference,CurrentStaffIdentity,unauthenticated } from '../src/staff/verifier';

// Ephemeral signing keys and verifier exist in this test process only. Neither
// the production bootstrap nor any environment switch imports this harness.
const keys=generateKeyPairSync('ed25519'),otherKeys=generateKeyPairSync('ed25519');
const encode=(value:unknown)=>Buffer.from(JSON.stringify(value)).toString('base64url');
const hash=(s:string)=>createHash('sha256').update(s).digest('hex');
const schema=`staff_${randomUUID().replaceAll('-','')}`;
const policy:StaffPolicy={issuer:'https://staff-fixture.invalid',audience:'staff-fixture',tenant:'',origin:'https://console-fixture.invalid',
  version:'fixture-sms-v1',digestKey:randomBytes(32).toString('hex'),requiredMethods:['sms'],maxAuthenticationAgeSeconds:300,
  sessionSeconds:900,challengeSeconds:120,challengeLimitPerHour:1000,clientChallengeLimitPerHour:100,
  verificationTimeoutMs:500,maxConcurrentVerifications:4};
let now=Date.now(),admin:Database,db:Database,authority:StaffAuthority,app:Awaited<ReturnType<typeof NestFactory.create>>,base:string,databaseUrl:string;
const currentOverrides=new Map<string,Partial<CurrentStaffIdentity>>();let proofChecks=0,currentChecks=0;
const verifier:StaffIdentityVerifier={
  async verifySignIn(proof){
    proofChecks++;
    try{
      const [head,payload,signature,extra]=proof.split('.');
      if(!head||!payload||!signature||extra||JSON.parse(Buffer.from(head,'base64url').toString()).alg!=='EdDSA'
        ||!verify(null,Buffer.from(`${head}.${payload}`),keys.publicKey,Buffer.from(signature,'base64url')))throw unauthenticated();
      const c=JSON.parse(Buffer.from(payload,'base64url').toString());
      return {issuer:c.iss,audience:c.aud,tenant:c.tenant,subject:c.sub,authTime:c.auth_time,issuedAt:c.iat,expiresAt:c.exp,authenticationMethods:c.amr};
    }catch{throw unauthenticated();}
  },
  async currentIdentity(identity){currentChecks++;return {...identity,disabled:false,validAfter:0,...currentOverrides.get(identity.subject)};}
};
const identity=(subject:string):StaffIdentityReference=>({issuer:policy.issuer,audience:policy.audience,tenant:policy.tenant,subject});
function proof(subject:string,changes:Record<string,unknown>={},key=keys.privateKey){
  const seconds=Math.floor(now/1000),body=`${encode({alg:'EdDSA'})}.${encode({iss:policy.issuer,aud:policy.audience,tenant:'',sub:subject,
    iat:seconds,auth_time:seconds-1,exp:seconds+60,amr:['sms'],...changes})}`;
  return `${body}.${sign(null,Buffer.from(body),key).toString('base64url')}`;
}
const defer=()=>{let release!:()=>void;const wait=new Promise<void>(r=>{release=r;});return{wait,release};};
async function principal(permissions:StaffPermission[]=['listener.review.read']){
  const id=randomUUID(),subject=`fixture-${randomUUID()}`;
  await db.pool.query('INSERT INTO staff_principals(id,issuer,audience,tenant,provider_subject,subject_digest) VALUES($1,$2,$3,$4,$5,$6)',
    [id,policy.issuer,policy.audience,policy.tenant,subject,authority.binding(identity(subject))]);
  for(const permission of permissions)await db.pool.query("INSERT INTO staff_permission_grants(id,principal_id,permission,reason_code) VALUES($1,$2,$3,'fixture_only')",[randomUUID(),id,permission]);
  return{id,subject};
}
async function login(subject:string,changes:Record<string,unknown>={},service=authority){
  const challenge=await service.challenge(policy.origin,randomUUID());
  return service.exchange({proof:proof(subject,changes)},policy.origin,challenge.cookie,challenge.csrfToken);
}
async function request(path:string,method='GET',body?:unknown,cookie?:string,csrf?:string,origin:string|undefined=policy.origin){
  const response=await fetch(`${base}/v1/admin/${path}`,{method,headers:{...(origin?{Origin:origin}:{}),...(body===undefined?{}:{'Content-Type':'application/json'}),
    ...(cookie?{Cookie:cookie}:{}),...(csrf?{'X-CSRF-Token':csrf}:{})},...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:'error'});
  return {response,body:await response.json() as any};
}
before(async()=>{
  assert.equal(process.env.NODE_ENV,'test');assert.ok(process.env.TEST_DATABASE_URL);assert.ok(process.env.REDIS_URL);
  const url=new URL(process.env.TEST_DATABASE_URL!);assert.match(decodeURIComponent(url.pathname.slice(1)),/^[a-z0-9_]+_test$/);
  admin=new Database(url.toString());await admin.pool.query(`CREATE SCHEMA ${schema}`);url.searchParams.set('options',`-csearch_path=${schema}`);databaseUrl=url.toString();
  db=new Database(databaseUrl);await migrate(db);await migrate(db);authority=new StaffAuthority(db,policy,verifier,()=>now);
  @Module({controllers:[StaffController],providers:[{provide:StaffAuthority,useValue:authority}]}) class FixtureModule{}
  app=await NestFactory.create(FixtureModule,{logger:false});await app.listen(0,'127.0.0.1');base=await app.getUrl();
});
after(async()=>{if(app)await app.close();if(db)await db.close();if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}});

test('migration creates no staff authority and the normal bootstrap is unavailable even with fixture environment flags',async()=>{
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_principals')).rows[0].count,'0');
  const old=process.env.STAFF_AUTH_ENABLED;process.env.STAFF_AUTH_ENABLED='true';
  const runtime=await createApplication({databaseUrl,redisUrl:process.env.REDIS_URL!,port:0,devAccessKey:'isolated-staff-fixture-key-with-no-live-access'},()=>now);
  try{
    await runtime.app.listen(0,'127.0.0.1');const origin=await runtime.app.getUrl();
    const status=await fetch(`${origin}/v1/admin/auth/status`);assert.deepEqual(await status.json(),{configured:false,available:false,reasonCode:'STAFF_AUTH_UNAVAILABLE'});
    for(const path of ['session','auth/challenge','auth/exchange','auth/logout']){
      const response=await fetch(`${origin}/v1/admin/${path}`,{method:path==='session'?'GET':'POST',headers:{Origin:policy.origin,'Content-Type':'application/json',Authorization:'Bearer forged-customer-token'},...(path==='session'?{}:{body:'{}'})});
      const result=await response.json() as any;
      assert.equal(response.status,503);assert.equal(result.error.code,'STAFF_AUTH_UNAVAILABLE');
      assert.equal(result.requestId,response.headers.get('x-request-id'));
    }
  }finally{await runtime.close();if(old===undefined)delete process.env.STAFF_AUTH_ENABLED;else process.env.STAFF_AUTH_ENABLED=old;}
});

test('signed proof exchanges for a minimal opaque cookie session, never an ordinary app identity',async()=>{
  const user=await principal(['listener.review.read','listener.review.evidence.read']);
  const challenge=await request('auth/challenge','POST',{});assert.equal(challenge.response.status,200);
  const challengeSet=challenge.response.headers.getSetCookie()[0]!;
  assert.match(challengeSet,/^__Host-nightshift_staff_challenge=[a-f0-9]{64}; Path=\/; Max-Age=120; Secure; HttpOnly; SameSite=Strict$/);
  const login=await request('auth/exchange','POST',{proof:proof(user.subject)},challengeSet.split(';')[0],challenge.body.csrfToken);
  assert.equal(login.response.status,200);assert.deepEqual(login.body.staff,{id:user.id});assert.equal(login.body.permissions.length,2);
  const set=login.response.headers.getSetCookie(),session=set.find(v=>v.startsWith(`${STAFF_COOKIE}=`))!;
  assert.match(session,/^__Host-nightshift_staff=[a-f0-9]{64}; Path=\/; Max-Age=900; Secure; HttpOnly; SameSite=Strict$/);
  const cookie=session.split(';')[0]!,raw=cookie.split('=')[1]!;
  const current=await request('session','GET',undefined,cookie);assert.deepEqual(current.body,login.body);
  assert.equal(current.response.headers.get('cache-control'),'no-store');assert.equal(current.response.headers.get('access-control-allow-origin'),null);
  assert.doesNotMatch(JSON.stringify(login.body),new RegExp(`${user.subject}|${raw}`));
  assert.equal((await db.pool.query('SELECT count(*) FROM users')).rows[0].count,'0');
  const stored=(await db.pool.query('SELECT * FROM staff_sessions WHERE principal_id=$1',[user.id])).rows[0];assert.equal(stored.token_hash,hash(raw));
  assert.doesNotMatch(JSON.stringify(stored),new RegExp(raw));
});

test('real staff HTTP status, challenge, session, logout and errors match the separate public contract',async()=>{
  const contract=require('@nightshift/contracts/staff.openapi.json');
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  const validate=(name:string,value:unknown)=>{
    const check=ajv.compile({$defs:definitions,$ref:`#/$defs/${name}`});assert.equal(check(value),true,JSON.stringify(check.errors));
  };
  const user=await principal(),status=await request('auth/status');validate('StaffAuthStatus',status.body);
  const challenge=await request('auth/challenge','POST',{});validate('StaffChallenge',challenge.body);
  const challengeCookie=challenge.response.headers.getSetCookie()[0]!.split(';')[0];
  const session=await request('auth/exchange','POST',{proof:proof(user.subject)},challengeCookie,challenge.body.csrfToken);
  assert.equal(session.response.status,200);validate('StaffSession',session.body);
  const sessionCookie=session.response.headers.getSetCookie().find(v=>v.startsWith(`${STAFF_COOKIE}=`))!.split(';')[0];
  validate('StaffSession',(await request('session','GET',undefined,sessionCookie)).body);
  const denied=await request('auth/logout','POST',{},sessionCookie,'0'.repeat(64));assert.equal(denied.response.status,403);validate('StaffError',denied.body);
  const logout=await request('auth/logout','POST',{},sessionCookie,session.body.csrfToken);assert.equal(logout.response.status,200);validate('StaffLogout',logout.body);
  assert.ok(logout.response.headers.getSetCookie().every(v=>v.includes('Max-Age=0; Secure; HttpOnly; SameSite=Strict')));
  const revoked=await request('session','GET',undefined,sessionCookie);assert.equal(revoked.response.status,401);validate('StaffError',revoked.body);
});

test('origin, JSON and single-use challenge checks prevent cross-origin and replayed exchanges',async()=>{
  const user=await principal(),checks=proofChecks;
  for(const origin of [undefined,'null','https://other-fixture.invalid',`${policy.origin}/`]){
    const response=await fetch(`${base}/v1/admin/auth/challenge`,{method:'POST',headers:{...(origin?{Origin:origin}:{}),'Content-Type':'application/json'},body:'{}'});
    assert.equal(response.status,403);
  }
  assert.equal(proofChecks,checks);
  const challenge=await authority.challenge(policy.origin,randomUUID());
  await assert.rejects(authority.exchange({proof:proof(user.subject)},policy.origin,challenge.cookie,'0'.repeat(64)),{code:'STAFF_CSRF_INVALID'});
  const outcomes=await Promise.allSettled([1,2].map(()=>authority.exchange({proof:proof(user.subject)},policy.origin,challenge.cookie,challenge.csrfToken)));
  assert.equal(outcomes.filter(r=>r.status==='fulfilled').length,1);
  assert.equal((outcomes.find(r=>r.status==='rejected') as PromiseRejectedResult).reason.code,'STAFF_CSRF_INVALID');
  assert.equal(proofChecks,checks+1);
});

test('unknown identities and forged customer roles cannot enroll or acquire grants',async()=>{
  const before=(await db.pool.query('SELECT count(*) FROM staff_principals')).rows[0].count;
  await assert.rejects(login(`unknown-${randomUUID()}`,{admin:true,roles:['admin'],listenerApproved:true}),{code:'STAFF_UNAUTHENTICATED'});
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_principals')).rows[0].count,before);
  const user=await principal([]);await assert.rejects(login(user.subject,{admin:true,roles:['admin']}),{code:'STAFF_FORBIDDEN'});
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_sessions WHERE principal_id=$1',[user.id])).rows[0].count,'0');
});

test('signed issuer, audience, method, timestamp and signature failures cannot create sessions',async()=>{
  const user=await principal(),seconds=Math.floor(now/1000);
  for(const changes of [{iss:'https://wrong.invalid'},{aud:'customer-app'},{tenant:'other'},{amr:[]},{amr:['password']},{amr:['sms','sms']},
    {auth_time:seconds-301},{auth_time:seconds+1},{iat:seconds+1},{exp:seconds},{sub:'+919999999999'},{auth_time:null}]){
    await assert.rejects(login(user.subject,changes),{code:'STAFF_UNAUTHENTICATED'});
  }
  const challenge=await authority.challenge(policy.origin,randomUUID());
  await assert.rejects(authority.exchange({proof:proof(user.subject,{},otherKeys.privateKey)},policy.origin,challenge.cookie,challenge.csrfToken),{code:'STAFF_UNAUTHENTICATED'});
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_sessions WHERE principal_id=$1',[user.id])).rows[0].count,'0');
});

test('session authority is cookie-only and CSRF is bound to the current cookie',async()=>{
  const a=await principal(),b=await principal(),one=await login(a.subject),two=await login(b.subject);
  const response=await fetch(`${base}/v1/admin/session`,{headers:{Authorization:`Bearer ${one.cookie}`}});assert.equal(response.status,401);
  const duplicated=await request('session','GET',undefined,`${STAFF_COOKIE}=${one.cookie}; ${STAFF_COOKIE}=${two.cookie}`);assert.equal(duplicated.response.status,401);
  await assert.rejects(authority.logout(one.cookie,two.view.csrfToken,policy.origin),{code:'STAFF_CSRF_INVALID'});
  await assert.rejects(authority.session(one.cookie,'https://other.invalid'),{code:'STAFF_ORIGIN_DENIED'});
  assert.equal((await authority.session(one.cookie)).staff.id,a.id);
});

test('replacement login revokes old cookies and an old logout cannot revoke the replacement',async()=>{
  const user=await principal(),one=await login(user.subject);now+=2000;const two=await login(user.subject);
  await assert.rejects(authority.authenticate(one.cookie),{code:'STAFF_UNAUTHENTICATED'});
  await assert.rejects(authority.logout(one.cookie,one.view.csrfToken,policy.origin),{code:'STAFF_UNAUTHENTICATED'});
  assert.equal((await authority.session(two.cookie)).staff.id,user.id);
});

test('logout is local during provider outage and old authentication lineage cannot re-exchange',async t=>{
  const user=await principal(),session=await login(user.subject),authTime=Math.floor(now/1000)-1;
  const mock=t.mock.method(verifier,'currentIdentity',async()=>{throw new Error('private-provider-secret');});
  await authority.logout(session.cookie,session.view.csrfToken,policy.origin);mock.mock.restore();
  await assert.rejects(authority.authenticate(session.cookie),{code:'STAFF_UNAUTHENTICATED'});
  now+=2000;await assert.rejects(login(user.subject,{auth_time:authTime}),{code:'STAFF_UNAUTHENTICATED'});
  assert.equal((await login(user.subject)).view.staff.id,user.id);
});

test('provider disablement, revocation and mismatched lookup identity reject an otherwise live cookie',async()=>{
  const user=await principal(),session=await login(user.subject);
  for(const state of [{disabled:true},{validAfter:Math.floor(now/1000)+1},{subject:'different-provider-user'}]){
    currentOverrides.set(user.subject,state);await assert.rejects(authority.authenticate(session.cookie),{code:'STAFF_UNAUTHENTICATED'});
  }
  currentOverrides.delete(user.subject);assert.equal((await authority.session(session.cookie)).staff.id,user.id);
});

test('grant changes invalidate admitted actors and require fresh authentication, with no denied-action audit effect',async()=>{
  const user=await principal(['listener.review.read','listener.review.evidence.read']),session=await login(user.subject),actor=await authority.authenticate(session.cookie);
  await db.pool.query("UPDATE staff_permission_grants SET revoked_at=GREATEST(granted_at,now()) WHERE principal_id=$1 AND permission='listener.review.evidence.read'",[user.id]);
  const before=(await db.pool.query('SELECT count(*) FROM staff_audit_events WHERE principal_id=$1',[user.id])).rows[0].count;
  await assert.rejects(db.tx(c=>authority.authorize(c,actor,'listener.review.read')),{code:'STAFF_UNAUTHENTICATED'});
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_audit_events WHERE principal_id=$1',[user.id])).rows[0].count,before);
  now+=2000;const fresh=await login(user.subject),current=await authority.authenticate(fresh.cookie);
  await assert.rejects(db.tx(c=>authority.authorize(c,current,'listener.review.decide')),{code:'STAFF_FORBIDDEN'});
  assert.deepEqual((await db.tx(c=>authority.authorize(c,current,'listener.review.read'))).permissions,['listener.review.read']);
});

test('a grant revoked during provider lookup cannot leave a newly admitted session actor',async t=>{
  const user=await principal(),session=await login(user.subject),entered=defer(),release=defer(),original=verifier.currentIdentity.bind(verifier);
  const mock=t.mock.method(verifier,'currentIdentity',async(ref:StaffIdentityReference)=>{const result=await original(ref);entered.release();await release.wait;return result;});
  const pending=authority.authenticate(session.cookie);await entered.wait;
  try{await db.pool.query('UPDATE staff_permission_grants SET revoked_at=GREATEST(granted_at,now()) WHERE principal_id=$1',[user.id]);release.release();await assert.rejects(pending,{code:'STAFF_UNAUTHENTICATED'});}
  finally{release.release();await pending.catch(()=>{});mock.mock.restore();}
});

test('principal locking serializes a valid action before revocation and rejects later actions',async()=>{
  const user=await principal(),session=await login(user.subject),actor=await authority.authenticate(session.cookie),entered=defer(),release=defer();
  const work=db.tx(async c=>{await authority.authorize(c,actor,'listener.review.read');entered.release();await release.wait;});await entered.wait;
  const client=await db.pool.connect();
  try{
    const pid=(await client.query('SELECT pg_backend_pid() pid')).rows[0].pid;
    const revoke=client.query('UPDATE staff_principals SET disabled=true WHERE id=$1',[user.id]);
    for(let n=0;;n++){
      const blocked=(await db.pool.query('SELECT cardinality(pg_blocking_pids($1)) count',[pid])).rows[0].count;
      if(blocked>0)break;assert.ok(n<100,'revocation did not wait for authorized transaction');await new Promise(r=>setTimeout(r,10));
    }
    release.release();await work;await revoke;
    await assert.rejects(db.tx(c=>authority.authorize(c,actor,'listener.review.read')),{code:'STAFF_UNAUTHENTICATED'});
  }finally{release.release();await work;client.release();}
});

test('expired sessions and malformed/customer actors cannot authorize actions',async()=>{
  const user=await principal(),session=await login(user.subject),actor=await authority.authenticate(session.cookie);
  await db.pool.query('UPDATE staff_sessions SET expires_at=created_at+interval \'1 millisecond\' WHERE principal_id=$1',[user.id]);now+=1000;
  await assert.rejects(db.tx(c=>authority.authorize(c,actor,'listener.review.read')),{code:'STAFF_UNAUTHENTICATED'});
  await assert.rejects(db.tx(c=>authority.authorize(c,{id:user.id,sessionHash:actor.sessionHash} as any,'listener.review.read')),{code:'STAFF_UNAUTHENTICATED'});
});

test('audit, identity bindings and revocation history cannot be rewritten',async()=>{
  const user=await principal(),session=await login(user.subject);await authority.logout(session.cookie,session.view.csrfToken,policy.origin);
  await assert.rejects(db.pool.query('DELETE FROM staff_audit_events WHERE principal_id=$1',[user.id]),{code:'23514'});
  await assert.rejects(db.pool.query("UPDATE staff_principals SET provider_subject='replacement' WHERE id=$1",[user.id]),{code:'23514'});
  await assert.rejects(db.pool.query('UPDATE staff_principals SET authority_version=1,revoked_before=0 WHERE id=$1',[user.id]),{code:'23514'});
  await assert.rejects(db.pool.query('DELETE FROM staff_permission_grants WHERE principal_id=$1',[user.id]),{code:'23514'});
});

test('an existing cookie cannot cross a changed issuer, audience, binding key or authentication policy',async()=>{
  const user=await principal(),session=await login(user.subject);
  for(const change of [{issuer:'https://other-fixture.invalid'},{audience:'different-staff-app'},
    {digestKey:randomBytes(32).toString('hex')},{requiredMethods:['totp']},{version:'different-policy'}]){
    const changed=new StaffAuthority(db,{...policy,...change},verifier,()=>now);
    await assert.rejects(changed.authenticate(session.cookie),{code:'STAFF_UNAUTHENTICATED'});
  }
});

test('hung provider work retains its capacity slot after caller timeout and cannot accumulate retries',async()=>{
  const user=await principal(),gate=defer();let calls=0;
  const limited=new StaffAuthority(db,{...policy,verificationTimeoutMs:20,maxConcurrentVerifications:1},{
    async verifySignIn(value){calls++;await gate.wait;return verifier.verifySignIn(value);},currentIdentity:verifier.currentIdentity.bind(verifier)},()=>now);
  try{
    await assert.rejects(login(user.subject,{},limited),{code:'STAFF_AUTH_UNAVAILABLE'});
    await assert.rejects(login(user.subject,{},limited),{code:'STAFF_AUTH_UNAVAILABLE'});assert.equal(calls,1);
  }finally{gate.release();}
});

test('challenge expiry and bounded issuance fail before provider work',async()=>{
  const limited=new StaffAuthority(db,{...policy,challengeLimitPerHour:1,clientChallengeLimitPerHour:1},verifier,()=>now+7200000);
  const first=await limited.challenge(policy.origin,'one-fixture-client');
  await assert.rejects(limited.challenge(policy.origin,'different-fixture-client'),{code:'STAFF_RATE_LIMITED'});
  const checks=proofChecks;
  await db.pool.query('UPDATE staff_auth_challenges SET expires_at=created_at+interval \'1 millisecond\' WHERE cookie_hash=$1',[hash(first.cookie)]);
  const expired=new StaffAuthority(db,policy,verifier,()=>now+7201000);
  await assert.rejects(expired.exchange({proof:'synthetic'},policy.origin,first.cookie,first.csrfToken),{code:'STAFF_CSRF_INVALID'});assert.equal(proofChecks,checks);
});
