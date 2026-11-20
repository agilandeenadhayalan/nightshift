import 'reflect-metadata';
import { after,before,test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash,generateKeyPairSync,randomBytes,randomUUID,sign,verify } from 'node:crypto';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { Auth } from '../src/auth';
import { Config,loadConfig } from '../src/config';
import { Presence } from '../src/presence';
import { PhoneAuthentication } from '../src/identity/phone-auth';
import { FirebaseIdentityProvider } from '../src/identity/firebase';
import { StaffAuthority,StaffPermission } from '../src/staff/authority';
import { StaffAppBinding } from '../src/staff/app-binding';
import { FirebaseStaffVerifier } from '../src/staff/firebase';
import { StaffPolicy } from '../src/staff/verifier';
import { StaffController,STAFF_COOKIE,STAFF_CHALLENGE_COOKIE } from '../src/staff/http';
import { AccountLifecycle,DELETION_NOTICE_VERSION } from '../src/account-lifecycle';

const schema=`staff_native_${randomUUID().replaceAll('-','')}`,project='staff-native-fixture',key=randomBytes(32).toString('hex');
const signing=generateKeyPairSync('ed25519'),encode=(value:unknown)=>Buffer.from(JSON.stringify(value)).toString('base64url');
let now=Date.now(),sequence=100,db:Database,admin:Database,auth:Auth,phone:PhoneAuthentication,authority:StaffAuthority,base:string;
let app:Awaited<ReturnType<typeof NestFactory.create>>;
const users=new Map<string,{uid:string;phoneNumber:string;disabled:boolean;tokensValidAfterTime?:string}>();
const config:Config={databaseUrl:'',redisUrl:'',port:0,devAccessKey:'synthetic-native-staff-key',phoneAuth:{provider:'firebase',projectId:project,
  digestKey:key,consentVersion:'fixture-v1',dailyAdmissionLimit:100}};
const policy:StaffPolicy={issuer:`https://securetoken.google.com/${project}`,audience:project,tenant:'',origin:'https://staff-fixture.invalid',
  version:'native-fixture-v1',digestKey:randomBytes(32).toString('hex'),requiredMethods:['sms'],requireAppBinding:true,
  maxAuthenticationAgeSeconds:3600,sessionSeconds:1800,challengeSeconds:120,challengeLimitPerHour:1000,clientChallengeLimitPerHour:100,
  verificationTimeoutMs:500,maxConcurrentVerifications:4};
