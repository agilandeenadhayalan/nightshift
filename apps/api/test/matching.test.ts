import {after,before,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {PoolClient} from 'pg';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import {Database} from '../src/db';
import {NightShiftService} from '../src/service';
import {AccountLifecycle,DELETION_NOTICE_VERSION} from '../src/account-lifecycle';
import {rankMatchingCandidates,MatchingCandidate} from '../src/matching';
import {bounded,deferred,MatchingFixture,MatchingParticipant,matchBody} from './matching-fixture';

const h=new MatchingFixture();
before(()=>h.open());
after(()=>h.close());
beforeEach(async()=>{
  // Prior cases keep durable history but cannot supply candidates to this case.
  if(h.ids.size)await h.db.pool.query('UPDATE users SET suspended=true,desired_online=false WHERE id=ANY($1::uuid[])',[[...h.ids]]);
  h.advance(120_000);await h.service.recover();await h.service.matching.processPending(100);
});
const start=(owner:MatchingParticipant,body=matchBody(),key=randomUUID())=>h.service.matching.start(owner,body,key);
async function advance(owner:MatchingParticipant){await h.service.matching.processPending();return(await h.service.matching.current(owner)).request!;}
async function counts(owner:string){return(await h.db.pool.query(`SELECT
  (SELECT count(*)::int FROM call_sessions WHERE customer_id=$1) calls,
  (SELECT count(*)::int FROM active_participant_claims p JOIN call_sessions c ON c.id=p.call_id WHERE c.customer_id=$1) claims,
  (SELECT count(*)::int FROM spend_holds WHERE user_id=$1 AND released_at IS NULL) holds,
  (SELECT count(*)::int FROM journal_batches j JOIN call_sessions c ON c.id=j.call_id WHERE c.customer_id=$1) settlements,
  (SELECT coalesce(sum(charge_microcredits),0)::text FROM call_sessions WHERE customer_id=$1) charge,
  (SELECT coalesce(sum(earning_paise),0)::text FROM call_sessions WHERE customer_id=$1) earnings`,[owner])).rows[0];}
async function noCharge(owner:MatchingParticipant,balance:number){
  const result=await counts(owner.id);assert.equal(result.claims,0);assert.equal(result.holds,0);assert.equal(result.settlements,0);assert.equal(result.charge,'0');assert.equal(result.earnings,'0');
  assert.equal((await h.service.wallet(owner.id)).balanceMicrocredits,balance);
}
async function callFor(owner:MatchingParticipant){const request=(await h.service.matching.current(owner)).request!;assert.ok(request.currentCallId);return h.service.call(owner.id,request.currentCallId);}
async function decline(owner:MatchingParticipant,listeners:MatchingParticipant[]){const call=await callFor(owner),listener=listeners.find(a=>a.id===call.listenerId)!;assert.ok(listener);await h.service.action(listener,call.id,'decline',{expectedVersion:call.version},randomUUID());return call;}

test('matching requires explicit audio consent, supported language and the current quote',async()=>{
  const owner=await h.participant();
  for(const body of [{...matchBody(),consent:false},{...matchBody(),consentVersion:'obsolete'},{...matchBody(),language:'xx'},
    {...matchBody(),mediaType:'video'},{...matchBody(),quoteId:'obsolete'},{...matchBody(),listenerId:randomUUID()}])
    await assert.rejects(h.service.matching.start(owner,body,randomUUID()));
  assert.equal((await h.service.matching.current(owner)).request,null);assert.equal((await counts(owner.id)).calls,0);
});

test('no supply terminates without calls, claims, holds, charges or earnings',async()=>{
  const owner=await h.participant(),balance=(await h.service.wallet(owner.id)).balanceMicrocredits,request=await start(owner);
  assert.equal(request.state,'searching');assert.equal(request.attemptCount,0);assert.equal(request.waitBudgetSeconds,90);
  const result=await advance(owner);assert.equal(result.state,'exhausted');assert.equal(result.terminalReason,'no_supply');assert.equal(result.currentCallId,null);
  assert.equal((await counts(owner.id)).calls,0);await noCharge(owner,balance);
});

test('one hundred concurrent creates retain exactly one active request and stable same-key recovery',async()=>{
  const owner=await h.participant(),key=randomUUID();
  const results=await Promise.allSettled(Array.from({length:100},(_,i)=>start(owner,matchBody(),i<50?key:randomUUID())));
  const fulfilled=results.filter((r):r is PromiseFulfilledResult<Awaited<ReturnType<typeof start>>>=>r.status==='fulfilled');
  assert.ok(fulfilled.length);assert.equal(new Set(fulfilled.map(r=>r.value.id)).size,1);
  for(const result of results)if(result.status==='rejected')assert.equal(result.reason.code,'MATCH_ACTIVE');
  assert.equal((await h.db.pool.query("SELECT count(*)::int total FROM matching_requests WHERE customer_id=$1 AND state IN ('searching','ringing')",[owner.id])).rows[0].total,1);
  const original=await h.service.matching.get(owner,fulfilled[0]!.value.id);
  assert.equal((await start(owner,matchBody(),key)).id,original.id);
  await assert.rejects(start(owner,matchBody('en'),key),{code:'IDEMPOTENCY_CONFLICT'});
});

test('three declines produce distinct sequential invitations and zero settlement',async()=>{
  const owner=await h.participant(),listeners=await Promise.all(Array.from({length:4},()=>h.participant(true))),balance=(await h.service.wallet(owner.id)).balanceMicrocredits;
  const request=await start(owner),seen=new Set<string>();
  for(let ordinal=1;ordinal<=3;ordinal++){
    const progress=await advance(owner);assert.equal(progress.state,'ringing');assert.equal(progress.attemptCount,ordinal);
    const call=await callFor(owner);assert.ok(!seen.has(call.listenerId));seen.add(call.listenerId);
    assert.equal((await counts(owner.id)).claims,2);assert.equal((await counts(owner.id)).holds,1);
    assert.ok(Date.parse(call.expiresAt!)<=Date.parse(request.deadlineAt));
    await decline(owner,listeners);assert.equal((await counts(owner.id)).claims,0);assert.equal((await counts(owner.id)).holds,0);
  }
  const result=await advance(owner);assert.equal(result.state,'exhausted');assert.equal(result.terminalReason,'all_declined');assert.equal(result.attemptCount,3);
  await h.service.matching.processPending();assert.equal((await counts(owner.id)).calls,3);await noCharge(owner,balance);
});

test('timeouts consume the original absolute budget and never create a fourth invitation',async()=>{
  const owner=await h.participant();await Promise.all(Array.from({length:4},()=>h.participant(true)));
  const balance=(await h.service.wallet(owner.id)).balanceMicrocredits,request=await start(owner);
  for(let ordinal=1;ordinal<=3;ordinal++){
    const progress=await advance(owner);assert.equal(progress.attemptCount,ordinal);assert.equal(progress.deadlineAt,request.deadlineAt);
    const call=await callFor(owner);h.now=Date.parse(call.expiresAt!);await h.service.recover();
  }
  const result=await advance(owner);assert.ok(['expired','exhausted'].includes(result.state));assert.equal(result.currentCallId,null);
  h.advance(90_000);await h.service.matching.processPending();assert.equal((await counts(owner.id)).calls,3);await noCharge(owner,balance);
});

test('scheduler delay leaves less than one second without manufacturing a fresh invitation period',async()=>{
  const owner=await h.participant();await h.participant(true);const request=await start(owner);h.now=Date.parse(request.deadlineAt)-999;
  await advance(owner);assert.equal((await counts(owner.id)).calls,0);
  h.advance(1000);const result=await advance(owner);assert.equal(result.state,'expired');assert.equal(result.deadlineAt,request.deadlineAt);
});

test('matching owns the customer during the gap before the first reservation',async()=>{
  const owner=await h.participant(),listener=await h.participant(true);await h.db.pool.query('UPDATE users SET listener_approved=true WHERE id=$1',[owner.id]);
  const request=await start(owner);
  await assert.rejects(h.service.createCall(owner,{listenerId:listener.id,quoteId:matchBody().quoteId},randomUUID()));
  await assert.rejects(h.service.mode(owner,{mode:'listener'}));
  const result=await h.service.matching.cancel(owner,request.id,{expectedVersion:request.version},randomUUID());assert.equal(result.state,'cancelled');
  assert.equal((await counts(owner.id)).calls,0);
});

test('cancel ends one ringing invitation atomically and remains idempotent',async()=>{
  const owner=await h.participant();await h.participant(true);const balance=(await h.service.wallet(owner.id)).balanceMicrocredits;await start(owner);
  const request=await advance(owner),key=randomUUID(),body={expectedVersion:request.version};
  const result=await h.service.matching.cancel(owner,request.id,body,key);assert.equal(result.state,'cancelled');assert.equal(result.currentCallId,null);
  assert.deepEqual(await h.service.matching.cancel(owner,request.id,body,key),result);
  await h.service.matching.processPending();assert.equal((await counts(owner.id)).calls,1);await noCharge(owner,balance);
});

test('accepted-ever remains matched after the call ends before the coordinator observes it',async()=>{
  const owner=await h.participant(),listeners=await Promise.all([h.participant(true),h.participant(true)]);await start(owner);await advance(owner);
  const call=await callFor(owner),actual=listeners.find(listener=>listener.id===call.listenerId);assert.ok(actual);
  const accepted=await h.service.action(actual,call.id,'accept',{expectedVersion:call.version},randomUUID());
  await h.service.action(owner,call.id,'end',{expectedVersion:accepted.version},randomUUID());
  const result=await advance(owner);assert.equal(result.state,'matched');assert.equal(result.currentCallId,call.id);
  h.advance(100_000);const replacement=new NightShiftService(h.db,h.presence,h.config,h.clock);await replacement.matching.processPending();
  assert.equal((await counts(owner.id)).calls,1);assert.equal((await replacement.matching.current(owner)).request!.state,'matched');
});

test('acceptance winning before cancel returns matched and does not end the accepted call',async()=>{
  const owner=await h.participant(),listener=await h.participant(true);await start(owner);const request=await advance(owner),call=await callFor(owner);
  await h.service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID());
  const result=await h.service.matching.cancel(owner,request.id,{expectedVersion:request.version},randomUUID());
  assert.equal(result.state,'matched');assert.equal(result.currentCallId,call.id);assert.equal((await h.service.call(owner.id,call.id)).state,'connecting');
});

