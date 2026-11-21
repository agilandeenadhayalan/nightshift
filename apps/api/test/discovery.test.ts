import 'reflect-metadata';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { io, Socket } from 'socket.io-client';
import { TEST_RATE } from '@nightshift/backend-domain';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { Actor } from '../src/auth';
import { createApplication } from '../src/http';
import { Config } from '../src/config';
import { DIRECTORY_LIMITS } from '../src/directory';
import { DELETION_NOTICE_VERSION } from '../src/account-lifecycle';

// Synthetic adult/approved records exist only in this per-run schema. They do
// not exercise staff authority or turn a real applicant into a listener.
const schema=`discovery_${randomUUID().replaceAll('-','')}`,ids=new Set<string>(),sockets=new Set<Socket>();
let admin:Database,db:Database,runtime:Awaited<ReturnType<typeof createApplication>>,config:Config,base:string,now=Date.now();
type Participant=Actor&{token:string};
const defer=()=>{let release!:()=>void;const wait=new Promise<void>(resolve=>{release=resolve;});return {wait,release};};

before(async()=>{
  assert.ok(process.env.TEST_DATABASE_URL,'Use an explicit dedicated test database');
  assert.ok(process.env.REDIS_URL,'Use the configured isolated Redis endpoint');
  const url=new URL(process.env.TEST_DATABASE_URL!);assert.match(decodeURIComponent(url.pathname.slice(1)),/^[a-z0-9_]+_test$/);
  admin=new Database(url.toString());await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options',`-csearch_path=${schema}`);db=new Database(url.toString());await migrate(db);
  await db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[TEST_RATE.id,TEST_RATE]);
  await db.pool.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES('platform:test','TEST_MICROCREDIT','platform_test'),('subsidy:test','TEST_PAISE','subsidy_test')");
  config={databaseUrl:url.toString(),redisUrl:process.env.REDIS_URL!,port:0,devAccessKey:'isolated-directory-fixture-key-only'};
  runtime=await createApplication(config,()=>now);await runtime.app.listen(0,'127.0.0.1');base=await runtime.app.getUrl();
});
beforeEach(async()=>{
  now=Date.now();for(const socket of sockets)socket.close();sockets.clear();
  // Keep each case's directory distinct without deleting financial/identity rows.
  if(ids.size)await db.pool.query('UPDATE users SET listener_approved=false WHERE id=ANY($1::uuid[])',[[...ids]]);
});
after(async()=>{
  for(const socket of sockets)socket.close();
  if(runtime){for(const id of ids)await runtime.presence.clear(id);await runtime.close();}
  if(db)await db.close();if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}
});

async function participant(listener=false,languages=['ta']):Promise<Participant>{
  const id=randomUUID();ids.add(id);
  await db.tx(async c=>{
    await c.query('INSERT INTO users(id,test_handle,display_name,listener_approved,mode,languages) VALUES($1,$1::uuid::text,$2,$3,$4,$5)',
      [id,'Synthetic public alias',listener,listener?'listener':'customer',languages]);
    await c.query("INSERT INTO wallet_accounts(id,user_id,unit,kind) VALUES($1,$2,'TEST_MICROCREDIT','customer_test'),($3,$2,'TEST_PAISE','listener_test')",[`customer:${id}`,id,`listener:${id}`]);
    await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'fictional_test_grant')",[`fixture:${id}`]);
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,10000000000),($1,'platform:test',-10000000000)",[`fixture:${id}`,`customer:${id}`]);
  });
  const signed=await runtime.auth.login({handle:id,accessKey:config.devAccessKey,deviceId:randomUUID()},`${schema}:${id}`);
  return {...await runtime.auth.authenticate(signed.token),token:signed.token};
}
async function listeners(count:number){const result:Participant[]=[];for(let i=0;i<count;i++)result.push(await participant(true));return result;}
const page=(actor:Actor,filter:Parameters<typeof runtime.service.directory.page>[1]={},favorites=false)=>runtime.service.directory.page(actor,filter,favorites);
async function request(path:string,actor?:Participant,method='GET',body?:unknown){
  const response=await fetch(`${base}/v1/${path}`,{method,headers:{...(actor?{Authorization:`Bearer ${actor.token}`} : {}),...(body===undefined?{}:{'Content-Type':'application/json'})},body:body===undefined?undefined:JSON.stringify(body)});
  return {status:response.status,body:await response.json() as any};
}
async function connect(actor:Participant){
  const socket=io(base,{transports:['websocket'],auth:{token:actor.token},reconnection:false,autoConnect:false});sockets.add(socket);
  const ready=event(socket,'connect');socket.connect();await ready;return socket;
}
function event(socket:Socket,name:string,predicate:(value:any)=>boolean=()=>true):Promise<any>{
  return new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{socket.off(name,handler);reject(new Error(`Timed out waiting for ${name}`));},5000);
    const handler=(value:any)=>{if(predicate(value)){clearTimeout(timer);socket.off(name,handler);resolve(value);}};
    socket.on(name,handler);
  });
}
const subscribe=(socket:Socket,body:unknown):Promise<any>=>socket.timeout(5000).emitWithAck('directory.subscribe',body);