const defer=()=>{let resolve!:()=>void;const promise=new Promise<void>(r=>{resolve=r;});return{resolve,promise};};
let getUserGate:ReturnType<typeof defer>|undefined,getUserEntered:ReturnType<typeof defer>|undefined;
// Signed provider harness is confined to this isolated test file. The real
// factory never imports it or selects a fixture through environment values.
const client={
  async verifyIdToken(token:string,checkRevoked?:boolean){
    assert.equal(checkRevoked,true);const [h,p,s]=token.split('.');
    if(!h||!p||!s||!verify(null,Buffer.from(`${h}.${p}`),signing.publicKey,Buffer.from(s,'base64url')))throw {code:'auth/invalid-id-token'};
    const claims=JSON.parse(Buffer.from(p,'base64url').toString());const user=users.get(claims.uid);
    if(!user||user.disabled)throw {code:'auth/user-disabled'};
    if(user.tokensValidAfterTime&&claims.auth_time<Math.floor(Date.parse(user.tokensValidAfterTime)/1000))throw {code:'auth/id-token-revoked'};
    return claims;
  },
  async getUser(uid:string){getUserEntered?.resolve();await getUserGate?.promise;const user=users.get(uid);if(!user)throw {code:'auth/user-not-found'};return {...user} as any;},
  async createCustomToken(){throw new Error('not used');}
};
const provider=new FirebaseIdentityProvider(client as any,project,()=>now);
const verifier=new FirebaseStaffVerifier(client as any,project,key,()=>now);
const presence={async rateLimit(){return true;},async clear(){}} as unknown as Presence;
function proof(uid:string,mobile:string,authTime=Math.floor(now/1000),extra:Record<string,unknown>={}){
  const sec=Math.floor(now/1000),payload={uid,sub:uid,iss:policy.issuer,aud:project,auth_time:authTime,iat:sec,exp:sec+3600,
    phone_number:mobile,firebase:{sign_in_provider:'phone',identities:{phone:[mobile]}},...extra};
  const unsigned=`${encode({alg:'EdDSA'})}.${encode(payload)}`;return `${unsigned}.${sign(null,Buffer.from(unsigned),signing.privateKey).toString('base64url')}`;
}
async function account(){
  const uid=`opaque:${randomUUID()}`,mobile=`+919${String(++sequence).padStart(9,'0')}`,device=`fixture-${randomUUID()}`;
  users.set(uid,{uid,phoneNumber:mobile,disabled:false});const token=proof(uid,mobile),authTime=Math.floor(now/1000);
  const admission=await phone.admit({phone:mobile,deviceId:device,consentVersion:'fixture-v1'},randomUUID(),randomUUID());
  const result=await auth.exchange({idToken:token,deviceId:device,attemptId:admission.attemptId},randomUUID());
  await db.pool.query('UPDATE users SET adult_confirmed=true WHERE id=$1',[result.userId]);
  return {uid,mobile,device,token,authTime,userId:result.userId};
}
async function approved(permissions:StaffPermission[]=['listener.review.read','staff.access.manage']){
  const a=await account(),request=await authority.accessRequest(a.token,true);
  await authority.provision(request.requestId,a.userId,permissions,true);return {...a,request};
}
async function login(token:string){const c=await authority.challenge(policy.origin,randomUUID(),token);
  return authority.exchange({proof:token},policy.origin,c.cookie,c.csrfToken,token);}