test('cancellation winning rejects a late acceptance and prevents automatic fallback',async()=>{
  const owner=await h.participant(),listener=await h.participant(true);await start(owner);const request=await advance(owner),call=await callFor(owner);
  await h.service.matching.cancel(owner,request.id,{expectedVersion:request.version},randomUUID());
  await assert.rejects(h.service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID()));
  await h.service.matching.processPending();assert.equal((await counts(owner.id)).calls,1);assert.equal((await counts(owner.id)).claims,0);
});

test('same-device token refresh preserves search lineage while stale actor/cache reads are denied',async()=>{
  const owner=await h.participant();await h.participant(true);const key=randomUUID(),request=await start(owner,matchBody(),key),fresh=await h.refresh(owner);
  await assert.rejects(start(owner,matchBody(),key),{code:'UNAUTHENTICATED'});
  await assert.rejects(h.service.matching.get(owner,request.id),{code:'UNAUTHENTICATED'});
  assert.equal((await start(fresh,matchBody(),key)).id,request.id);
  const progress=await advance(fresh);assert.equal(progress.state,'ringing');assert.equal(progress.attemptCount,1);
});

for(const change of ['logout','fresh-sign-in','device-takeover','suspension','underage','deletion'] as const)test(`${change} invalidates pending originating lineage before any invitation`,async()=>{
  const owner=await h.participant();await h.participant(true);await start(owner);
  if(change==='logout')await h.auth.logout(owner,c=>h.service.logoutCall(owner,c));
  if(change==='fresh-sign-in')await h.refresh(owner,true);
  if(change==='device-takeover')await h.refresh(owner,true,randomUUID());
  if(change==='suspension')await h.db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[owner.id]);
  if(change==='underage')await h.db.pool.query('UPDATE users SET adult_confirmed=false WHERE id=$1',[owner.id]);
  if(change==='deletion')await new AccountLifecycle(h.db,h.clock,async()=>{}).requestDeletion(owner,{noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:'a'.repeat(64)});
  await h.service.matching.processPending();assert.equal((await counts(owner.id)).calls,0);
  const rows=(await h.db.pool.query('SELECT state FROM matching_requests WHERE customer_id=$1',[owner.id])).rows;assert.equal(rows.length,1);assert.ok(!['searching','ringing'].includes(rows[0].state));
});