test('frozen pages retain rank, avoid duplicates and exclude later entrants until refresh',async()=>{
  const owner=await participant(),members=await listeners(25),expected=members.map(x=>x.id).sort();
  const first=await page(owner);assert.deepEqual(first.items.map(x=>x.id),expected.slice(0,20));assert.ok(first.nextCursor);
  const entrant=await participant(true);await runtime.service.availability(entrant,{online:true});
  const moved=members.find(x=>x.id===expected[24])!;await runtime.service.availability(moved,{online:true});
  const second=await page(owner,{cursor:first.nextCursor!});
  assert.equal(second.viewEpoch,first.viewEpoch);assert.deepEqual(second.items.map(x=>x.id),expected.slice(20));assert.equal(second.nextCursor,null);
  assert.equal(new Set([...first.items,...second.items].map(x=>x.id)).size,25);
  assert.equal(second.items.find(x=>x.id===moved.id)?.available,true);
  const refreshed=await page(owner);assert.notEqual(refreshed.viewEpoch,first.viewEpoch);assert.ok(refreshed.items.some(x=>x.id===entrant.id));
});

test('pagination advances over removed members and cannot expose current blocked or restricted profiles',async()=>{
  const owner=await participant(),members=await listeners(25),first=await page(owner),ordered=members.map(x=>x.id).sort();
  const remaining=ordered.slice(20);await runtime.service.block(owner,remaining[0]!);
  await db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[remaining[1]]);
  await db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[remaining[2]]);
  const second=await page(owner,{cursor:first.nextCursor!});assert.deepEqual(second.items.map(x=>x.id),remaining.slice(3));assert.equal(second.nextCursor,null);
  const replay=await page(owner,{cursor:first.nextCursor!});assert.deepEqual(replay.items,second.items);
});

test('cursor capabilities bind owner, language, availability filter and favorites collection',async()=>{
  const owner=await participant(),other=await participant();await listeners(21);const first=await page(owner);assert.ok(first.nextCursor);
  for(const [actor,filter,favorites] of [[other,{cursor:first.nextCursor},false],[owner,{cursor:first.nextCursor,language:'en'},false],
    [owner,{cursor:first.nextCursor,availableOnly:true},false],[owner,{cursor:first.nextCursor},true]] as const){
    await assert.rejects(page(actor,filter,favorites),{code:'DIRECTORY_VIEW_NOT_FOUND',status:404});
  }
  await assert.rejects(page(owner,{cursor:owner.id}),{code:'DIRECTORY_VIEW_NOT_FOUND'});
  await assert.rejects(page(owner,{availableOnly:'true'}),{code:'INVALID_FIELD'});
  await assert.rejects(page(owner,{language:['ta']}),{code:'INVALID_LANGUAGE'});
});

test('five-minute views expire and refresh retains only four epochs across both collections',async()=>{
  const owner=await participant();await listeners(21);const first=await page(owner);
  now+=DIRECTORY_LIMITS.lifetimeMs;
  await assert.rejects(page(owner,{cursor:first.nextCursor!}),{code:'DIRECTORY_VIEW_EXPIRED',status:410});
  await runtime.service.directory.cleanupExpired();
  assert.equal((await db.pool.query('SELECT count(*) FROM directory_members WHERE view_id=$1',[first.viewEpoch])).rows[0].count,'0');
  const epochs=[];for(let i=0;i<5;i++)epochs.push(await page(owner,{},i%2===0));
  assert.equal((await db.pool.query('SELECT count(*) FROM directory_views WHERE owner_id=$1',[owner.id])).rows[0].count,'4');
  assert.equal((await db.pool.query('SELECT count(*) FROM directory_views WHERE id=$1',[epochs[0]!.viewEpoch])).rows[0].count,'0');
});

