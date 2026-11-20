import 'reflect-metadata';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { Auth } from '../src/auth';
import { Config } from '../src/config';
import { Presence } from '../src/presence';
import { PhoneAuthentication } from '../src/identity/phone-auth';
import { VerifiedFirebaseIdentity } from '../src/identity/firebase';
import { AccountLifecycle, DELETION_NOTICE_VERSION } from '../src/account-lifecycle';
import { createApplication } from '../src/http';
import { ApiError } from '../src/errors';

const schema=`firebase_phone_${randomUUID().replaceAll('-','')}`,issuer='native-phone-fixture',secret=randomBytes(32).toString('hex');
let db:Database,admin:Database,phone:PhoneAuthentication,auth:Auth,now=Date.now();
const identities=new Map<string,VerifiedFirebaseIdentity>();
const config:Config={databaseUrl:'',redisUrl:'',port:0,devAccessKey:'synthetic-native-phone-test-key',
  phoneAuth:{provider:'firebase',projectId:issuer,digestKey:secret,consentVersion:'phone-signin-v1',dailyAdmissionLimit:100}};
const presence={async rateLimit(){return true;},async clear(){}} as unknown as Presence;
const phoneDigest=(value:string)=>createHmac('sha256',secret).update(`${issuer}\0phone\0${value}`).digest('hex');
const number=()=>`+919${String(++sequence).padStart(9,'0')}`;let sequence=100;
function token(uid:string,mobile:string,authTime=Math.floor(now/1000),issuedAt=Math.floor(now/1000)){
  const value=randomBytes(24).toString('hex');
  identities.set(value,{uid,issuer:`https://securetoken.google.com/${issuer}`,audience:issuer,authTime,issuedAt,expiresAt:issuedAt+3600,signInProvider:'phone',phoneNumber:mobile});return value;
}
async function admission(mobile:string,deviceId='device-a',key=randomUUID()){
  return phone.admit({phone:mobile,deviceId,consentVersion:'phone-signin-v1'},'127.0.0.1',key);
}
async function session(mobile=number(),uid=`opaque-${randomUUID()}`,deviceId='device-a'){
  const attempt=await admission(mobile,deviceId),idToken=token(uid,mobile);
  const result=await auth.exchange({idToken,deviceId,attemptId:attempt.attemptId},'127.0.0.1');
  return {mobile,uid,idToken,attempt,result};
}
before(async()=>{
  assert.ok(process.env.TEST_DATABASE_URL);const url=new URL(process.env.TEST_DATABASE_URL!);
  admin=new Database(url.toString());await admin.pool.query(`CREATE SCHEMA ${schema}`);url.searchParams.set('options',`-csearch_path=${schema}`);
  db=new Database(url.toString());await migrate(db);
  config.databaseUrl=url.toString();config.redisUrl=process.env.REDIS_URL!;
  phone=new PhoneAuthentication(db,presence,config.phoneAuth,{firebase:{async verifyIdToken(value){
    const identity=identities.get(String(value));assert.ok(identity);return identity;
  }}},()=>now);
  auth=new Auth(db,presence,config,phone,()=>now);
});
after(async()=>{if(db)await db.close();if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}});

test('native phone identity needs admission, maps opaque Firebase UID to a restricted UUID and replays safely',async()=>{
  const mobile=number(),uid='firebase-non-uuid-user',idToken=token(uid,mobile);
  await assert.rejects(auth.exchange({idToken,deviceId:'device-a'},'127.0.0.1'),{code:'PHONE_ADMISSION_REQUIRED'});
  const key=randomUUID(),attempt=await admission(mobile,'device-a',key);
  assert.deepEqual(await admission(mobile,'device-a',key),attempt);
  const first=await auth.exchange({idToken,deviceId:'device-a',attemptId:attempt.attemptId},'127.0.0.1');
  assert.match(first.userId,/^[0-9a-f-]{36}$/);assert.notEqual(first.userId,uid);assert.equal(first.needsOnboarding,true);
  assert.equal((await auth.exchange({idToken,deviceId:'device-a',attemptId:attempt.attemptId},'127.0.0.1')).userId,first.userId);
  await assert.rejects(auth.authenticate(idToken),{code:'ONBOARDING_REQUIRED'});
  assert.equal((await auth.authenticate(idToken,true)).id,first.userId);
  const user=(await db.pool.query('SELECT listener_approved,adult_confirmed FROM users WHERE id=$1',[first.userId])).rows[0];
  assert.deepEqual(user,{listener_approved:false,adult_confirmed:false});
  const rows=JSON.stringify((await db.pool.query('SELECT row_to_json(a) FROM firebase_phone_admissions a')).rows);
  assert.ok(!rows.includes(mobile));assert.ok(!rows.includes(idToken));
});