test('two coordinator instances race one next ordinal and one invitation event',async()=>{
  const owner=await h.participant();await Promise.all(Array.from({length:3},()=>h.participant(true)));await start(owner);
  const otherDb=new Database(h.config.databaseUrl),other=new NightShiftService(otherDb,h.presence,h.config,h.clock);
  try{await Promise.all([h.service.matching.processPending(),other.matching.processPending()]);}
  finally{await otherDb.close();}
  const current=(await h.service.matching.current(owner)).request!;assert.equal(current.attemptCount,1);assert.equal((await counts(owner.id)).calls,1);
  assert.equal((await h.db.pool.query("SELECT count(*)::int total FROM call_events WHERE call_id=$1 AND kind='call.invited'",[current.currentCallId])).rows[0].total,1);
  assert.equal((await counts(owner.id)).claims,2);assert.equal((await counts(owner.id)).holds,1);
});

for(const restriction of ['block-customer','block-listener','approval','adult','suspension','language','mode','logout','presence','availability'] as const)
test(`candidate ${restriction} committed after selection prevents a stale reservation`,async t=>{
  const owner=await h.participant(),listener=await h.participant(true);await start(owner);
  const entered=deferred(),release=deferred(),original=h.presence.online.bind(h.presence);let once=false;
  const mock=t.mock.method(h.presence,'online',async(...args:Parameters<typeof original>)=>{
    const value=await original(...args);if(!once&&args[0].includes(listener.id)){once=true;entered.release();await release.promise;}return value;
  });
  const pending=h.service.matching.processPending();
  try{
    await bounded(entered.promise);
    if(restriction==='block-customer')await h.service.block(owner,listener.id);
    if(restriction==='block-listener')await h.service.block(listener,owner.id);
    if(restriction==='approval')await h.db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[listener.id]);
    if(restriction==='adult')await h.db.pool.query('UPDATE users SET adult_confirmed=false WHERE id=$1',[listener.id]);
    if(restriction==='suspension')await h.db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[listener.id]);
    if(restriction==='language')await h.db.pool.query("UPDATE users SET languages=ARRAY['en'] WHERE id=$1",[listener.id]);
    if(restriction==='mode')await h.service.mode(listener,{mode:'customer'});
    if(restriction==='logout')await h.auth.logout(listener,c=>h.service.logoutCall(listener,c));
    if(restriction==='presence')await h.presence.clear(listener.id);
    if(restriction==='availability')await h.service.availability(listener,{online:false});
    release.release();await pending;
    assert.equal((await counts(owner.id)).calls,0);assert.equal((await counts(owner.id)).holds,0);
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_listener_fairness WHERE listener_id=$1',[listener.id])).rows[0].total,0);
  }finally{release.release();await Promise.allSettled([pending]);mock.mock.restore();}
});

