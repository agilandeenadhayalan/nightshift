import 'reflect-metadata';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { PoolClient } from 'pg';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { seed } from '../src/seed';
import { Actor } from '../src/auth';
import { Config } from '../src/config';
import { createApplication } from '../src/http';
import { VerifiedFirebaseIdentity } from '../src/identity/firebase';

const schema=`call_auth_${randomUUID().replaceAll('-','')}`,issuer='call-authorization-fixture';
const identities=new Map<string,VerifiedFirebaseIdentity>(),ids=new Set<string>();
type Participant=Actor&{token:string};
let admin:Database,runtime:Awaited<ReturnType<typeof createApplication>>,base:string;
let now=Date.now();
const defer=()=>{let release!:()=>void;const wait=new Promise<void>(resolve=>{release=resolve;});return {wait,release};};
before(async()=>{
  assert.equal(process.env.NODE_ENV,'test');assert.ok(process.env.TEST_DATABASE_URL);assert.ok(process.env.REDIS_URL);
  const url=new URL(process.env.TEST_DATABASE_URL!);assert.match(decodeURIComponent(url.pathname.slice(1)),/^[a-z0-9_]+_test$/);
  admin=new Database(url.toString());await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options',`-csearch_path=${schema}`);
  const db=new Database(url.toString());await migrate(db);await seed(db);await db.close();
  const config:Config={databaseUrl:url.toString(),redisUrl:process.env.REDIS_URL!,port:0,
    devAccessKey:'isolated-call-authorization-fixture-key',agoraAppId:'a'.repeat(32),agoraAppCertificate:'b'.repeat(32),
    phoneAuth:{projectId:issuer,digestKey:randomBytes(32).toString('hex'),consentVersion:'phone-signin-v1'}};
  runtime=await createApplication(config,()=>now,{firebase:{async verifyIdToken(token){
    const proof=identities.get(String(token));assert.ok(proof);return proof;
  }}});
  await runtime.app.listen(0,'127.0.0.1');base=await runtime.app.getUrl();
});
after(async()=>{
  if(runtime){for(const id of ids)await runtime.presence.clear(id);await runtime.close();}
  if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}
});

async function exchange(id:string,authTime=Math.floor(now/1000)):Promise<Participant>{
  const token=randomBytes(32).toString('hex'),issuedAt=Math.floor(now/1000);
  identities.set(token,{uid:id,issuer:`https://securetoken.google.com/${issuer}`,audience:issuer,authTime,issuedAt,expiresAt:issuedAt+3600});
  await runtime.auth.exchange({idToken:token,deviceId:'same-fixture-phone'},`${schema}:${randomUUID()}`);
  return {...await runtime.auth.authenticate(token),token};
}
async function participant(listener=false){
  const id=randomUUID();ids.add(id);
  await runtime.db.tx(async c=>{
    await c.query('INSERT INTO users(id,display_name,listener_approved,mode) VALUES($1,$2,$3,$4)',[id,'Synthetic call fixture',listener,listener?'listener':'customer']);
    const binding=randomUUID();
    await c.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:msg91',$3,$4)",[binding,id,issuer,randomBytes(32).toString('hex')]);
    await c.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1",[binding]);
    await c.query("INSERT INTO wallet_accounts(id,user_id,unit,kind) VALUES($1,$2,'TEST_MICROCREDIT','customer_test'),($3,$2,'TEST_PAISE','listener_test')",[`customer:${id}`,id,`listener:${id}`]);
    await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'fictional_test_grant')",[`fixture:${id}`]);
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,10000000000),($1,'platform:test',-10000000000)",[`fixture:${id}`,`customer:${id}`]);
  });return exchange(id);
}
async function fixture(accepted=false){
  const customer=await participant(),listener=await participant(true),key=randomUUID();
  await runtime.service.availability(listener,{online:true});
  const body={listenerId:listener.id,quoteId:'test-audio-v1'};
  let call=await runtime.service.createCall(customer,body,key);
  if(accepted)call=await runtime.service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID());
  return {customer,listener,call,key,body};
}
async function refresh(actor:Participant){now+=1000;return exchange(actor.id,actor.identityAuthTime);}

