import 'reflect-metadata';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { seed } from '../src/seed';
import { Config, loadConfig } from '../src/config';
import { NightShiftService } from '../src/service';
import { createApplication } from '../src/http';
import { Actor } from '../src/auth';
import { MICRO } from '../src/billing';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import { io } from 'socket.io-client';

let runtime:Awaited<ReturnType<typeof createApplication>>,admin:Database;
let customer:Actor,customer2:Actor,listener:Actor;
let customerToken:string,listenerToken:string;
let now=Date.now(),base:string,config:Config;
const schema=`test_${randomUUID().replaceAll('-','')}`;
const idem=()=>randomUUID();
before(async()=>{
  const env:NodeJS.ProcessEnv={...process.env,NODE_ENV:'test'};
  const url=new URL(env.TEST_DATABASE_URL??env.DATABASE_URL??'postgres://invalid');
  // Every run is isolated in a new schema; never clear or overwrite existing account records.
  admin=new Database(url.toString());
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options',`-csearch_path=${schema}`);
  config=loadConfig({...env,DATABASE_URL:url.toString()});
  const db=new Database(config.databaseUrl);await migrate(db);await migrate(db);await seed(db);await seed(db);await db.close();
  runtime=await createApplication(config,()=>now);await runtime.app.listen(0,'127.0.0.1');
  base=await runtime.app.getUrl();
  const a=await runtime.auth.login({handle:'customer',accessKey:config.devAccessKey,deviceId:'test-a'},schema);
  const b=await runtime.auth.login({handle:'listener',accessKey:config.devAccessKey,deviceId:'test-b'},schema);
  const c=await runtime.auth.login({handle:'customer2',accessKey:config.devAccessKey,deviceId:'test-c'},schema);
  customer=await runtime.auth.authenticate(a.token);listener=await runtime.auth.authenticate(b.token);customer2=await runtime.auth.authenticate(c.token);
  customerToken=a.token;listenerToken=b.token;
});
after(async()=>{
  if(runtime)await runtime.close();
  if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}
});
async function online(){await runtime.service.availability(listener,{online:true});}
async function invite(actor=customer){await online();return runtime.service.createCall(actor,{listenerId:listener.id,quoteId:'test-audio-v1'},idem());}
async function accept(call:{id:string;version:number}){return runtime.service.action(listener,call.id,'accept',{expectedVersion:call.version},idem());}
async function end(actor:Actor,call:{id:string}){
  const current=await runtime.service.call(actor.id,call.id);return runtime.service.action(actor,call.id,'end',{expectedVersion:current.version},idem());
}
async function bothReady(id:string){await runtime.service.media(customer,id,{ready:true});await runtime.service.media(listener,id,{ready:true});}
async function healthy(id:string,seconds:number){for(let i=0;i<seconds;i++){now+=1000;await bothReady(id);}}
async function request(path:string,method='GET',token?:string,body?:unknown){
  const response=await fetch(`${base}/v1/${path}`,{method,headers:{...(token?{Authorization:`Bearer ${token}`}:{}) ,...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});
  return {status:response.status,body:await response.json() as any};
}
test('health and HTTP guards reject missing credentials and client-forged roles',async()=>{
  assert.equal((await request('health')).status,200);
  assert.equal((await request('snapshot')).status,401);
  assert.equal((await request('snapshot','GET','invalid')).status,401);
  const forged=await request('me/mode','PUT',customerToken,{mode:'listener',listenerApproved:true});
  assert.equal(forged.status,400);assert.equal(forged.body.error.code,'INVALID_FIELD');
  const forbidden=await request('me/mode','PUT',customerToken,{mode:'listener'});
  assert.equal(forbidden.status,403);
  assert.equal((await request('listeners?language=xx','GET',customerToken)).status,400);
});
test('seed grants do not duplicate and directory expires Redis presence',async()=>{
  assert.equal((await runtime.service.wallet(customer.id)).balanceMicrocredits,10000*MICRO);
  await online();assert.equal((await runtime.service.listeners(customer.id,'ta')).items[0]?.id,listener.id);
  await runtime.presence.clear(listener.id);assert.equal((await runtime.service.listeners(customer.id,'ta')).items.length,0);
  await assert.rejects(()=>runtime.service.createCall(customer,{listenerId:listener.id,quoteId:'test-audio-v1'},idem()),{code:'LISTENER_OFFLINE'});
});
test('simultaneous callers reserve the listener exactly once; cancellation frees both claims',async()=>{
  await online();
  const results=await Promise.allSettled([customer,customer2].map(a=>runtime.service.createCall(a,{listenerId:listener.id,quoteId:'test-audio-v1'},idem())));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const won=results.find(r=>r.status==='fulfilled') as PromiseFulfilledResult<any>;
  const actor=won.value.customerId===customer.id?customer:customer2;
  const ended=await runtime.service.action(actor,won.value.id,'cancel',{expectedVersion:won.value.version},idem());
  assert.equal(ended.reason,'cancelled');assert.equal(ended.chargeMicrocredits,0);
  const claims=await runtime.db.pool.query('SELECT count(*) FROM active_participant_claims');assert.equal(claims.rows[0].count,'0');
});
test('call creation replay is stable and conflicting payload is rejected',async()=>{
  await online();const key=idem(),body={listenerId:listener.id,quoteId:'test-audio-v1'};
  const a=await runtime.service.createCall(customer,body,key),b=await runtime.service.createCall(customer,body,key);
  assert.equal(a.id,b.id);
  await assert.rejects(()=>runtime.service.createCall(customer,{...body,listenerId:customer2.id},key),{code:'IDEMPOTENCY_CONFLICT'});
  await end(customer,a);
});
test('only invited listener can accept; history and tokens are participant-only',async()=>{
  const call=await invite();
  await assert.rejects(()=>runtime.service.action(customer,call.id,'accept',{expectedVersion:1},idem()),{code:'INVALID_TRANSITION'});
  await assert.rejects(()=>runtime.service.call(customer2.id,call.id),{code:'CALL_NOT_FOUND'});
  await assert.rejects(()=>runtime.service.rtcToken(customer2,call.id),{code:'CALL_NOT_FOUND'});
  await assert.rejects(()=>runtime.service.rtcToken(customer,call.id),{code:'CALL_NOT_ACTIVE'});
  assert.equal((await request(`calls/${call.id}`,'GET',(await runtime.auth.login({handle:'customer2',accessKey:config.devAccessKey,deviceId:'other'},schema)).token)).status,404);
  await accept(call);
  if(!config.agoraAppId)await assert.rejects(()=>runtime.service.rtcToken(customer,call.id),{code:'RTC_UNAVAILABLE'});
  await end(listener,call);
});
test('server metering excludes ringing and reconnect gaps; settlement and journal balance survive retries',async()=>{
  const before=await runtime.service.wallet(customer.id);const call=await invite();now+=10_000;await accept(call);
  await bothReady(call.id);await healthy(call.id,30);
  await runtime.service.media(customer,call.id,{ready:false});now+=10_000;
  await runtime.service.media(listener,call.id,{ready:true});await bothReady(call.id);await healthy(call.id,31);
  const ended=await end(customer,call);assert.equal(ended.connectedMs,61_000);assert.equal(ended.chargeMicrocredits,61*MICRO);
  assert.equal((await runtime.service.wallet(customer.id)).balanceMicrocredits,before.balanceMicrocredits-61*MICRO);
  await end(listener,call);await runtime.service.recover();
  assert.equal((await runtime.service.wallet(customer.id)).balanceMicrocredits,before.balanceMicrocredits-61*MICRO);
  assert.deepEqual(await runtime.service.call(listener.id,call.id),await runtime.service.call(customer.id,call.id));
  const balances=await runtime.db.pool.query('SELECT a.unit,sum(l.amount)::text total FROM journal_lines l JOIN wallet_accounts a ON a.id=l.account_id GROUP BY a.unit');
  assert.ok(balances.rows.every(r=>r.total==='0'));
  const restarted=new NightShiftService(runtime.db,runtime.presence,config,()=>now);
  assert.equal((await restarted.call(customer.id,call.id)).connectedMs,61000);
  const history=await restarted.history(listener.id);assert.ok(history.items.some(c=>c.id===call.id));
});
test('short healthy calls match free reference tariff and untrusted duration is rejected',async()=>{
  const call=await invite();await accept(call);await bothReady(call.id);await healthy(call.id,40);
  await assert.rejects(()=>runtime.service.media(customer,call.id,{ready:true,elapsedMs:600000,price:1}),{code:'INVALID_FIELD'});
  const ended=await end(listener,call);assert.equal(ended.connectedMs,40_000);assert.equal(ended.chargeMicrocredits,0);
});
test('decline, cancelled acceptance, missed invite, failed join and stale media recover with no fabricated time',async()=>{
  const declined=await invite();await runtime.service.action(listener,declined.id,'decline',{expectedVersion:1},idem());
  await assert.rejects(()=>runtime.service.action(listener,declined.id,'accept',{expectedVersion:1},idem()),{code:'CALL_ALREADY_ENDED'});
  const missed=await invite();now+=30001;await runtime.service.recover();assert.equal((await runtime.service.call(customer.id,missed.id)).reason,'timeout');
  const failed=await invite();await accept(failed);now+=45001;await runtime.service.recover();
  assert.equal((await runtime.service.call(customer.id,failed.id)).chargeMicrocredits,0);
  const killed=await invite();await accept(killed);await bothReady(killed.id);await healthy(killed.id,10);
  now+=6000;await runtime.service.recover();assert.equal((await runtime.service.call(customer.id,killed.id)).state,'reconnecting');
  now+=45001;await runtime.service.recover();const result=await runtime.service.call(customer.id,killed.id);
  assert.equal(result.state,'ended');assert.equal(result.connectedMs,10000);assert.equal(result.chargeMicrocredits,0);
});
test('journal cannot be rewritten or left unbalanced at transaction commit',async()=>{
  await assert.rejects(()=>runtime.db.pool.query('UPDATE journal_lines SET amount=amount+1'),/append-only/);
  await assert.rejects(()=>runtime.db.tx(async c=>{
    const id=`invalid:${idem()}`;await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'invalid')",[id]);
    await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,1)',[id,`customer:${customer.id}`]);
  }),/Unbalanced journal/);
});
test('single account cannot switch modes or sign in elsewhere during a call',async()=>{
  const call=await invite();
  await assert.rejects(()=>runtime.service.mode(listener,{mode:'customer'}),{code:'CALL_ACTIVE'});
  await assert.rejects(()=>runtime.auth.login({handle:'listener',accessKey:config.devAccessKey,deviceId:'second'},schema),{code:'CALL_ACTIVE'});
  await end(customer,call);
});
test('language eligibility, media entitlement and event cursors are revalidated',async()=>{
  await runtime.service.languages(customer,{languages:['ta']});await runtime.service.languages(listener,{languages:['en']});await online();
  await assert.rejects(()=>runtime.service.createCall(customer,{listenerId:listener.id,quoteId:'test-audio-v1'},idem()),{code:'LANGUAGE_MISMATCH'});
  await runtime.service.languages(listener,{languages:['ta','en']});
  const call=await invite();await accept(call);
  await runtime.db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[listener.id]);
  await assert.rejects(()=>runtime.service.rtcToken(customer,call.id),{code:'CALL_NOT_ELIGIBLE'});
  await runtime.db.pool.query('UPDATE users SET listener_approved=true WHERE id=$1',[listener.id]);
  const events=await runtime.service.events(customer);const privateEvent=events.items.find(e=>e.entityId===call.id)!;
  await assert.rejects(()=>runtime.service.events(customer2,privateEvent.id),{code:'EVENT_NOT_FOUND'});
  await end(customer,call);
});
test('durable reconnect cursor does not skip transitions committed in the same millisecond',async()=>{
  const call=await invite();
  const before=await runtime.service.events(customer);
  const inviteEvent=before.items.find(event=>event.entityId===call.id)!;
  const accepted=await accept(call);assert.equal(accepted.state,'connecting');
  const replay=await runtime.service.events(customer,inviteEvent.id);
  assert.ok(replay.items.some(event=>event.entityId===call.id&&event.data.state==='connecting'));
  await end(customer,call);
});
test('bounded test-credit exhaustion never overspends and releases unused reservation',async()=>{
  const balance=await runtime.service.wallet(customer2.id);
  const drain=balance.balanceMicrocredits-60*MICRO;
  await runtime.db.tx(async c=>{
    const key=`test-drain:${idem()}`;await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'test-fixture')",[key]);
    await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,$3),($1,$4,$5)',[key,`customer:${customer2.id}`,-drain,'platform:test',drain]);
  });
  const call=await invite(customer2);assert.equal(call.maxDurationSeconds,60);await accept(call);
  await runtime.service.media(customer2,call.id,{ready:true});await runtime.service.media(listener,call.id,{ready:true});
  for(let i=0;i<60;i++){now+=1000;await runtime.service.media(customer2,call.id,{ready:true});await runtime.service.media(listener,call.id,{ready:true});}
  const ended=await runtime.service.call(customer2.id,call.id);assert.equal(ended.state,'ended');assert.equal(ended.reason,'test_credit_limit');
  assert.equal(ended.chargeMicrocredits,60*MICRO);assert.equal((await runtime.service.wallet(customer2.id)).availableMicrocredits,0);
  await assert.rejects(()=>runtime.service.createCall(customer2,{listenerId:listener.id,quoteId:'test-audio-v1'},idem()),{code:'INSUFFICIENT_BALANCE'});
  await assert.rejects(()=>runtime.service.rtcToken(customer2,call.id),{code:'CALL_NOT_ACTIVE'});
});
test('HTTP snapshots, histories, rates and failures conform to the published contract',async()=>{
  const contract=JSON.parse(await readFile(path.resolve(__dirname,'../../../../packages/contracts/openapi.json'),'utf8'));
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  for(const [endpoint,name,token] of [['snapshot','Snapshot',customerToken],['calls','CallPage',customerToken],['listeners','ListenerPage',customerToken],['wallet','Wallet',customerToken],['me','User',customerToken],['snapshot','Error',undefined]]){
    const response=await request(endpoint!,'GET',token);
    const validate=ajv.compile({$defs:definitions,$ref:`#/$defs/${name}`});
    assert.equal(validate(response.body),true,JSON.stringify(validate.errors));
  }
});
test('Socket.IO rejects forged authorization and disconnects a revoked session',async()=>{
  const invalid=io(base,{transports:['websocket'],auth:{token:'forged'},reconnection:false});
  await new Promise<void>((resolve,reject)=>{
    const timer=setTimeout(()=>reject(new Error('Socket auth timeout')),3000);
    invalid.once('connect_error',error=>{clearTimeout(timer);assert.match(error.message,/UNAUTHENTICATED/);invalid.close();resolve();});
  });
  const login=await runtime.auth.login({handle:'customer2',accessKey:config.devAccessKey,deviceId:'socket-device'},schema);
  const socket=io(base,{transports:['websocket'],auth:{token:login.token},reconnection:false});
  await new Promise<void>((resolve,reject)=>{
    const timer=setTimeout(()=>reject(new Error('Socket connection timeout')),3000);
    socket.once('connect',()=>{clearTimeout(timer);resolve();});socket.once('connect_error',reject);
  });
  await runtime.auth.logout(await runtime.auth.authenticate(login.token));
  await new Promise<void>((resolve,reject)=>{
    const timer=setTimeout(()=>reject(new Error('Revoked socket remained connected')),3000);
    socket.once('disconnect',()=>{clearTimeout(timer);socket.close();resolve();});
  });
  await runtime.db.pool.query('UPDATE auth_sessions SET expires_at=now()-interval \'1 second\' WHERE token_hash=$1',[customer.sessionHash]);
  assert.equal((await request('me','GET',customerToken)).status,401);
  await runtime.db.pool.query('UPDATE auth_sessions SET expires_at=now()+interval \'1 hour\' WHERE token_hash=$1',[customer.sessionHash]);
});
test('blocking while the peer ends cannot deadlock on user foreign-key locks',async()=>{
  const call=await invite();const connected=await accept(call);
  const concurrentDb=new Database(config.databaseUrl);
  const ordinaryTx=concurrentDb.tx.bind(concurrentDb);
  let signalCall!:()=>void,signalUsers!:()=>void;
  const callLocked=new Promise<void>(resolve=>{signalCall=resolve;});
  const usersLocked=new Promise<void>(resolve=>{signalUsers=resolve;});
  // Gate the real service transactions at their actual lock acquisition points.
  // End owns the call; block then owns user rows and waits for that call. The FK
  // insert performed by end must remain compatible with those user-row locks.
  concurrentDb.tx=fn=>ordinaryTx(async c=>{
    const client=c as any,original=client.query;
    client.query=async(sql:string,...args:unknown[])=>{
      const result=await original.call(client,sql,...args);
      if(sql.startsWith('SELECT * FROM call_sessions WHERE id=$1 AND')){signalCall();await usersLocked;}
      if(sql.startsWith('SELECT id FROM users WHERE id=ANY'))signalUsers();
      return result;
    };
    try{return await fn(c);}finally{client.query=original;}
  });
  const service=new NightShiftService(concurrentDb,runtime.presence,config,()=>now);
  try{
    const ending=service.action(listener,call.id,'end',{expectedVersion:connected.version},idem());
    await callLocked;
    const blocking=service.block(customer,listener.id);
    await Promise.all([ending,blocking]);
    assert.equal((await runtime.service.call(customer.id,call.id)).state,'ended');
  }finally{
    signalUsers();await concurrentDb.close();
    await runtime.db.pool.query('DELETE FROM blocks WHERE actor_id=$1 AND target_id=$2',[customer.id,listener.id]);
  }
});
test('reports require participation; blocking ends call and excludes discovery and future pairs',async()=>{
  const call=await invite();await accept(call);
  await assert.rejects(()=>runtime.service.report(customer2,{callId:call.id,reason:'test'},idem()),{code:'CALL_NOT_FOUND'});
  const key=idem(),body={callId:call.id,reason:'Synthetic report'};
  assert.deepEqual(await runtime.service.report(customer,body,key),await runtime.service.report(customer,body,key));
  await runtime.service.block(customer,listener.id);
  assert.equal((await runtime.service.call(customer.id,call.id)).reason,'blocked');
  assert.equal((await runtime.service.listeners(customer.id)).items.length,0);
  await assert.rejects(()=>runtime.service.createCall(customer,{listenerId:listener.id,quoteId:'test-audio-v1'},idem()),{code:'PAIR_BLOCKED'});
});
test('logout revokes API authorization and listener presence',async()=>{
  await runtime.auth.logout(listener);
  assert.equal((await request('snapshot','GET',listenerToken)).status,401);
  assert.equal(await runtime.presence.isOnline(listener.id),false);
  assert.equal((await request('snapshot','GET',customerToken)).status,200);
});