async function http(path:string,method='GET',token?:string,body?:unknown,cookie?:string,csrf?:string){
  const response=await fetch(`${base}/v1/admin/${path}`,{method,redirect:'error',headers:{Origin:policy.origin,
    ...(token?{Authorization:`Bearer ${token}`} :{}),...(body===undefined?{}:{'Content-Type':'application/json'}),
    ...(cookie?{Cookie:cookie}:{}),...(csrf?{'X-CSRF-Token':csrf}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
  return {response,body:await response.json() as any};
}
before(async()=>{
  assert.equal(process.env.NODE_ENV,'test');const url=new URL(process.env.TEST_DATABASE_URL!);assert.match(url.pathname,/_test$/);
  admin=new Database(url.toString());await admin.pool.query(`CREATE SCHEMA ${schema}`);url.searchParams.set('options',`-csearch_path=${schema}`);
  db=new Database(url.toString());await migrate(db);await migrate(db);
  phone=new PhoneAuthentication(db,presence,config.phoneAuth,{firebase:provider},()=>now);auth=new Auth(db,presence,config,phone,()=>now);
  authority=new StaffAuthority(db,policy,verifier,()=>now,new StaffAppBinding(auth,config.phoneAuth!,()=>now));
  @Module({controllers:[StaffController],providers:[{provide:StaffAuthority,useValue:authority}]})class Harness{}
  app=await NestFactory.create(Harness,{logger:false});await app.listen(0,'127.0.0.1');base=await app.getUrl();
});
after(async()=>{getUserGate?.resolve();if(app)await app.close();if(db)await db.close();if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}});

test('real adapter accepts only signed current phone identity and detects changed current phone',async()=>{
  const a=await account();assert.equal((await verifier.verifySignIn(a.token)).subject,a.uid);
  await assert.rejects(verifier.verifySignIn(`${a.token.slice(0,-4)}AAAA`),{code:'STAFF_UNAUTHENTICATED'});
  await assert.rejects(verifier.verifySignIn(proof(a.uid,a.mobile,a.authTime,{firebase:{sign_in_provider:'custom'}})),{code:'STAFF_UNAUTHENTICATED'});
  await assert.rejects(verifier.verifySignIn(proof(a.uid,a.mobile,a.authTime,{aud:'other-project'})),{code:'STAFF_UNAUTHENTICATED'});
  await assert.rejects(verifier.verifySignIn(proof(a.uid,a.mobile,a.authTime,{firebase:{sign_in_provider:'phone',tenant:'other',identities:{phone:[a.mobile]}}})),{code:'STAFF_UNAUTHENTICATED'});
});
test('pending request is own-account idempotent, creates no authority, and dry run is read-only',async()=>{
  const a=await account();await assert.rejects(authority.accessRequest(a.token,false),{code:'STAFF_ACCESS_REQUEST_NOT_FOUND'});
  const r=await authority.accessRequest(a.token,true);assert.equal(r.accountReference,a.userId);assert.equal(r.status,'pending');
  assert.deepEqual(await authority.accessRequest(a.token,true),r);assert.deepEqual(await authority.accessRequest(a.token,false),r);
  const counts=async()=> (await db.pool.query('SELECT (SELECT count(*) FROM staff_principals) p,(SELECT count(*) FROM staff_permission_grants) g,(SELECT count(*) FROM staff_audit_events) a')).rows[0];
  const before=await counts(),dry=await authority.provision(r.requestId,a.userId,['listener.review.read']);assert.equal(dry.applied,false);assert.deepEqual(await counts(),before);
  await assert.rejects(authority.provision(r.requestId,randomUUID(),['staff.access.manage'],true),{code:'STAFF_ACCESS_REQUEST_NOT_FOUND'});
  await assert.rejects(login(a.token),{code:'STAFF_ACCESS_NOT_APPROVED'});
});
test('explicit exact reference provisioning is idempotent and exposes only opaque refs',async()=>{
  const a=await approved();assert.equal((await authority.accessRequest(a.token,false)).status,'provisioned');
  const retry=await authority.provision(a.request.requestId,a.userId,['listener.review.read','staff.access.manage'],true);assert.deepEqual(retry.adding,[]);
  const session=await login(a.token);assert.deepEqual(session.view.permissions,['listener.review.read','staff.access.manage']);
  const publicJson=JSON.stringify(session.view);assert.ok(!publicJson.includes(a.uid));assert.ok(!publicJson.includes(a.mobile));assert.ok(!publicJson.includes(a.token));
  assert.equal(session.maxAgeSeconds,1800);assert.deepEqual(await authority.session(session.cookie),session.view);
});
test('HTTP native boundary requires app bearer, exact empty body, CSRF and same proof bearer',async()=>{
  const a=await approved(),b=await account();
  assert.equal((await http('access-requests','POST',undefined,{})).response.status,401);
  assert.equal((await http('access-requests','POST',a.token,{userId:b.userId})).response.status,400);
  const missing=await http('access-requests/current','GET',b.token);assert.equal(missing.response.status,404);
  const challenge=await http('auth/challenge','POST',a.token,{});assert.equal(challenge.response.status,200);
  const cookie=challenge.response.headers.getSetCookie()[0]!.split(';')[0];assert.ok(cookie?.startsWith(STAFF_CHALLENGE_COOKIE));
  const bad=await http('auth/exchange','POST',a.token,{proof:b.token},cookie,challenge.body.csrfToken);assert.equal(bad.response.status,401);
  const replay=await http('auth/exchange','POST',a.token,{proof:a.token},cookie,challenge.body.csrfToken);assert.equal(replay.body.error.code,'STAFF_CSRF_INVALID');
  const c=await http('auth/challenge','POST',a.token,{}),login=await http('auth/exchange','POST',a.token,{proof:a.token},c.response.headers.getSetCookie()[0]!.split(';')[0],c.body.csrfToken);
  assert.equal(login.response.status,200);assert.match(login.response.headers.getSetCookie()[0]!,new RegExp(`^${STAFF_COOKIE}=[a-f0-9]{64}; Path=/; Max-Age=1800; Secure; HttpOnly; SameSite=Strict$`));
});
test('another current approved account cannot consume the first account challenge',async()=>{
  const a=await approved(),b=await approved(),c=await authority.challenge(policy.origin,randomUUID(),a.token);
  await assert.rejects(authority.exchange({proof:b.token},policy.origin,c.cookie,c.csrfToken,b.token),{code:'STAFF_CSRF_INVALID'});
});
test('same-device token refresh preserves staff lineage but stale bearer cannot start native work',async()=>{
  const a=await approved(),s=await login(a.token);now+=2000;const refreshed=proof(a.uid,a.mobile,a.authTime);
  await auth.exchange({idToken:refreshed,deviceId:a.device},randomUUID());assert.deepEqual(await authority.session(s.cookie),s.view);
  await assert.rejects(authority.challenge(policy.origin,randomUUID(),a.token),{code:'UNAUTHENTICATED'});
  assert.equal((await authority.accessRequest(refreshed,false)).requestId,a.request.requestId);
});
test('app logout and device takeover invalidate staff cookies without reverse lock callbacks',async()=>{
  const a=await approved(),s=await login(a.token);await auth.logout(await auth.authenticate(a.token));
  await assert.rejects(authority.session(s.cookie),{code:'STAFF_UNAUTHENTICATED'});
  const b=await approved(),other=await login(b.token);now+=2000;
  await auth.exchange({idToken:proof(b.uid,b.mobile),deviceId:'replacement'},randomUUID());
  await assert.rejects(authority.session(other.cookie),{code:'STAFF_UNAUTHENTICATED'});
});
test('deletion immediately invalidates staff source authority and pending enrollment',async()=>{
  const a=await approved(),s=await login(a.token);
  await new AccountLifecycle(db,()=>now).requestDeletion(await auth.authenticate(a.token),{noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
  await assert.rejects(authority.session(s.cookie),{code:'STAFF_UNAUTHENTICATED'});
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_access_requests WHERE user_id=$1',[a.userId])).rows[0].count,'0');
  await assert.rejects(authority.provision(a.request.requestId,a.userId,['staff.access.manage'],true),{code:'STAFF_ACCESS_REQUEST_NOT_FOUND'});
});
test('provider disable, revocation and changed phone invalidate cookie authority',async()=>{
  for(const kind of ['disable','revoke','phone']){
    const a=await approved(),s=await login(a.token),u=users.get(a.uid)!;
    if(kind==='disable')u.disabled=true;else if(kind==='revoke')u.tokensValidAfterTime=new Date((a.authTime+1)*1000).toISOString();else u.phoneNumber='+918888888888';
    await assert.rejects(authority.session(s.cookie),{code:'STAFF_UNAUTHENTICATED'});
  }
});
test('changed provider phone before exchange cannot mint a cookie even with a signed unexpired old token',async()=>{
  const a=await approved(),c=await authority.challenge(policy.origin,randomUUID(),a.token);
  users.get(a.uid)!.phoneNumber='+918888888888';
  const before=(await db.pool.query('SELECT count(*) FROM staff_sessions')).rows[0].count;
  await assert.rejects(authority.exchange({proof:a.token},policy.origin,c.cookie,c.csrfToken,a.token),{code:'STAFF_UNAUTHENTICATED'});
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_sessions')).rows[0].count,before);
});
test('logout during provider lookup wins before local staff authorization',async()=>{
  const a=await approved(),s=await login(a.token);getUserGate=defer();getUserEntered=defer();
  const pending=authority.session(s.cookie);await getUserEntered.promise;
  await auth.logout(await auth.authenticate(a.token));getUserGate.resolve();
  await assert.rejects(pending,{code:'STAFF_UNAUTHENTICATED'});getUserGate=undefined;getUserEntered=undefined;
});
test('authority action rechecks app lineage after a previously successful guard',async()=>{
  const a=await approved(),s=await login(a.token),actor=await authority.authenticate(s.cookie);
  await auth.logout(await auth.authenticate(a.token));
  await assert.rejects(db.tx(c=>authority.authorize(c,actor,'listener.review.read',[randomUUID()])),{code:'STAFF_UNAUTHENTICATED'});
});
test('new authentication cannot recover an old pending reference and proof challenge is one use',async()=>{
  const a=await account(),r=await authority.accessRequest(a.token,true);now+=2000;const token=proof(a.uid,a.mobile);
  await auth.exchange({idToken:token,deviceId:a.device},randomUUID());
  await assert.rejects(authority.accessRequest(token,false),{code:'STAFF_ACCESS_REQUEST_NOT_FOUND'});
  await assert.rejects(authority.provision(r.requestId,a.userId,['listener.review.read'],true),{code:'STAFF_UNAUTHENTICATED'});
  const b=await approved(),c=await authority.challenge(policy.origin,randomUUID(),b.token);
  const results=await Promise.allSettled([1,2].map(()=>authority.exchange({proof:b.token},policy.origin,c.cookie,c.csrfToken,b.token)));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.filter(r=>r.status==='rejected').length,1);
});
test('fresh-auth limit uses auth_time rather than refreshed iat and session expiry is bounded',async()=>{
  const a=await approved(),s=await login(a.token);now+=3601000;const token=proof(a.uid,a.mobile,a.authTime);
  await auth.exchange({idToken:token,deviceId:a.device},randomUUID());
  await assert.rejects(authority.challenge(policy.origin,randomUUID(),token),{code:'STAFF_FRESH_SIGN_IN_REQUIRED'});
  await assert.rejects(authority.session(s.cookie),{code:'STAFF_UNAUTHENTICATED'});
});
test('expired request private data is removed in bounded cleanup while authority audit remains',async()=>{
  await authority.cleanupAccessRequests();const a=await approved(),b=await account();await authority.accessRequest(b.token,true);
  const audit=(await db.pool.query('SELECT count(*) FROM staff_audit_events')).rows[0].count;now+=3600001;
  assert.equal(await authority.cleanupAccessRequests(1),1);
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_access_requests WHERE user_id=ANY($1::uuid[])',[[a.userId,b.userId]])).rows[0].count,'1');
  assert.equal(await authority.cleanupAccessRequests(1),1);assert.equal((await db.pool.query('SELECT count(*) FROM staff_audit_events')).rows[0].count,audit);
});
test('deletion erases unprovisioned challenge binding while preserving its rate accounting',async()=>{
  const a=await account(),challenge=await authority.challenge(policy.origin,randomUUID(),a.token);
  const digest=createHash('sha256').update(challenge.cookie).digest('hex');
  await new AccountLifecycle(db,()=>now).requestDeletion(await auth.authenticate(a.token),{noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
  const rows=(await db.pool.query('SELECT app_binding,client_digest FROM staff_auth_challenges WHERE cookie_hash=$1',[digest])).rows;
  assert.equal(rows.length,1);assert.equal(rows[0].app_binding,null);assert.match(rows[0].client_digest,/^[a-f0-9]{64}$/);
});
test('autonomous challenge cleanup removes expired private binding without resetting hourly quota',async()=>{
  const a=await account(),clientKey=randomUUID(),limited=new StaffAuthority(db,{...policy,clientChallengeLimitPerHour:1},verifier,()=>now,new StaffAppBinding(auth,config.phoneAuth!,()=>now));
  const challenge=await limited.challenge(policy.origin,clientKey,a.token),digest=createHash('sha256').update(challenge.cookie).digest('hex');
  now+=120001;await authority.cleanupAccessRequests();
  const row=(await db.pool.query('SELECT app_binding FROM staff_auth_challenges WHERE cookie_hash=$1',[digest])).rows[0];
  assert.ok(row);assert.equal(row.app_binding,null);
  await assert.rejects(limited.challenge(policy.origin,clientKey,a.token),{code:'STAFF_RATE_LIMITED'});
  now+=3480000;await authority.cleanupAccessRequests();
  assert.equal((await db.pool.query('SELECT count(*) FROM staff_auth_challenges WHERE cookie_hash=$1',[digest])).rows[0].count,'0');
});
test('challenge issuance and account deletion keep owner-before-challenge lock order',async()=>{
  const a=await account(),old=await authority.challenge(policy.origin,randomUUID(),a.token),actor=await auth.authenticate(a.token);
  await db.pool.query('UPDATE staff_auth_challenges SET created_at=$2,expires_at=$3 WHERE cookie_hash=$1',
    [createHash('sha256').update(old.cookie).digest('hex'),new Date(now-3600001),new Date(now-1)]);
  const entered=defer(),release=defer(),deletionEntered=defer();
  const binding=new StaffAppBinding(auth,config.phoneAuth!,()=>now),originalAssert=binding.assert.bind(binding);
  binding.assert=async(...args)=>{entered.resolve();await release.promise;return originalAssert(...args);};
  const service=new StaffAuthority(db,policy,verifier,()=>now,binding),originalTx=db.tx.bind(db);
  db.tx=work=>originalTx(async c=>{
    const originalQuery=c.query;
    c.query=(function(...args:any[]){
      if(typeof args[0]==='string'&&args[0].includes('UPDATE users SET suspended=true'))deletionEntered.resolve();
      return (originalQuery as any).apply(c,args);
    }) as typeof c.query;
    try{return await work(c);}finally{c.query=originalQuery;}
  });
  try{
    const challenge=service.challenge(policy.origin,randomUUID(),a.token);await entered.promise;
    const deletion=new AccountLifecycle(db,()=>now).requestDeletion(actor,{noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
    const outcomes=Promise.allSettled([challenge,deletion]);await deletionEntered.promise;release.resolve();
    const [challengeResult,deletionResult]=await outcomes;
    assert.equal(deletionResult.status,'fulfilled');assert.equal(challengeResult.status,'rejected');
    if(challengeResult.status==='rejected')assert.equal(challengeResult.reason.code,'STAFF_UNAUTHENTICATED');
    assert.equal((await db.pool.query('SELECT suspended FROM users WHERE id=$1',[a.userId])).rows[0].suspended,true);
  }finally{release.resolve();db.tx=originalTx;}
});
test('real staff configuration remains explicit and bounded without a fixture switch',()=>{
  const env={NODE_ENV:'test',DEV_AUTH_ENABLED:'true',DEV_ACCESS_KEY:'fixture-key-123456789012345',DATABASE_URL:'postgres://fixture',REDIS_URL:'redis://fixture',
    STAFF_AUTH_ENABLED:'true'};assert.throws(()=>loadConfig(env));
  const full={...env,PHONE_AUTH_ENABLED:'true',PHONE_AUTH_PROVIDER:'firebase',FIREBASE_PROJECT_ID:project,PHONE_AUTH_DIGEST_KEY:key,
    PHONE_AUTH_CONSENT_VERSION:'fixture-v1',PHONE_AUTH_DAILY_ADMISSION_LIMIT:'10',STAFF_CONSOLE_ORIGIN:policy.origin,STAFF_AUTH_DIGEST_KEY:policy.digestKey,STAFF_AUTH_POLICY_VERSION:'sms-v1'};
  assert.equal(loadConfig(full).staffAuth?.sessionSeconds,1800);assert.throws(()=>loadConfig({...full,STAFF_SESSION_SECONDS:'1801'}));
  assert.throws(()=>loadConfig({...full,STAFF_CONSOLE_ORIGIN:'http://127.0.0.1'}));assert.throws(()=>loadConfig({...full,NODE_ENV:'production'}));
});