test('admission requires current consent and exact phone/device/fresh phone authentication',async()=>{
  const mobile=number(),attempt=await admission(mobile),uid=`opaque-${randomUUID()}`;
  await assert.rejects(phone.admit({phone:mobile,deviceId:'device-a',consentVersion:'old'},'127.0.0.1',randomUUID()),{code:'OTP_INVALID_CONSENT'});
  await assert.rejects(auth.exchange({idToken:token(uid,number()),deviceId:'device-a',attemptId:attempt.attemptId},'127.0.0.1'),{code:'PHONE_ADMISSION_MISMATCH'});
  await assert.rejects(auth.exchange({idToken:token(uid,mobile),deviceId:'other-device',attemptId:attempt.attemptId},'127.0.0.1'),{code:'PHONE_ADMISSION_MISMATCH'});
  await assert.rejects(auth.exchange({idToken:token(uid,mobile,Math.floor(now/1000)-301),deviceId:'device-a',attemptId:attempt.attemptId},'127.0.0.1'),{code:'FRESH_SIGN_IN_REQUIRED'});
  const custom=token(uid,mobile);identities.set(custom,{...identities.get(custom)!,signInProvider:'custom'});
  await assert.rejects(auth.exchange({idToken:custom,deviceId:'device-a',attemptId:attempt.attemptId},'127.0.0.1'),{code:'INVALID_ID_TOKEN'});
});

test('read-only session verification cannot enroll and a known UID cannot change its bound phone',async()=>{
  const mobile=number(),uid=`opaque-${randomUUID()}`,idToken=token(uid,mobile);
  await assert.rejects(phone.sessionIdentity(idToken),{code:'INVALID_ID_TOKEN'});
  assert.equal((await db.pool.query('SELECT count(*) FROM firebase_phone_bindings WHERE uid_digest=$1',[createHmac('sha256',secret).update(`${issuer}\0firebase-uid\0${uid}`).digest('hex')])).rows[0].count,'0');
  await session(mobile,uid);
  await assert.rejects(auth.exchange({idToken:token(uid,number()),deviceId:'device-a'},'127.0.0.1'),{code:'PHONE_IDENTITY_CONFLICT'});
});

test('refresh preserves the mapped app identity and logout blocks old auth_time with any device or admission replay',async()=>{
  const signed=await session(),actor=await auth.authenticate(signed.idToken,true);now+=2000;
  const refreshed=token(signed.uid,signed.mobile,identities.get(signed.idToken)!.authTime);
  assert.equal((await auth.exchange({idToken:refreshed,deviceId:'device-a'},'127.0.0.1')).userId,signed.result.userId);
  await auth.logout(actor);now+=2000;
  const stale=token(signed.uid,signed.mobile,identities.get(signed.idToken)!.authTime);
  await assert.rejects(auth.exchange({idToken:stale,deviceId:'another-device'},'127.0.0.1'),{code:'SESSION_REVOKED'});
  await assert.rejects(auth.exchange({idToken:signed.idToken,deviceId:'device-a',attemptId:signed.attempt.attemptId},'127.0.0.1'),{code:'SESSION_REVOKED'});
});

