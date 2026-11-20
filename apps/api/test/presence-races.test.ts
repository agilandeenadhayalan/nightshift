import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:net';
import { createClient } from 'redis';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { seed } from '../src/seed';
import { Actor, Auth } from '../src/auth';
import { Config } from '../src/config';
import { Presence } from '../src/presence';
import { NightShiftService } from '../src/service';
import { PhoneAuthentication } from '../src/identity/phone-auth';
import { VerifiedFirebaseIdentity } from '../src/identity/firebase';
import { AccountLifecycle, DELETION_NOTICE_VERSION } from '../src/account-lifecycle';

const schema=`presence_${randomUUID().replaceAll('-','')}`,issuer='presence-race-fixture';
const ids=new Set<string>(),identities=new Map<string,VerifiedFirebaseIdentity>();
let admin:Database,db:Database,presence:Presence,service:NightShiftService,auth:Auth,config:Config;
let redis:ReturnType<typeof createClient>,now=Date.now();
const defer=()=>{let release!:()=>void;const wait=new Promise<void>(resolve=>{release=resolve;});return {wait,release};};
const version=async(id:string)=>String((await db.pool.query('SELECT presence_version FROM users WHERE id=$1',[id])).rows[0].presence_version);
const requestIp=()=>`${schema}:${randomUUID()}`;

before(async()=>{
  assert.ok(process.env.TEST_DATABASE_URL,'Use an explicit dedicated test database');
  assert.ok(process.env.REDIS_URL,'Use the configured Redis endpoint');
  const url=new URL(process.env.TEST_DATABASE_URL!);
  assert.match(decodeURIComponent(url.pathname.slice(1)),/^[a-z0-9_]+_test$/);
  admin=new Database(url.toString());await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options',`-csearch_path=${schema}`);db=new Database(url.toString());await migrate(db);await seed(db);
  config={databaseUrl:url.toString(),redisUrl:process.env.REDIS_URL!,port:0,devAccessKey:'presence-race-key-for-isolated-fixtures',
    phoneAuth:{projectId:issuer,digestKey:randomBytes(32).toString('hex'),consentVersion:'phone-signin-v1'}};
  presence=new Presence(config.redisUrl);await presence.connect();
  redis=createClient({url:config.redisUrl});redis.on('error',()=>{});await redis.connect();
  const phone=new PhoneAuthentication(db,presence,config.phoneAuth,{firebase:{async verifyIdToken(token){
    const identity=identities.get(String(token));assert.ok(identity);return identity;
  }}},()=>now);
  auth=new Auth(db,presence,config,phone,()=>now);service=new NightShiftService(db,presence,config,()=>now);
});
beforeEach(()=>{now=Date.now();});
after(async()=>{
  // Only UUID keys created in this isolated schema are removed; never flush Redis.
  if(redis?.isReady){for(const id of ids)await redis.del(`presence:${id}`);await redis.quit();}
  if(presence)await presence.close();if(db)await db.close();
  if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}
});

async function account(listener=true){
  const id=randomUUID();ids.add(id);
  await db.tx(async c=>{
    await c.query('INSERT INTO users(id,test_handle,display_name,listener_approved,mode) VALUES($1::uuid,$1::uuid::text,$2,$3,$4)',
      [id,'Synthetic presence fixture',listener,listener?'listener':'customer']);
    await c.query("INSERT INTO wallet_accounts(id,user_id,unit,kind) VALUES($1,$2,'TEST_MICROCREDIT','customer_test'),($3,$2,'TEST_PAISE','listener_test')",
      [`customer:${id}`,id,`listener:${id}`]);
    await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'fictional_test_grant')",[`seed:${id}`]);
    await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,10000000000),($1,\'platform:test\',-10000000000)',[`seed:${id}`,`customer:${id}`]);
  });return id;
}
async function login(id:string,deviceId=randomUUID()){
  const signed=await auth.login({handle:id,accessKey:config.devAccessKey,deviceId},requestIp());
  return auth.authenticate(signed.token);
}
async function participant(listener=true){const id=await account(listener);return login(id);}
async function invite(customer:Actor,listener:Actor){
  await service.availability(listener,{online:true});
  return service.createCall(customer,{listenerId:listener.id,quoteId:'test-audio-v1'},randomUUID());
}
async function phoneActor(id:string,device:string,authTime=Math.floor(now/1000)){
  const token=randomBytes(32).toString('hex'),issuedAt=Math.floor(now/1000);
  identities.set(token,{uid:id,issuer:`https://securetoken.google.com/${issuer}`,audience:issuer,authTime,issuedAt,expiresAt:issuedAt+3600});
  await auth.exchange({idToken:token,deviceId:device},requestIp());return auth.authenticate(token);
}
async function phoneAccount(){
  const id=await account(),binding=randomUUID();
  await db.pool.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:msg91',$3,$4)",[binding,id,issuer,randomBytes(32).toString('hex')]);
  await db.pool.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1",[binding]);
  return phoneActor(id,'phone-a');
}