test('cancel while selection is in flight wins before a reservation can publish',async t=>{
  const owner=await h.participant(),listener=await h.participant(true),request=await start(owner);
  const entered=deferred(),release=deferred(),original=h.presence.online.bind(h.presence);let once=false;
  const mock=t.mock.method(h.presence,'online',async(...args:Parameters<typeof original>)=>{
    const value=await original(...args);if(!once&&args[0].includes(listener.id)){once=true;entered.release();await release.promise;}return value;
  });
  const pending=h.service.matching.processPending();
  try{await bounded(entered.promise);const cancelled=await h.service.matching.cancel(owner,request.id,{expectedVersion:request.version},randomUUID());
    assert.equal(cancelled.state,'cancelled');release.release();await pending;assert.equal((await counts(owner.id)).calls,0);
  }finally{release.release();await Promise.allSettled([pending]);mock.mock.restore();}
});

test('rollback after every reservation write restores claims, hold, ordinal, fairness and event together',async t=>{
  const owner=await h.participant(),listener=await h.participant(true),request=await start(owner),original=h.db.tx.bind(h.db);
  const mock=t.mock.method(h.db,'tx',async<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>=>original(async c=>{
    let reserved=false;
    const proxy=new Proxy(c,{get(target,key){if(key!=='query')return Reflect.get(target,key);return async(...args:any[])=>{
      const result=await (target.query as (...values:any[])=>Promise<any>).apply(target,args);
      if(String(args[0]).includes('INSERT INTO matching_attempts'))reserved=true;return result;
    };}});
    const result=await fn(proxy);if(reserved)throw Error('Synthetic failure before reservation commit');return result;
  }));
  try{await assert.rejects(h.service.matching.processPending(),/Synthetic failure before reservation commit/);}
  finally{mock.mock.restore();}
  assert.deepEqual(await counts(owner.id),{calls:0,claims:0,holds:0,settlements:0,charge:'0',earnings:'0'});
  const row=(await h.db.pool.query('SELECT state,version,attempt_count,current_call_id FROM matching_requests WHERE id=$1',[request.id])).rows[0];
  assert.deepEqual(row,{state:'searching',version:1,attempt_count:0,current_call_id:null});
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_attempts WHERE request_id=$1',[request.id])).rows[0].total,0);
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_listener_fairness WHERE listener_id=$1',[listener.id])).rows[0].total,0);
  const replacement=new NightShiftService(h.db,h.presence,h.config,h.clock);await replacement.matching.processPending();
  assert.equal((await counts(owner.id)).calls,1);assert.equal((await counts(owner.id)).holds,1);
  const current=(await replacement.matching.current(owner)).request!;assert.equal(current.attemptCount,1);
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM outbox_events WHERE event_id IN (SELECT id FROM call_events WHERE call_id=$1)',[current.currentCallId])).rows[0].total,2);
});