test('directory storage is explicitly bounded and marks a truncated epoch',async()=>{
  const owner=await participant(),bulk=Array.from({length:DIRECTORY_LIMITS.members+1},()=>randomUUID());bulk.forEach(id=>ids.add(id));
  await db.pool.query("INSERT INTO users(id,display_name,listener_approved,mode,languages) SELECT id,'Synthetic bounded fixture',true,'listener',ARRAY['ta'] FROM unnest($1::uuid[]) AS x(id)",[bulk]);
  const result=await page(owner);assert.equal(result.truncated,true);assert.equal(result.items.length,20);
  assert.equal((await db.pool.query('SELECT count(*) FROM directory_members WHERE view_id=$1',[result.viewEpoch])).rows[0].count,String(DIRECTORY_LIMITS.members));
});

test('offline, busy and Redis loss disable calling without discarding the durable busy claim',async()=>{
  const owner=await participant(),caller=await participant(),listener=await participant(true);await runtime.service.availability(listener,{online:true});
  const call=await runtime.service.createCall(caller,{listenerId:listener.id,quoteId:TEST_RATE.id},randomUUID());
  try{
    const result=await page(owner),card=result.items.find(x=>x.id===listener.id)!;assert.equal(card.busy,true);assert.equal(card.available,false);
    await runtime.presence.clear(listener.id);
    const status=await runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[listener.id]});
    assert.equal(status.items[0]?.online,false);assert.equal(status.items[0]?.busy,true);assert.equal(status.items[0]?.available,false);
    assert.equal((await db.pool.query('SELECT call_id FROM active_participant_claims WHERE user_id=$1',[listener.id])).rows[0].call_id,call.id);
    assert.equal((await page(owner,{availableOnly:true})).items.length,0);
    assert.equal((await page(owner)).items.length,1,'offline approved listener remains in the full directory');
  }finally{await runtime.service.action(caller,call.id,'cancel',{expectedVersion:call.version},randomUUID());}
});

test('available, busy and offline ranks use stable UUID ties and exclude the full eligibility matrix',async()=>{
  const owner=await participant(),caller=await participant(),available=await listeners(2),busy=await participant(true),offline=await participant(true);
  const underage=await participant(true),customerMode=await participant(true),unapproved=await participant(true),suspended=await participant(true),reverseBlocked=await participant(true);
  await participant(true,['en']);
  for(const listener of [...available,busy])await runtime.service.availability(listener,{online:true});
  await db.pool.query('UPDATE users SET adult_confirmed=false WHERE id=$1',[underage.id]);
  await runtime.service.mode(customerMode,{mode:'customer'});
  await db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[unapproved.id]);
  await db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[suspended.id]);
  await runtime.service.block(reverseBlocked,owner.id);
  const call=await runtime.service.createCall(caller,{listenerId:busy.id,quoteId:TEST_RATE.id},randomUUID());
  try{
    const result=await page(owner);assert.deepEqual(result.items.map(x=>x.id),[...available.map(x=>x.id).sort(),busy.id,offline.id]);
    assert.equal(result.items[2]?.busy,true);assert.equal(result.items[2]?.available,false);assert.equal(result.items[3]?.online,false);
    assert.deepEqual((await page(owner,{availableOnly:true})).items.map(x=>x.id),available.map(x=>x.id).sort());
  }finally{await runtime.service.action(caller,call.id,'cancel',{expectedVersion:call.version},randomUUID());}
});

test('an available-only served card disables immediately without moving its subscription rank',async()=>{
  const owner=await participant(),listener=await participant(true);await runtime.service.availability(listener,{online:true});
  const view=await page(owner,{availableOnly:true}),subscription=await runtime.service.directory.subscribe(owner,{viewEpoch:view.viewEpoch,language:'ta',visibleIds:[listener.id]});assert.ok(subscription);
  await runtime.service.availability(listener,{online:false});
  const update=await runtime.service.directory.updates(owner,subscription);assert.equal(update.items[0]?.id,listener.id);assert.equal(update.items[0]?.available,false);assert.deepEqual(update.removedIds,[]);
  assert.equal((await page(owner,{availableOnly:true})).items.length,0);
});