test('actors admitted before logout cannot restore availability, heartbeat or mode',async()=>{
  const actor=await participant();await service.availability(actor,{online:true});await auth.logout(actor);
  for(const mutation of [()=>service.availability(actor,{online:true}),()=>service.heartbeat(actor),()=>service.mode(actor,{mode:'customer'})]){
    await assert.rejects(mutation(),{code:'UNAUTHENTICATED'});
  }
  assert.equal((await service.user(actor.id)).online,false);
  assert.equal((await db.pool.query('SELECT desired_online FROM users WHERE id=$1',[actor.id])).rows[0].desired_online,false);
});

test('late heartbeat cannot overwrite a newer device lease or authorize itself after cache loss',async t=>{
  const actor=await participant();await service.availability(actor,{online:true});
  const entered=defer(),release=defer(),original=presence.heartbeat.bind(presence);let delayed=true;
  const mock=t.mock.method(presence,'heartbeat',async(id:string,v:string)=>{
    if(id===actor.id && delayed){delayed=false;entered.release();await release.wait;}
    return original(id,v);
  });
  const pending=service.heartbeat(actor);await entered.wait;
  let oldVersion=await version(actor.id);
  try{
    const replacement=await login(actor.id);await service.availability(replacement,{online:true});
    const current=await version(actor.id);release.release();await pending;
    assert.equal(await presence.isOnline(actor.id,current),true);
    assert.equal(await presence.isOnline(actor.id,oldVersion),false);
    // Simulated loss is scoped to this account, never a shared Redis restart/flush.
    await redis.del(`presence:${actor.id}`);await original(actor.id,oldVersion);
    assert.equal(await presence.isOnline(actor.id),true,'stale bytes exist, so DB fencing is exercised');
    assert.equal((await service.user(actor.id)).online,false);
    const customer=await participant(false);
    assert.ok(!(await service.listeners(customer.id)).items.some(row=>row.id===actor.id&&row.available));
    await assert.rejects(service.createCall(customer,{listenerId:actor.id,quoteId:'test-audio-v1'},randomUUID()),{code:'LISTENER_OFFLINE'});
    await service.heartbeat(replacement);assert.equal((await service.user(actor.id)).online,true);
  }finally{release.release();await pending;mock.mock.restore();}
});

test('delayed logout clear cannot remove a newer device availability intent',async t=>{
  const actor=await participant();await service.availability(actor,{online:true});
  const entered=defer(),release=defer(),original=presence.clear.bind(presence);let delayed=true;
  const mock=t.mock.method(presence,'clear',async(id:string,v?:string)=>{
    if(id===actor.id && delayed){delayed=false;entered.release();await release.wait;}
    return original(id,v);
  });
  const pending=auth.logout(actor);await entered.wait;
  try{
    const next=await login(actor.id);await service.availability(next,{online:true});
    release.release();await pending;assert.equal((await service.user(actor.id)).online,true);
  }finally{release.release();await pending;mock.mock.restore();}
});

test('delayed offline clear cannot erase a later online intent on the same session',async t=>{
  const actor=await participant();await service.availability(actor,{online:true});
  const entered=defer(),release=defer(),original=presence.clear.bind(presence);let delayed=true;
  const mock=t.mock.method(presence,'clear',async(id:string,v?:string)=>{
    if(id===actor.id && delayed){delayed=false;entered.release();await release.wait;}
    return original(id,v);
  });
  const pending=service.availability(actor,{online:false});await entered.wait;
  try{await service.availability(actor,{online:true});release.release();await pending;assert.equal((await service.user(actor.id)).online,true);}
  finally{release.release();await pending;mock.mock.restore();}
});