test('revoking the originating phone identity without expiring the session stops pending matching',async()=>{
  const owner=await h.participant();await h.participant(true);await start(owner);
  await h.db.pool.query("UPDATE auth_identities SET state='revoked',revoked_at=GREATEST(created_at,$2::timestamptz) WHERE user_id=$1 AND state='verified'",[owner.id,new Date(h.now)]);
  await h.service.matching.processPending();assert.equal((await counts(owner.id)).calls,0);
  assert.equal((await h.db.pool.query('SELECT state FROM matching_requests WHERE customer_id=$1',[owner.id])).rows[0].state,'cancelled');
});

test('a safety block ends this search instead of silently inviting a replacement',async()=>{
  const owner=await h.participant(),listeners=await Promise.all([h.participant(true),h.participant(true)]);await start(owner);await advance(owner);
  const call=await callFor(owner),listener=listeners.find(l=>l.id===call.listenerId)!;await h.service.block(listener,owner.id);
  const result=await advance(owner);assert.equal(result.state,'cancelled');assert.equal(result.terminalReason,'safety_blocked');assert.equal((await counts(owner.id)).calls,1);assert.equal((await counts(owner.id)).holds,0);
});

test('a listener logout can advance but customer logout terminates the remaining consent',async()=>{
  const owner=await h.participant(),listeners=await Promise.all([h.participant(true),h.participant(true)]);await start(owner);await advance(owner);
  const call=await callFor(owner),listener=listeners.find(l=>l.id===call.listenerId)!;await h.auth.logout(listener,c=>h.service.logoutCall(listener,c));
  const next=await advance(owner);assert.equal(next.state,'ringing');assert.equal(next.attemptCount,2);assert.notEqual(next.currentCallId,call.id);
  await h.auth.logout(owner,c=>h.service.logoutCall(owner,c));await h.service.matching.processPending();
  assert.equal((await counts(owner.id)).calls,2);assert.equal((await counts(owner.id)).holds,0);
});

test('seeded fairness gives a neutral newcomer opportunities and randomizes equal candidates only',()=>{
  const seed=Buffer.alloc(32,7),candidates:MatchingCandidate[]=Array.from({length:40},(_,i)=>({id:`00000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`,eligibleSince:1000,lastOfferedAt:null,recentAccepted:0,recentOffered:0}));
  const first=rankMatchingCandidates(candidates,seed).map(c=>c.id);assert.deepEqual(rankMatchingCandidates(candidates,seed).map(c=>c.id),first);
  assert.notDeepEqual(rankMatchingCandidates(candidates,Buffer.alloc(32,8)).map(c=>c.id),first);
  const seen=new Set<string>();
  for(let i=0;i<candidates.length;i++){
    const selected=rankMatchingCandidates(candidates,seed)[0]!,chosen=candidates.find(c=>c.id===selected.id)!;assert.ok(!seen.has(chosen.id),'A stable population must get one opportunity before repeats');seen.add(chosen.id);chosen.lastOfferedAt=2000+i;chosen.recentOffered++;
  }
  assert.equal(seen.size,candidates.length);
  const newcomer={id:'ffffffff-ffff-4fff-8fff-ffffffffffff',eligibleSince:1500,lastOfferedAt:null,recentAccepted:0,recentOffered:0};
  assert.equal(rankMatchingCandidates([...candidates,newcomer],seed)[0]!.id,newcomer.id);
});

test('a high-UUID newcomer receives a real invitation beyond the directory 2,000-member cutoff',async()=>{
  const owner=await h.participant(),low=Array.from({length:2001},(_,i)=>`00000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`),high='ffffffff-ffff-4fff-8fff-ffffffffffff';
  await h.developmentListeners([...low,high]);
  // Established listeners have explicit synthetic recent-offer history; the
  // high UUID became eligible only one second ago and has no acceptance record.
  await h.db.pool.query('UPDATE users SET created_at=$2 WHERE id=ANY($1::uuid[])',[low,new Date(h.now-86_400_000)]);
  await h.db.pool.query('UPDATE users SET created_at=$2 WHERE id=$1',[high,new Date(h.now-1000)]);
  await h.db.pool.query('INSERT INTO matching_listener_fairness(listener_id,last_offered_at) SELECT id,$2::timestamptz FROM unnest($1::uuid[]) id',[low,new Date(h.now-500)]);
  await start(owner);const result=await advance(owner);assert.equal(result.state,'ringing');
  assert.equal((await callFor(owner)).listenerId,high);assert.equal(result.attemptCount,1);
});