test('a restriction committed during Redis lookup is absent from the final directory response',async t=>{
  const owner=await participant(),listener=await participant(true);await runtime.service.availability(listener,{online:true});
  const entered=defer(),release=defer(),original=runtime.presence.online.bind(runtime.presence);let gated=false;
  const mock=t.mock.method(runtime.presence,'online',async(list:string[],versions:ReadonlyMap<string,string>)=>{
    const answer=await original(list,versions);if(!gated&&list.includes(listener.id)){gated=true;entered.release();await release.wait;}return answer;
  });
  const pending=page(owner);await entered.wait;
  try{await db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[listener.id]);release.release();assert.equal((await pending).items.length,0);}
  finally{release.release();await pending;mock.mock.restore();}
});

test('status hydration permits only served, favorited or historical listeners in the selected language',async()=>{
  const owner=await participant(),other=await participant(),ta=await participant(true),en=await participant(true,['en']);
  assert.deepEqual((await runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[ta.id]})).removedIds,[ta.id]);
  const view=await page(owner);assert.ok(view.items.some(x=>x.id===ta.id));
  assert.equal((await runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[ta.id]})).items.length,1);
  assert.equal((await runtime.service.directory.statuses(other,{language:'ta',listenerIds:[ta.id]})).items.length,0);
  await runtime.service.favorite(owner,en.id,true);
  assert.equal((await runtime.service.directory.statuses(owner,{language:'en',listenerIds:[en.id]})).items.length,1);
  assert.equal((await runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[en.id]})).items.length,0);
  await assert.rejects(runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[ta.id,ta.id]}),{code:'INVALID_DIRECTORY_SLICE'});
  await assert.rejects(runtime.service.directory.statuses(owner,{language:'ta',listenerIds:Array.from({length:41},()=>randomUUID())}),{code:'INVALID_DIRECTORY_SLICE'});
});

test('recent-call hydration returns current reachability without rewriting the historical outcome',async()=>{
  const owner=await participant(),outsider=await participant(),listener=await participant(true);await runtime.service.availability(listener,{online:true});
  const call=await runtime.service.createCall(owner,{listenerId:listener.id,quoteId:TEST_RATE.id},randomUUID());
  await runtime.service.action(owner,call.id,'cancel',{expectedVersion:call.version},randomUUID());
  const historical=await runtime.service.call(owner.id,call.id);assert.equal(historical.reason,'cancelled');
  await runtime.service.availability(listener,{online:false});
  const status=await runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[listener.id]});assert.equal(status.items[0]?.available,false);
  assert.equal((await runtime.service.directory.statuses(outsider,{language:'ta',listenerIds:[listener.id]})).items.length,0);
  await runtime.service.availability(listener,{online:true});assert.equal((await runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[listener.id]})).items[0]?.available,true);
  assert.deepEqual(await runtime.service.call(owner.id,call.id),historical);
});

test('subscriptions require served members of the owned epoch and allow explicit unsubscribe',async()=>{
  const owner=await participant(),other=await participant();await listeners(21);const view=await page(owner);
  const unseen=(await db.pool.query('SELECT listener_id FROM directory_members WHERE view_id=$1 AND NOT served',[view.viewEpoch])).rows[0].listener_id;
  const raw={viewEpoch:view.viewEpoch,language:'ta',visibleIds:[view.items[0]!.id]};
  assert.deepEqual(await runtime.service.directory.subscribe(owner,raw),raw);
  await assert.rejects(runtime.service.directory.subscribe(other,raw),{code:'DIRECTORY_VIEW_NOT_FOUND'});
  await assert.rejects(runtime.service.directory.subscribe(owner,{...raw,language:'en'}),{code:'DIRECTORY_VIEW_NOT_FOUND'});
  await assert.rejects(runtime.service.directory.subscribe(owner,{...raw,visibleIds:[unseen]}),{code:'DIRECTORY_VIEW_NOT_FOUND'});
  await assert.rejects(runtime.service.directory.subscribe(owner,{...raw,visibleIds:[raw.visibleIds[0],raw.visibleIds[0]]}),{code:'INVALID_DIRECTORY_SLICE'});
  await assert.rejects(runtime.service.directory.subscribe(owner,{...raw,visibleIds:Array.from({length:41},()=>randomUUID())}),{code:'INVALID_DIRECTORY_SLICE'});
  assert.equal(await runtime.service.directory.subscribe(owner,null),null);
  assert.equal(await runtime.service.directory.subscribe(owner,{visibleIds:[]}),null);
});