test('legacy phone binding converges to its existing UUID and revoked/suspended tombstones cannot re-enroll',async()=>{
  for(const restricted of [false,true]){
    const mobile=number(),id=randomUUID(),identityId=randomUUID();
    await db.pool.query("INSERT INTO users(id,display_name,adult_confirmed,suspended) VALUES($1,'Fixture',false,$2)",[id,restricted]);
    await db.pool.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:msg91',$3,$4)",[identityId,id,issuer,phoneDigest(mobile)]);
    await db.pool.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1",[identityId]);
    if(restricted)await db.pool.query("UPDATE auth_identities SET state='revoked',revoked_at=now() WHERE id=$1",[identityId]);
    if(restricted)await assert.rejects(session(mobile),{code:'ACCOUNT_RESTRICTED'});
    else assert.equal((await session(mobile)).result.userId,id);
    assert.equal((await db.pool.query("SELECT count(*) FROM auth_identities WHERE issuer=$1 AND subject_digest=$2 AND provider IN ('phone:msg91','phone:firebase')",[issuer,phoneDigest(mobile)])).rows[0].count,'1');
  }
});

test('consumed admission refuses another ID token and deletion removes admissions while retaining hashed identity tombstones',async()=>{
  const signed=await session();now+=1000;
  await assert.rejects(auth.exchange({idToken:token(signed.uid,signed.mobile),deviceId:'device-a',attemptId:signed.attempt.attemptId},'127.0.0.1'),{code:'PHONE_ADMISSION_CONSUMED'});
  const lifecycle=new AccountLifecycle(db,()=>now),actor=await auth.authenticate(signed.idToken,true);
  await lifecycle.requestDeletion(actor,{confirm:true,noticeVersion:DELETION_NOTICE_VERSION,receiptToken:randomBytes(32).toString('hex')});
  assert.equal((await db.pool.query('SELECT count(*) FROM firebase_phone_admissions WHERE user_id=$1 OR phone_digest=$2',[signed.result.userId,phoneDigest(signed.mobile)])).rows[0].count,'0');
  now+=61000;
  await assert.rejects(session(signed.mobile,`new-firebase-${randomUUID()}`),{code:'ACCOUNT_RESTRICTED'});
});

test('one admission cannot bind concurrent differing Firebase UIDs or create duplicate phone accounts',async()=>{
  const mobile=number(),device='concurrent-device',attempt=await admission(mobile,device);
  const results=await Promise.allSettled(['first','second'].map(uid=>auth.exchange({idToken:token(`${uid}-${randomUUID()}`,mobile),deviceId:device,attemptId:attempt.attemptId},'127.0.0.1')));
  assert.equal(results.filter(result=>result.status==='fulfilled').length,1);
  const failed=results.find(result=>result.status==='rejected') as PromiseRejectedResult;
  assert.equal(failed.reason.code,'PHONE_ADMISSION_CONSUMED');
  const identity=(await db.pool.query('SELECT id FROM auth_identities WHERE issuer=$1 AND subject_digest=$2',[issuer,phoneDigest(mobile)])).rows;
  assert.equal(identity.length,1);
  assert.equal((await db.pool.query('SELECT count(*) FROM firebase_phone_bindings WHERE phone_identity_id=$1',[identity[0].id])).rows[0].count,'1');
});

test('expired and superseded admissions reject before identity enrollment',async()=>{
  const mobile=number(),device='expiry-device',first=await admission(mobile,device);
  now+=61000;const next=await admission(mobile,device),uid=`expiry-${randomUUID()}`;
  await assert.rejects(auth.exchange({idToken:token(uid,mobile),deviceId:device,attemptId:first.attemptId},'127.0.0.1'),{code:'PHONE_ADMISSION_EXPIRED'});
  await assert.rejects(auth.exchange({idToken:token(uid,mobile,Math.floor(now/1000)-6),deviceId:device,attemptId:next.attemptId},'127.0.0.1'),{code:'FRESH_SIGN_IN_REQUIRED'});
  now+=300001;
  await assert.rejects(auth.exchange({idToken:token(uid,mobile),deviceId:device,attemptId:next.attemptId},'127.0.0.1'),{code:'PHONE_ADMISSION_EXPIRED'});
  assert.equal((await db.pool.query('SELECT count(*) FROM auth_identities WHERE issuer=$1 AND subject_digest=$2',[issuer,phoneDigest(mobile)])).rows[0].count,'0');
});