test('expired Redis candidates in the first fairness page cannot permanently hide later eligible supply',async()=>{
  const owner=await h.participant(),ids=Array.from({length:51},(_,i)=>`10000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`);
  await h.developmentListeners(ids);for(const id of ids.slice(0,50))await h.presence.clear(id);
  await start(owner);const result=await advance(owner);assert.equal(result.state,'ringing');assert.equal((await callFor(owner)).listenerId,ids[50]);
  assert.equal(result.attemptCount,1);
});

test('twenty ringing requests cannot starve the next searching request under the bounded worker limit',async()=>{
  const owners:MatchingParticipant[]=[];for(let i=0;i<21;i++)owners.push(await h.participant());
  await Promise.all(Array.from({length:21},()=>h.participant(true)));await Promise.all(owners.map(owner=>start(owner)));
  const lastId=(await h.db.pool.query('SELECT customer_id FROM matching_requests WHERE customer_id=ANY($1::uuid[]) ORDER BY sequence DESC LIMIT 1',[owners.map(owner=>owner.id)])).rows[0].customer_id;
  const last=owners.find(owner=>owner.id===lastId)!;
  await h.service.matching.processPending(20);assert.equal((await counts(last.id)).calls,0);
  await h.service.matching.processPending(20);assert.equal((await h.service.matching.current(last)).request!.state,'ringing');
});

test('credit depletion after opt-in fails without a reservation or consumed fairness turn',async()=>{
  const owner=await h.participant(),listener=await h.participant(true);await start(owner);
  const balance=(await h.service.wallet(owner.id)).balanceMicrocredits,batch=`matching-depletion:${randomUUID()}`;
  await h.db.tx(async c=>{await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'fictional_test_adjustment')",[batch]);
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,$3),($1,'platform:test',$4)",[batch,`customer:${owner.id}`,-balance,balance]);});
  const result=await advance(owner);assert.equal(result.state,'failed');assert.equal(result.terminalReason,'insufficient_balance');assert.equal((await counts(owner.id)).calls,0);
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_listener_fairness WHERE listener_id=$1',[listener.id])).rows[0].total,0);
});

test('one hundred mixed matching/direct customers contend for one durable listener claim',{timeout:60000},async()=>{
  const listener=await h.participant(true),customers:MatchingParticipant[]=[];
  for(let batch=0;batch<10;batch++)customers.push(...await Promise.all(Array.from({length:10},()=>h.participant())));
  await Promise.all(customers.slice(0,50).map(owner=>start(owner)));
  const workerUrl=new URL(h.config.databaseUrl);workerUrl.searchParams.set('application_name','matching-contention-worker');
  const workerDb=new Database(workerUrl.toString()),worker=new NightShiftService(workerDb,h.presence,h.config,h.clock);
  const gateDb=new Database(h.config.databaseUrl),gate=await gateDb.pool.connect();
  await gate.query('BEGIN');await gate.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[listener.id]);
  const pending=[...customers.slice(50).map(owner=>h.service.createCall(owner,{listenerId:listener.id,quoteId:matchBody().quoteId},randomUUID())),
    ...customers.slice(0,50).map(()=>worker.matching.processPending(100))];
  const settled=Promise.allSettled(pending);
  try{
    const deadline=Date.now()+5000;let blocked=0,workersBlocked=0;
    do{
      await gate.query('SELECT pg_stat_clear_snapshot()');
      const row=(await gate.query("SELECT count(*) total,count(*) FILTER(WHERE application_name='matching-contention-worker') workers FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid() AND cardinality(pg_blocking_pids(pid))>0")).rows[0];
      blocked=Number(row.total);workersBlocked=Number(row.workers);
      if(workersBlocked>=1&&blocked>workersBlocked)break;await new Promise<void>(resolve=>setTimeout(resolve,10));
    }while(Date.now()<deadline);
    assert.ok(workersBlocked>=1&&blocked>workersBlocked,`The gate must observe both matching and direct-call database lock waiters (total=${blocked}, workers=${workersBlocked})`);
    await gate.query('COMMIT');const outcomes=await settled;
    for(const outcome of outcomes.slice(0,50))if(outcome.status==='rejected')assert.equal(outcome.reason.code,'LISTENER_BUSY');
    for(const outcome of outcomes.slice(50))assert.equal(outcome.status,'fulfilled',outcome.status==='rejected'?String(outcome.reason):undefined);
    const active=(await h.db.pool.query("SELECT c.id,c.customer_id FROM call_sessions c JOIN active_participant_claims p ON p.call_id=c.id WHERE p.user_id=$1",[listener.id])).rows;
    assert.equal(active.length,1);
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM active_participant_claims WHERE call_id=$1',[active[0].id])).rows[0].total,2);
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM spend_holds WHERE user_id=ANY($1::uuid[]) AND released_at IS NULL',[customers.map(c=>c.id)])).rows[0].total,1);
    assert.equal((await h.db.pool.query("SELECT count(*)::int total FROM call_sessions WHERE customer_id=ANY($1::uuid[]) AND state<>'ended'",[customers.map(c=>c.id)])).rows[0].total,1);
    assert.equal((await h.db.pool.query(`SELECT count(*)::int total FROM matching_attempts a LEFT JOIN call_sessions c ON c.id=a.call_id WHERE c.id IS NULL`)).rows[0].total,0);
  }finally{await gate.query('ROLLBACK');gate.release();await gateDb.close();await settled;await workerDb.close();}
});