test('same-device refresh invalidates an already admitted accept actor',async()=>{
  const {customer,listener,call}=await fixture();const fresh=await refresh(listener);
  await assert.rejects(runtime.service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID()),{code:'UNAUTHENTICATED'});
  assert.equal((await runtime.service.call(customer.id,call.id)).state,'ringing');
  assert.equal((await runtime.service.action(fresh,call.id,'accept',{expectedVersion:call.version},randomUUID())).state,'connecting');
});

test('same-device refresh invalidates an admitted media heartbeat without changing readiness or metering',async()=>{
  const {customer,call}=await fixture(true);const fresh=await refresh(customer);
  const before=(await runtime.db.pool.query('SELECT customer_ready,customer_media_at,connected_ms FROM call_sessions WHERE id=$1',[call.id])).rows[0];
  await assert.rejects(runtime.service.media(customer,call.id,{ready:true}),{code:'UNAUTHENTICATED'});
  assert.deepEqual((await runtime.db.pool.query('SELECT customer_ready,customer_media_at,connected_ms FROM call_sessions WHERE id=$1',[call.id])).rows[0],before);
  await runtime.service.media(fresh,call.id,{ready:true});
});

test('same-device refresh prevents an admitted old actor minting another RTC token',async()=>{
  const {customer,call}=await fixture(true);const fresh=await refresh(customer);
  await assert.rejects(runtime.service.rtcToken(customer,call.id),{code:'UNAUTHENTICATED'});
  assert.equal((await runtime.service.rtcToken(fresh,call.id)).uid,1);
});

test('create-call idempotency cache rechecks the actor while preserving current-session retry',async()=>{
  const {customer,call,key,body}=await fixture();const fresh=await refresh(customer);
  await assert.rejects(runtime.service.createCall(customer,body,key),{code:'UNAUTHENTICATED'});
  assert.deepEqual(await runtime.service.createCall(fresh,body,key),call);
});

test('accepted-call idempotency cache does not grant a revoked actor access',async()=>{
  const {listener,call}=await fixture(),key=randomUUID(),body={expectedVersion:call.version};
  const result=await runtime.service.action(listener,call.id,'accept',body,key),fresh=await refresh(listener);
  await assert.rejects(runtime.service.action(listener,call.id,'accept',body,key),{code:'UNAUTHENTICATED'});
  assert.deepEqual(await runtime.service.action(fresh,call.id,'accept',body,key),result);
});

test('report creation and cached report results require a current actor',async()=>{
  const {customer,call}=await fixture(),key=randomUUID(),body={callId:call.id,reason:'Synthetic authorization regression'};
  const result=await runtime.service.report(customer,body,key),fresh=await refresh(customer);
  await assert.rejects(runtime.service.report(customer,body,key),{code:'UNAUTHENTICATED'});
  await assert.rejects(runtime.service.report(customer,body,randomUUID()),{code:'UNAUTHENTICATED'});
  assert.deepEqual(await runtime.service.report(fresh,body,key),result);
  assert.equal((await runtime.db.pool.query('SELECT count(*) FROM reports WHERE call_id=$1',[call.id])).rows[0].count,'1');
});

test('expired sessions and actors lacking a session hash cannot mutate or mint',async()=>{
  const {customer,call}=await fixture(true);
  await runtime.db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[customer.sessionHash,new Date(now-1)]);
  for(const actor of [customer,{id:customer.id} as Actor]){
    for(const run of [()=>runtime.service.media(actor,call.id,{ready:true}),()=>runtime.service.rtcToken(actor,call.id),
      ()=>runtime.service.action(actor,call.id,'end',{expectedVersion:call.version},randomUUID()),
      ()=>runtime.service.report(actor,{callId:call.id,reason:'Synthetic'},randomUUID())])await assert.rejects(run(),{code:'UNAUTHENTICATED'});
  }
});

test('current participants can end and cancel after the peer becomes ineligible',async()=>{
  for(const accepted of [false,true]){
    const {customer,listener,call}=await fixture(accepted);
    await runtime.db.pool.query('UPDATE users SET listener_approved=false,adult_confirmed=false,suspended=true WHERE id=$1',[listener.id]);
    const result=await runtime.service.action(customer,call.id,accepted?'end':'cancel',{expectedVersion:call.version},randomUUID());
    assert.equal(result.state,'ended');assert.equal(result.chargeMicrocredits,0);
    assert.equal((await runtime.db.pool.query('SELECT count(*) FROM active_participant_claims WHERE call_id=$1',[call.id])).rows[0].count,'0');
  }
});