test('favorite add is idempotent, private to its owner and removable after eligibility loss',async()=>{
  const owner=await participant(),other=await participant(),listener=await participant(true,['en']);
  await Promise.all(Array.from({length:4},()=>runtime.service.favorite(owner,listener.id,true)));
  assert.equal((await db.pool.query('SELECT count(*) FROM favorites WHERE actor_id=$1 AND target_id=$2',[owner.id,listener.id])).rows[0].count,'1');
  assert.equal((await page(owner,{language:'en'},true)).items[0]?.favorite,true);
  assert.equal((await page(other,{language:'en'},true)).items.length,0);
  await db.pool.query('UPDATE users SET listener_approved=false,suspended=true WHERE id=$1',[listener.id]);
  assert.equal((await page(owner,{language:'en'},true)).items.length,0);
  assert.deepEqual(await runtime.service.favorite(owner,listener.id,false),{favorite:false});
  assert.deepEqual(await runtime.service.favorite(owner,randomUUID(),false),{favorite:false});
  await assert.rejects(runtime.service.favorite(owner,listener.id,true),{code:'NOT_FOUND'});
});

test('either-direction block wins a concurrent favorite write and prunes both private lists',async()=>{
  const owner=await participant(true),listener=await participant(true);
  await runtime.service.favorite(listener,owner.id,true);
  const results=await Promise.allSettled([runtime.service.favorite(owner,listener.id,true),runtime.service.block(listener,owner.id)]);
  assert.equal(results[1]!.status,'fulfilled');
  if(results[0]!.status==='rejected')assert.equal(results[0]!.reason.code,'PAIR_BLOCKED');
  assert.equal((await db.pool.query('SELECT count(*) FROM favorites WHERE actor_id=ANY($1::uuid[])',[[owner.id,listener.id]])).rows[0].count,'0');
  await assert.rejects(runtime.service.favorite(owner,listener.id,true),{code:'PAIR_BLOCKED'});
  await assert.rejects(runtime.service.favorite(listener,owner.id,true),{code:'PAIR_BLOCKED'});
  assert.deepEqual(await runtime.service.favorite(owner,listener.id,false),{favorite:false});
});