for(const expires of ['customer','listener'] as const)test(`${expires} session expiry during the final Redis read cannot authorize a new invitation`,async t=>{
  const owner=await h.participant(),listener=await h.participant(true);await start(owner);
  const target=expires==='customer'?owner:listener;
  await h.db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[target.sessionHash,new Date(h.now+500)]);
  const entered=deferred(),release=deferred(),original=h.presence.online.bind(h.presence);let reads=0;
  const mock=t.mock.method(h.presence,'online',async(...args:Parameters<typeof original>)=>{
    const value=await original(...args);if(args[0].includes(listener.id)&&++reads===2){entered.release();await release.promise;}return value;
  });
  const pending=h.service.matching.processPending();
  try{await bounded(entered.promise);h.advance(1000);release.release();const outcome=await Promise.allSettled([pending]);
    if(outcome[0]!.status==='rejected')assert.ok(['UNAUTHENTICATED','LISTENER_OFFLINE'].includes(outcome[0]!.reason.code));
    assert.equal((await counts(owner.id)).calls,0);await h.service.matching.processPending();assert.equal((await counts(owner.id)).holds,0);
  }finally{release.release();await Promise.allSettled([pending]);mock.mock.restore();}
});

test('three stale cancellation snapshots return a conflict rather than a successful still-ringing response',async t=>{
  const owner=await h.participant();await h.participant(true);await start(owner);const request=await advance(owner);
  const original=h.db.pool.query.bind(h.db.pool) as (...args:any[])=>Promise<any>;let snapshots=0;
  const mock=t.mock.method(h.db.pool,'query',async(...args:any[])=>{
    const result=await original(...args);
    if(String(args[0]).startsWith('SELECT m.*,s.listener_id')&&args[1]?.[0]===request.id){snapshots++;return{...result,rows:result.rows.map((r:any)=>({...r,version:r.version-1}))};}
    return result;
  });
  try{await assert.rejects(h.service.matching.cancel(owner,request.id,{expectedVersion:request.version},randomUUID()),{code:'MATCH_STALE_VERSION'});assert.equal(snapshots,3);}
  finally{mock.mock.restore();}
  assert.equal((await h.service.matching.get(owner,request.id)).state,'ringing');assert.equal((await counts(owner.id)).claims,2);
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_commands WHERE request_id=$1',[request.id])).rows[0].total,0);
});