test('opposite participant logout and end retain user-before-call ordering and settle once',async()=>{
  const {customer,listener,call}=await fixture(true);
  const outcomes=await Promise.allSettled([
    runtime.service.action(customer,call.id,'end',{expectedVersion:call.version},randomUUID()),
    runtime.auth.logout(listener,c=>runtime.service.logoutCall(listener,c))]);
  assert.ok(outcomes.every(r=>r.status==='fulfilled'));
  assert.equal((await runtime.service.call(customer.id,call.id)).state,'ended');
  assert.equal((await runtime.db.pool.query('SELECT count(*) FROM active_participant_claims WHERE call_id=$1',[call.id])).rows[0].count,'0');
  assert.equal((await runtime.db.pool.query("SELECT count(*) FROM call_events WHERE call_id=$1 AND payload->>'state'='ended'",[call.id])).rows[0].count,'1');
});

test('logout invalidates cached create, accept and report results without further durable writes',async()=>{
  const {customer,listener,call,key,body}=await fixture(),acceptKey=randomUUID(),acceptBody={expectedVersion:call.version};
  await runtime.service.action(listener,call.id,'accept',acceptBody,acceptKey);
  const reportKey=randomUUID(),reportBody={callId:call.id,reason:'Synthetic logout regression'};
  await runtime.service.report(customer,reportBody,reportKey);
  await runtime.auth.logout(customer,c=>runtime.service.logoutCall(customer,c));
  await runtime.auth.logout(listener,c=>runtime.service.logoutCall(listener,c));
  const counts=async()=> (await runtime.db.pool.query(`SELECT
    (SELECT count(*) FROM call_events WHERE call_id=$1) AS events,
    (SELECT count(*) FROM outbox_events WHERE event_id IN (SELECT id FROM call_events WHERE call_id=$1)) AS outbox,
    (SELECT count(*) FROM journal_batches WHERE call_id=$1) AS journal,
    (SELECT count(*) FROM idempotency_keys WHERE actor_id=ANY($2::uuid[])) AS retries,
    (SELECT count(*) FROM reports WHERE call_id=$1) AS reports`,[call.id,[customer.id,listener.id]])).rows[0];
  const before=await counts();
  await assert.rejects(runtime.service.createCall(customer,body,key),{code:'UNAUTHENTICATED'});
  await assert.rejects(runtime.service.action(listener,call.id,'accept',acceptBody,acceptKey),{code:'UNAUTHENTICATED'});
  await assert.rejects(runtime.service.report(customer,reportBody,reportKey),{code:'UNAUTHENTICATED'});
  assert.deepEqual(await counts(),before);
});

for(const operation of ['accept','media','rtc-token'] as const){
  test(`${operation} rejects a currently ineligible pair before readiness, acceptance or token issuance`,async()=>{
    for(const restriction of ['adult','suspended','approval','blocked','released-hold'] as const){
      const {customer,listener,call}=await fixture(operation!=='accept');
      // Keep the initiating actor eligible so this exercises the pair check,
      // independently of the initiating session's existing adult restriction.
      const other=operation==='accept'?customer:listener;
      if(restriction==='adult')await runtime.db.pool.query('UPDATE users SET adult_confirmed=false WHERE id=$1',[other.id]);
      if(restriction==='suspended')await runtime.db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[other.id]);
      if(restriction==='approval')await runtime.db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[listener.id]);
      if(restriction==='blocked')await runtime.db.pool.query('INSERT INTO blocks(actor_id,target_id) VALUES($1,$2)',[listener.id,customer.id]);
      if(restriction==='released-hold')await runtime.db.pool.query('UPDATE spend_holds SET released_at=now() WHERE call_id=$1',[call.id]);
      const before=await runtime.service.call(customer.id,call.id);
      const run=operation==='accept'?()=>runtime.service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID())
        :operation==='media'?()=>runtime.service.media(customer,call.id,{ready:true})
        :()=>runtime.service.rtcToken(customer,call.id);
      await assert.rejects(run(),{code:restriction==='blocked'||restriction==='released-hold'?'CALL_NOT_AUTHORIZED':'CALL_NOT_ELIGIBLE'});
      assert.deepEqual(await runtime.service.call(customer.id,call.id),before);
    }
  });
}