test('same-device refresh preserves liveness while stale fresh-lineage logout is rejected',async()=>{
  const first=await phoneAccount();await service.availability(first,{online:true});const before=await version(first.id);
  now+=2000;const refreshed=await phoneActor(first.id,'phone-a',first.identityAuthTime);
  assert.equal(await version(first.id),before);assert.equal((await service.user(first.id)).online,true);
  await assert.rejects(service.heartbeat(first),{code:'UNAUTHENTICATED'});
  await service.heartbeat(refreshed);
  await auth.logout(first);assert.equal((await service.user(first.id)).online,false,'admitted same-lineage logout remains effective');
  now+=2000;const newer=await phoneActor(first.id,'phone-b');await service.availability(newer,{online:true});
  let callback=false;
  await assert.rejects(auth.logout(first,async()=>{callback=true;}),{code:'UNAUTHENTICATED'});
  assert.equal(callback,false);assert.equal((await service.user(first.id)).online,true);
});

test('expired session does not authorize a surviving Redis lease',async()=>{
  const actor=await participant();await service.availability(actor,{online:true});
  await db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[actor.sessionHash,new Date(now+1000)]);now+=1001;
  assert.equal(await presence.isOnline(actor.id),true);
  await assert.rejects(service.heartbeat(actor),{code:'UNAUTHENTICATED'});
  assert.equal((await service.user(actor.id)).online,false);
});

test('eligibility changes advance a monotonic version and cannot revive an earlier lease',async()=>{
  const actor=await participant();await service.availability(actor,{online:true});const prior=await version(actor.id);
  await db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[actor.id]);
  await db.pool.query('UPDATE users SET listener_approved=true WHERE id=$1',[actor.id]);
  assert.ok(BigInt(await version(actor.id))>BigInt(prior));
  assert.equal((await service.user(actor.id)).online,false);
  await assert.rejects(db.pool.query('UPDATE users SET presence_version=$2 WHERE id=$1',[actor.id,prior]),{code:'23514'});
  await service.heartbeat(actor);assert.equal((await service.user(actor.id)).online,true);
});

test('a call creation admitted before logout cannot create a new reservation afterward',async()=>{
  const customer=await participant(false),listener=await participant();await service.availability(listener,{online:true});
  await auth.logout(customer,c=>service.logoutCall(customer,c));
  await assert.rejects(service.createCall(customer,{listenerId:listener.id,quoteId:'test-audio-v1'},randomUUID()),{code:'UNAUTHENTICATED'});
  assert.equal((await db.pool.query('SELECT count(*) FROM active_participant_claims WHERE user_id=ANY($1::uuid[])',[[customer.id,listener.id]])).rows[0].count,'0');
});

test('rolled-back intent never publishes and Redis failure leaves only recoverable offline intent',async t=>{
  const actor=await participant(),before=await version(actor.id);
  const failedDb={pool:db.pool,close:async()=>{},tx:async(fn:(c:any)=>Promise<unknown>)=>db.tx(async c=>{await fn(c);throw new Error('Synthetic rollback');})} as Database;
  const failedService=new NightShiftService(failedDb,presence,config,()=>now);
  const original=presence.heartbeat.bind(presence);let writes=0;
  const mock=t.mock.method(presence,'heartbeat',async(id:string,v:string)=>{writes++;return original(id,v);});
  await assert.rejects(failedService.availability(actor,{online:true}),/Synthetic rollback/);
  assert.equal(writes,0);assert.equal(await version(actor.id),before);mock.mock.restore();
  const broken=t.mock.method(presence,'heartbeat',async()=>{throw new Error('Synthetic Redis write failure');});
  await assert.rejects(service.availability(actor,{online:true}),/Synthetic Redis write failure/);broken.mock.restore();
  assert.equal((await service.user(actor.id)).online,false);
  await service.heartbeat(actor);assert.equal((await service.user(actor.id)).online,true);
});

test('cache loss and reconnect never release a database-owned busy participant',async()=>{
  const customer=await participant(false),listener=await participant(),call=await invite(customer,listener);
  await redis.del(`presence:${listener.id}`);await service.heartbeat(listener);
  const card=(await service.listeners(customer.id)).items.find(row=>row.id===listener.id);
  assert.equal(card?.busy,true);assert.equal(card?.available,false);
  const other=await participant(false);
  await assert.rejects(service.createCall(other,{listenerId:listener.id,quoteId:'test-audio-v1'},randomUUID()),{code:'LISTENER_BUSY'});
  assert.equal((await db.pool.query('SELECT call_id FROM active_participant_claims WHERE user_id=$1',[listener.id])).rows[0].call_id,call.id);
  await service.action(customer,call.id,'cancel',{expectedVersion:call.version},randomUUID());
});