test('one failed reservation cannot starve a later independent matching request',async t=>{
  const first=await h.participant(),second=await h.participant();await Promise.all([h.participant(true),h.participant(true)]);
  const failed=await start(first);await start(second);const original=h.db.tx.bind(h.db);let faults=0;
  const prior=(await h.db.pool.query("SELECT to_char(last_processed_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"') value FROM matching_requests WHERE id=$1",[failed.id])).rows[0].value;
  const mock=t.mock.method(h.db,'tx',async<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>=>original(async c=>{
    const proxy=new Proxy(c,{get(target,key){if(key!=='query')return Reflect.get(target,key);return async(...args:any[])=>{
      const result=await (target.query as (...values:any[])=>Promise<any>).apply(target,args);
      if(String(args[0]).includes('INSERT INTO matching_attempts')&&args[1]?.[0]===failed.id){faults++;throw Error('Synthetic isolated matching reservation failure');}return result;
    };}});return fn(proxy);
  }));
  try{
    await assert.rejects(h.service.matching.processPending());assert.equal(faults,1);
    assert.equal((await counts(first.id)).calls,0);assert.equal((await counts(first.id)).holds,0);
    assert.equal((await counts(second.id)).calls,1);assert.equal((await counts(second.id)).holds,1);
    assert.equal((await h.db.pool.query('SELECT last_processed_at>$2::timestamptz advanced FROM matching_requests WHERE id=$1',[failed.id,prior])).rows[0].advanced,true);
  }finally{mock.mock.restore();}
});

test('session expiry while matching admission rate limiting waits cannot create a request',async t=>{
  const owner=await h.participant();await h.db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[owner.sessionHash,new Date(h.now+500)]);
  const entered=deferred(),release=deferred(),original=h.presence.rateLimit.bind(h.presence);
  const mock=t.mock.method(h.presence,'rateLimit',async(...args:Parameters<typeof original>)=>{
    const result=await original(...args);if(args[0]===`matching:${owner.id}`){entered.release();await release.promise;}return result;
  });
  const pending=start(owner),denied=assert.rejects(pending,{code:'UNAUTHENTICATED'});
  try{await bounded(entered.promise);h.advance(1000);release.release();await denied;
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_requests WHERE customer_id=$1',[owner.id])).rows[0].total,0);
  }finally{release.release();await Promise.allSettled([denied]);mock.mock.restore();}
});

test('the final Redis wait cannot leave a sub-second invitation or extend the matching deadline',async t=>{
  const owner=await h.participant(),listener=await h.participant(true),request=await start(owner);h.now=Date.parse(request.deadlineAt)-1000;
  const entered=deferred(),release=deferred(),original=h.presence.online.bind(h.presence);let reads=0;
  const mock=t.mock.method(h.presence,'online',async(...args:Parameters<typeof original>)=>{
    const value=await original(...args);if(args[0].includes(listener.id)&&++reads===2){entered.release();await release.promise;}return value;
  });
  const pending=h.service.matching.processPending();
  try{await bounded(entered.promise);h.advance(1);release.release();await pending;
    const result=(await h.service.matching.current(owner)).request!;assert.equal(result.state,'expired');assert.equal(result.attemptCount,0);assert.equal(result.deadlineAt,request.deadlineAt);
    assert.equal((await counts(owner.id)).calls,0);assert.equal((await counts(owner.id)).holds,0);
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_attempts WHERE request_id=$1',[request.id])).rows[0].total,0);
  }finally{release.release();await Promise.allSettled([pending]);mock.mock.restore();}
});

test('owner HTTP matching routes enforce the published contract and exclude private selection data',async()=>{
  const owner=await h.participant(),other=await h.participant(),listener=await h.participant(true),contract=require('@nightshift/contracts/openapi.json');
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  const validate=(name:string,value:unknown)=>{const check=ajv.compile({$defs:definitions,$ref:`#/$defs/${name}`});assert.equal(check(value),true,JSON.stringify(check.errors));};
  assert.equal((await h.request('matches',undefined,'POST',matchBody(),randomUUID())).status,401);
  assert.equal((await h.request('matches',listener,'POST',matchBody(),randomUUID())).status,403);
  assert.equal((await h.request('matches?owner='+other.id,owner,'POST',matchBody(),randomUUID())).status,400);
  assert.equal((await h.request('matches',owner,'POST',{...matchBody(),rank:1},randomUUID())).status,400);
  assert.equal((await h.request('matches',owner,'POST',matchBody())).status,400);
  const key=randomUUID(),created=await h.request('matches',owner,'POST',matchBody(),key);assert.equal(created.status,200);validate('MatchingRequest',created.body);
  assert.equal((await h.request(`matches/${created.body.id}`,other)).status,404);
  const latest=await h.request('me/match',owner);assert.equal(latest.status,200);validate('CurrentMatchingRequest',latest.body);assert.equal(latest.body.request.id,created.body.id);
  const replay=await h.request('matches',owner,'POST',matchBody(),key);assert.equal(replay.status,200);assert.equal(replay.body.id,created.body.id);
  await h.service.matching.processPending();const progress=await h.request(`matches/${created.body.id}`,owner);assert.equal(progress.status,200);validate('MatchingRequest',progress.body);
  const serialized=JSON.stringify(progress.body);for(const privateValue of [owner.token,owner.mobile,owner.uid,listener.token,listener.mobile,listener.uid])assert.ok(!serialized.includes(privateValue));
  for(const privateField of ['selection_seed','score','recentAccepted','source_session_hash','source_auth_time','candidates'])assert.ok(!serialized.includes(privateField));
  const cancelled=await h.request(`matches/${created.body.id}/cancel`,owner,'POST',{expectedVersion:progress.body.version},randomUUID());assert.equal(cancelled.status,200);validate('MatchingRequest',cancelled.body);assert.equal(cancelled.body.state,'cancelled');
});