test('existing calls can accept and continue media after availability is withdrawn',async()=>{
  const {customer,listener,call}=await fixture();
  await runtime.service.availability(listener,{online:false});
  assert.equal((await runtime.service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID())).state,'connecting');
  await runtime.service.media(customer,call.id,{ready:true});
  assert.equal((await runtime.service.media(listener,call.id,{ready:true})).state,'connected');
  assert.equal((await runtime.service.rtcToken(customer,call.id)).uid,1);
});

test('opposite-party block serializes with concurrent media and token requests without a call/user lock inversion',async t=>{
  const {customer,listener,call}=await fixture(true),locked=defer(),release=defer(),lookedUp=defer();
  const original=runtime.db.tx.bind(runtime.db);let transaction=0,lookups=0;
  const mock=t.mock.method(runtime.db,'tx',async<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>=>{
    const operation=transaction++;let observed=false;
    return original(async client=>fn(new Proxy(client,{get(target,key){
      if(key!=='query')return Reflect.get(target,key);
      return async(...args:any[])=>{
        const result=await (target.query as (...values:any[])=>Promise<any>).apply(target,args);
        const sql=String(args[0]);
        // The real block transaction holds both user rows, but has not locked
        // the call. Let both incoming operations look up the call first. If
        // they locked the call before waiting for users, this would deadlock.
        if(operation===0&&sql.startsWith('SELECT id FROM users')&&sql.includes('FOR NO KEY UPDATE')){
          locked.release();await release.wait;
        }
        if((operation===1||operation===2)&&!observed&&sql.startsWith('SELECT * FROM call_sessions')){
          observed=true;if(++lookups===2)lookedUp.release();
        }
        return result;
      };
    }})));
  });
  const blocking=runtime.service.block(listener,customer.id);await locked.wait;
  const media=runtime.service.media(customer,call.id,{ready:true});
  const token=runtime.service.rtcToken(customer,call.id);
  const tokenDenied=assert.rejects(token,{code:'CALL_NOT_ACTIVE'});
  let timeout:ReturnType<typeof setTimeout>|undefined;
  try{
    await Promise.race([lookedUp.wait,new Promise<never>((_,reject)=>{timeout=setTimeout(()=>reject(new Error('Call lookup acquired an incompatible lock before user authorization')),5000);})]);
    release.release();await blocking;
    assert.equal((await media).state,'ended');await tokenDenied;
    assert.equal((await runtime.db.pool.query('SELECT count(*) FROM active_participant_claims WHERE call_id=$1',[call.id])).rows[0].count,'0');
    assert.equal((await runtime.db.pool.query("SELECT count(*) FROM call_events WHERE call_id=$1 AND payload->>'state'='ended'",[call.id])).rows[0].count,'1');
    assert.equal((await runtime.db.pool.query('SELECT customer_ready,listener_ready FROM call_sessions WHERE id=$1',[call.id])).rows[0].customer_ready,false);
  }finally{
    if(timeout)clearTimeout(timeout);release.release();await Promise.allSettled([blocking,media,tokenDenied]);mock.mock.restore();
  }
});

for(const operation of ['media','rtc-token','accept','cached-create'] as const){
  test(`HTTP ${operation} admitted before a same-device refresh is denied after refresh commits`,async t=>{
    const {customer,listener,call,key,body}=await fixture(operation==='media'||operation==='rtc-token');
    const actor=operation==='accept'?listener:customer,entered=defer(),release=defer();
    const original=runtime.auth.authenticate.bind(runtime.auth);let gated=false;
    const mock=t.mock.method(runtime.auth,'authenticate',async(token:string|undefined,allowOnboarding=false)=>{
      const result=await original(token,allowOnboarding);
      if(token===actor.token&&!gated){gated=true;entered.release();await release.wait;}return result;
    });
    const endpoint=operation==='cached-create'?'calls':`calls/${call.id}/${operation}`;
    const requestBody=operation==='media'?{ready:true}:operation==='accept'?{expectedVersion:call.version}:operation==='cached-create'?body:{};
    const pending=fetch(`${base}/v1/${endpoint}`,{method:'POST',headers:{Authorization:`Bearer ${actor.token}`,'Content-Type':'application/json','Idempotency-Key':operation==='cached-create'?key:randomUUID()},body:JSON.stringify(requestBody)});
    await entered.wait;
    try{await refresh(actor);release.release();const response=await pending;
      assert.equal(response.status,401);const result=await response.json() as {error:{code:string}};assert.equal(result.error.code,'UNAUTHENTICATED');
    }finally{release.release();await pending;mock.mock.restore();}
  });
}