test('simultaneous participant logout settles an active call exactly once without lock inversion',async()=>{
  const customer=await participant(false),listener=await participant(),call=await invite(customer,listener);
  await service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID());
  await service.media(customer,call.id,{ready:true});await service.media(listener,call.id,{ready:true});
  for(let i=0;i<42;i++){now+=1000;await service.media(customer,call.id,{ready:true});await service.media(listener,call.id,{ready:true});}
  await Promise.all([customer,listener].map(actor=>auth.logout(actor,c=>service.logoutCall(actor,c))));
  const ended=await service.call(customer.id,call.id);assert.equal(ended.state,'ended');assert.ok(ended.chargeMicrocredits>0);
  assert.equal((await db.pool.query('SELECT count(*) FROM active_participant_claims WHERE call_id=$1',[call.id])).rows[0].count,'0');
  assert.equal((await db.pool.query("SELECT count(*) FROM journal_batches WHERE call_id=$1 AND kind='test_call_settlement'",[call.id])).rows[0].count,'1');
});

test('accept racing logout cannot leave a surviving reservation or duplicate terminal event',async()=>{
  const customer=await participant(false),listener=await participant(),call=await invite(customer,listener);
  const results=await Promise.allSettled([
    service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID()),
    auth.logout(listener,c=>service.logoutCall(listener,c)),
  ]);
  assert.equal(results[1]!.status,'fulfilled');
  if(results[0]!.status==='rejected')assert.equal(results[0]!.reason.code,'CALL_ALREADY_ENDED');
  assert.equal((await service.call(customer.id,call.id)).state,'ended');
  assert.equal((await db.pool.query("SELECT count(*) FROM call_events WHERE call_id=$1 AND payload->>'state'='ended'",[call.id])).rows[0].count,'1');
  assert.equal((await db.pool.query('SELECT count(*) FROM active_participant_claims WHERE call_id=$1',[call.id])).rows[0].count,'0');
});

test('deletion fences a heartbeat that was admitted before suspension',async t=>{
  const actor=await phoneAccount();await service.availability(actor,{online:true});
  const entered=defer(),release=defer(),original=presence.heartbeat.bind(presence);let delayed=true;
  const mock=t.mock.method(presence,'heartbeat',async(id:string,v:string)=>{
    if(id===actor.id && delayed){delayed=false;entered.release();await release.wait;}return original(id,v);
  });
  const pending=service.heartbeat(actor);await entered.wait;
  try{
    const lifecycle=new AccountLifecycle(db,()=>now,id=>service.withdrawPresence(id));
    await lifecycle.requestDeletion(actor,{noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
    release.release();await pending;assert.equal((await service.user(actor.id)).online,false);
    await assert.rejects(service.heartbeat(actor),{code:'UNAUTHENTICATED'});
  }finally{release.release();await pending;mock.mock.restore();}
});

test('presence bigint fencing is exact and initial Redis connection is bounded',async()=>{
  const id=randomUUID();ids.add(id);
  await presence.heartbeat(id,'9007199254740993');assert.equal(await presence.heartbeat(id,'9007199254740992'),false);
  await presence.clear(id,'9007199254740992');assert.equal(await presence.isOnline(id,'9007199254740993'),true);
  const server=createServer();await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
  const address=server.address();assert.ok(address && typeof address!=='string');
  await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));
  const unavailable=new Presence(`redis://127.0.0.1:${address.port}`),start=Date.now();
  await assert.rejects(unavailable.connect(40),/Presence is unavailable/);
  assert.ok(Date.now()-start<1500);await unavailable.close();
});

test('real Redis lease expires after the configured 45 seconds without another heartbeat',{timeout:55000},async()=>{
  const id=randomUUID();ids.add(id);const start=Date.now();await presence.heartbeat(id,'1');
  const ttl=await redis.pTTL(`presence:${id}`);assert.ok(ttl>44000 && ttl<=45000);
  await new Promise(resolve=>setTimeout(resolve,45100));
  assert.equal(await presence.isOnline(id,'1'),false);
  assert.ok(Date.now()-start>=45000);
});