test('accepted account deletion purges favorites and transient directory membership atomically',async()=>{
  const owner=await participant(),listener=await participant(true);await runtime.service.favorite(owner,listener.id,true);
  const view=await page(owner),ownView=await page(listener),subscription={viewEpoch:view.viewEpoch,language:'ta',visibleIds:[listener.id]};
  // Trusted synthetic step-up actor at the service boundary, never client JSON.
  await runtime.lifecycle.requestDeletion({...listener,identityAuthTime:Math.floor(now/1000)},
    {noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
  assert.equal((await db.pool.query('SELECT count(*) FROM favorites WHERE actor_id=$1 OR target_id=$1',[listener.id])).rows[0].count,'0');
  assert.equal((await db.pool.query('SELECT count(*) FROM directory_members WHERE listener_id=$1',[listener.id])).rows[0].count,'0');
  assert.equal((await db.pool.query('SELECT count(*) FROM directory_views WHERE id=$1',[ownView.viewEpoch])).rows[0].count,'0');
  assert.deepEqual((await runtime.service.directory.updates(owner,subscription)).removedIds,[listener.id]);
  assert.equal((await page(owner,{},true)).items.length,0);
  await assert.rejects(runtime.service.favorite(owner,listener.id,true),{code:'NOT_FOUND'});
});

test('revoked owner actors cannot page, hydrate, subscribe or mutate favorites',async()=>{
  const owner=await participant(),listener=await participant(true),view=await page(owner);
  const subscription={viewEpoch:view.viewEpoch,language:'ta',visibleIds:[listener.id]};await runtime.auth.logout(owner);
  for(const action of [()=>page(owner),()=>runtime.service.directory.statuses(owner,{language:'ta',listenerIds:[listener.id]}),
    ()=>runtime.service.directory.subscribe(owner,subscription),()=>runtime.service.directory.updates(owner,subscription),
    ()=>runtime.service.favorite(owner,listener.id,true),()=>runtime.service.favorite(owner,listener.id,false),
    ()=>runtime.service.languages(owner,{languages:['en']})])await assert.rejects(action(),{code:'UNAUTHENTICATED'});
});

test('HTTP exposes bounded pages/status/favorites without private profile or identity fields',async()=>{
  const owner=await participant(),listener=await participant(true);
  assert.equal((await request('listeners')).status,401);assert.equal((await request('favorites')).status,401);
  const result=await request('listeners?language=ta',owner);assert.equal(result.status,200);assert.equal(result.body.items[0].id,listener.id);
  assert.deepEqual(Object.keys(result.body.items[0]).sort(),['id','displayName','languages','online','reachability','available','busy','favorite','testOnly','rate','videoRate'].sort());
  assert.equal(result.body.items[0].reachability,'offline');
  const status=await request('listeners/status',owner,'POST',{language:'ta',listenerIds:[listener.id]});assert.equal(status.status,201);assert.equal(status.body.items.length,1);
  assert.equal((await request('listeners?availableOnly=1',owner)).status,400);
  assert.equal((await request(`favorites/${listener.id}`,owner,'PUT')).status,200);
  assert.equal((await request('favorites?language=ta',owner)).body.items.length,1);
  assert.equal((await request(`favorites/${listener.id}`,owner,'DELETE')).status,200);
});

test('socket updates are scoped to the current visible IDs and language, and eligibility removal is explicit',async()=>{
  const owner=await participant(),ta=await participant(true),unseen=await participant(true),en=await participant(true,['en']);
  const view=await page(owner),english=await page(owner,{language:'en'}),socket=await connect(owner),received:any[]=[];
  socket.on('directory.updated',value=>received.push(value));
  let update=event(socket,'directory.updated',value=>value.viewEpoch===view.viewEpoch);
  assert.equal((await subscribe(socket,{viewEpoch:view.viewEpoch,language:'ta',visibleIds:[ta.id]})).ok,true);
  assert.deepEqual((await update).items.map((x:any)=>x.id),[ta.id]);
  const baseline=received.length;
  await runtime.service.availability(unseen,{online:true});await runtime.service.availability(en,{online:true});
  // Observe more than one actual worker interval: unrelated changes cannot fan out.
  await new Promise<void>(resolve=>setTimeout(resolve,1200));assert.equal(received.length,baseline);
  update=event(socket,'directory.updated',value=>value.viewEpoch===view.viewEpoch&&value.items[0]?.online===true);
  await runtime.service.availability(ta,{online:true});await update;
  update=event(socket,'directory.updated',value=>value.viewEpoch===english.viewEpoch);
  assert.equal((await subscribe(socket,{viewEpoch:english.viewEpoch,language:'en',visibleIds:[en.id]})).ok,true);
  assert.deepEqual((await update).items.map((x:any)=>x.id),[en.id]);
  update=event(socket,'directory.updated',value=>value.removedIds.includes(en.id));
  await runtime.service.block(owner,en.id);assert.deepEqual((await update).items,[]);
  assert.equal((await subscribe(socket,null)).ok,true);const stopped=received.length;
  await runtime.service.availability(ta,{online:false});await new Promise<void>(resolve=>setTimeout(resolve,1200));assert.equal(received.length,stopped);
});

test('a denied socket filter change clears the prior slice and a revoked socket disconnects',async()=>{
  const owner=await participant(),other=await participant(),listener=await participant(true),view=await page(owner),foreign=await page(other),socket=await connect(owner),received:any[]=[];
  socket.on('directory.updated',value=>received.push(value));let update=event(socket,'directory.updated');
  await subscribe(socket,{viewEpoch:view.viewEpoch,language:'ta',visibleIds:[listener.id]});await update;
  assert.deepEqual(await subscribe(socket,{viewEpoch:foreign.viewEpoch,language:'ta',visibleIds:[listener.id]}),{ok:false,code:'DIRECTORY_VIEW_NOT_FOUND'});
  const before=received.length;await runtime.service.availability(listener,{online:true});await new Promise<void>(resolve=>setTimeout(resolve,1200));assert.equal(received.length,before);
  const disconnected=event(socket,'disconnect');await runtime.auth.logout(owner);assert.equal(await disconnected,'io server disconnect');
});

test('simultaneous Tamil, English and unsubscribed sockets receive only their relevant segment',async()=>{
  const tamilOwner=await participant(),englishOwner=await participant(),passiveOwner=await participant(),ta=await participant(true),en=await participant(true,['en']);
  const tamil=await page(tamilOwner),english=await page(englishOwner,{language:'en'});
  const taSocket=await connect(tamilOwner),enSocket=await connect(englishOwner),passive=await connect(passiveOwner),deliveries:any[][]=[[],[],[]];
  [taSocket,enSocket,passive].forEach((socket,i)=>socket.on('directory.updated',value=>deliveries[i]!.push(value)));
  const initial=[event(taSocket,'directory.updated'),event(enSocket,'directory.updated')];
  await subscribe(taSocket,{viewEpoch:tamil.viewEpoch,language:'ta',visibleIds:[ta.id]});
  await subscribe(enSocket,{viewEpoch:english.viewEpoch,language:'en',visibleIds:[en.id]});await Promise.all(initial);
  const before=deliveries.map(values=>values.length),changed=event(taSocket,'directory.updated',value=>value.items[0]?.available===true);
  await runtime.service.availability(ta,{online:true});await changed;
  await new Promise<void>(resolve=>setTimeout(resolve,1200));
  assert.deepEqual(deliveries.map((values,i)=>values.length-before[i]!),[1,0,0]);
  assert.ok(deliveries[0]!.every(value=>value.language==='ta'&&value.items.every((card:any)=>card.id===ta.id)));
  assert.ok(deliveries[1]!.every(value=>value.language==='en'&&value.items.every((card:any)=>card.id===en.id)));
});

test('pending subscriptions coalesce to the latest slice without restoring superseded requests',async t=>{
  const owner=await participant(),listener=await participant(true),englishListener=await participant(true,['en']),view=await page(owner),english=await page(owner,{language:'en'}),socket=await connect(owner),received:any[]=[];
  const entered=defer(),release=defer(),original=runtime.service.directory.subscribe.bind(runtime.service.directory);let gated=false;
  const mock=t.mock.method(runtime.service.directory,'subscribe',async(actor:Actor,raw:unknown)=>{
    const result=await original(actor,raw);if(!gated){gated=true;entered.release();await release.wait;}return result;
  });
  socket.on('directory.updated',value=>received.push(value));
  const first=subscribe(socket,{viewEpoch:view.viewEpoch,language:'ta',visibleIds:[listener.id]});await entered.wait;
  try{
    const second=subscribe(socket,null),third=subscribe(socket,{viewEpoch:english.viewEpoch,language:'en',visibleIds:[englishListener.id]});
    assert.deepEqual(await second,{ok:false,code:'DIRECTORY_SUBSCRIPTION_SUPERSEDED'});
    const update=event(socket,'directory.updated');release.release();
    assert.deepEqual(await first,{ok:false,code:'DIRECTORY_SUBSCRIPTION_SUPERSEDED'});
    assert.deepEqual(await third,{ok:true,viewEpoch:english.viewEpoch});await update;
    assert.ok(received.length>0);assert.ok(received.every(value=>value.viewEpoch===english.viewEpoch));
  }finally{release.release();mock.mock.restore();}
});

test('a late directory update cannot cross an acknowledged language switch',async t=>{
  const owner=await participant(),ta=await participant(true),en=await participant(true,['en']),tamil=await page(owner),english=await page(owner,{language:'en'}),socket=await connect(owner),received:any[]=[];
  const entered=defer(),release=defer(),original=runtime.service.directory.updates.bind(runtime.service.directory);let gated=false;
  const mock=t.mock.method(runtime.service.directory,'updates',async(actor:Actor,subscription:Parameters<typeof original>[1])=>{
    const result=await original(actor,subscription);if(!gated&&subscription.viewEpoch===tamil.viewEpoch){gated=true;entered.release();await release.wait;}return result;
  });
  socket.on('directory.updated',value=>received.push(value));await subscribe(socket,{viewEpoch:tamil.viewEpoch,language:'ta',visibleIds:[ta.id]});await entered.wait;
  try{
    const update=event(socket,'directory.updated',value=>value.viewEpoch===english.viewEpoch);
    assert.equal((await subscribe(socket,{viewEpoch:english.viewEpoch,language:'en',visibleIds:[en.id]})).ok,true);release.release();await update;
    assert.ok(received.length>0);assert.ok(received.every(value=>value.viewEpoch===english.viewEpoch));
  }finally{release.release();mock.mock.restore();}
});