test('admission cooldown, phone budget and fingerprint conflicts are durable without SMS calls',async()=>{
  const mobile=number(),device='budget-device',key=randomUUID();await admission(mobile,device,key);
  await assert.rejects(admission(number(),device,key),{code:'IDEMPOTENCY_CONFLICT'});
  await assert.rejects(admission(mobile,device),{code:'OTP_COOLDOWN'});
  now+=61000;await admission(mobile,device);now+=61000;await admission(mobile,device);now+=61000;
  await assert.rejects(admission(mobile,device),{code:'OTP_RATE_LIMITED'});
});

test('digest-key rotation and conflicting legacy Firebase UID cannot silently create another account',async()=>{
  const rotated=new PhoneAuthentication(db,presence,{...config.phoneAuth!,digestKey:randomBytes(32).toString('hex')},{firebase:{async verifyIdToken(value){return identities.get(String(value))!;}}},()=>now);
  await assert.rejects(rotated.admit({phone:number(),deviceId:'rotated',consentVersion:'phone-signin-v1'},'127.0.0.1',randomUUID()),{code:'IDENTITY_CONFIGURATION'});
  const id=randomUUID(),identityId=randomUUID(),legacyMobile=number();
  await db.pool.query("INSERT INTO users(id,display_name,adult_confirmed) VALUES($1,'Fixture',true)",[id]);
  await db.pool.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:msg91',$3,$4)",[identityId,id,issuer,phoneDigest(legacyMobile)]);
  await db.pool.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1",[identityId]);
  await assert.rejects(session(number(),id,'conflicting-uid-device'),{code:'PHONE_IDENTITY_CONFLICT'});
});

test('native HTTP admission and opaque UID exchange preserve restricted onboarding and disable legacy sends',async()=>{
  const previous=process.env.NODE_ENV;process.env.NODE_ENV='test';
  const runtime=await createApplication(config,()=>now,{firebase:{async verifyIdToken(value){
    const identity=identities.get(String(value));if(!identity)throw new ApiError(401,'INVALID_ID_TOKEN','Sign in again.');return identity;
  }}});
  try{
    await runtime.app.listen(0,'127.0.0.1');const base=await runtime.app.getUrl(),mobile=number(),deviceId='http-native-device';
    const request=(route:string,body:unknown,key=randomUUID())=>fetch(`${base}/v1/${route}`,{method:'POST',headers:{'Content-Type':'application/json','Idempotency-Key':key},body:JSON.stringify(body)});
    let response=await request('auth/otp/request',{phone:mobile,deviceId,consentVersion:'phone-signin-v1'});
    assert.equal(response.status,503);assert.equal((await response.json() as any).error.code,'PHONE_AUTH_UNAVAILABLE');
    response=await request('auth/firebase/admissions',{phone:mobile,deviceId,consentVersion:'phone-signin-v1'});
    assert.equal(response.status,201);assert.equal(response.headers.get('Cache-Control'),'no-store');
    const attempt=await response.json() as any;assert.match(attempt.attemptId,/^[0-9a-f-]{36}$/);assert.ok(!JSON.stringify(attempt).includes(mobile));
    const idToken=token('native-http-firebase-uid',mobile);
    response=await request('auth/exchange',{idToken,deviceId,attemptId:attempt.attemptId});
    assert.equal(response.status,201);const signed=await response.json() as any;
    assert.equal(signed.token,idToken);assert.equal(signed.needsOnboarding,true);assert.equal(signed.user.listenerApproved,false);
    assert.match(signed.user.id,/^[0-9a-f-]{36}$/);assert.ok(!JSON.stringify(signed).includes(mobile));
    response=await fetch(`${base}/v1/me/onboarding`,{headers:{Authorization:`Bearer ${idToken}`}});
    assert.equal(response.status,200);assert.equal((await response.json() as any).required,true);
    response=await fetch(`${base}/v1/listeners`,{headers:{Authorization:`Bearer ${idToken}`}});assert.equal(response.status,403);
    response=await request('auth/firebase/verify',{idToken});assert.equal(response.status,201);
    assert.equal((await response.json() as any).userId,signed.user.id);
  }finally{await runtime.close();if(previous===undefined)delete process.env.NODE_ENV;else process.env.NODE_ENV=previous;}
});
