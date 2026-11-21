import {after,before,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {PoolClient} from 'pg';
import {TEST_RATE} from '@nightshift/backend-domain';
import {bounded,deferred,MatchingFixture} from './matching-fixture';

// No HTTP application or recovery timer: End must make progress by itself.
const h=new MatchingFixture();
before(()=>h.open());
after(()=>h.close());
async function connected(seconds=0){
  const customer=await h.participant(),listener=await h.participant(true);
  const invitation=await h.service.createCall(customer,{listenerId:listener.id,quoteId:TEST_RATE.id},randomUUID());
  await h.service.action(listener,invitation.id,'accept',{expectedVersion:invitation.version},randomUUID());
  const healthy=async()=>{await h.service.media(customer,invitation.id,{ready:true});return h.service.media(listener,invitation.id,{ready:true});};
  let call=await healthy();
  for(let second=0;second<seconds;second++){h.advance(1000);call=await healthy();}
  assert.equal(call.state,'connected');return{customer,listener,call};
}
async function effects(id:string){
  return(await h.db.pool.query(`SELECT
    (SELECT count(*)::int FROM call_events WHERE call_id=$1 AND payload->>'state'='ended') terminal,
    (SELECT count(*)::int FROM journal_batches WHERE call_id=$1 AND kind='test_call_settlement') settlements,
    (SELECT count(*)::int FROM active_participant_claims WHERE call_id=$1) claims,
    (SELECT count(*)::int FROM spend_holds WHERE call_id=$1 AND released_at IS NULL) holds`,[id])).rows[0];
}

test('observed-version End progresses after stale media without a recovery worker and settles only confirmed time',async()=>{
  const {customer,listener,call}=await connected(42),body={expectedVersion:call.version},key=randomUUID();
  const before=await h.service.wallet(customer.id);h.advance(6000);
  const ended=await h.service.action(customer,call.id,'end',body,key);
  assert.equal(ended.state,'ended');assert.equal(ended.reason,'participant_ended');
  assert.equal(ended.connectedMs,42000);assert.equal(ended.chargeMicrocredits,call.chargeMicrocredits);assert.ok(ended.chargeMicrocredits>0);
  assert.deepEqual(await effects(call.id),{terminal:1,settlements:1,claims:0,holds:0});
  assert.equal((await h.service.wallet(customer.id)).balanceMicrocredits,before.balanceMicrocredits-ended.chargeMicrocredits);
  const balances=(await h.db.pool.query('SELECT b.id,sum(l.amount)::text total FROM journal_batches b JOIN journal_lines l ON l.batch_id=b.id WHERE b.call_id=$1 GROUP BY b.id',[call.id])).rows;
  assert.equal(balances.length,2);assert.ok(balances.every(row=>row.total==='0'));
  // Lost End responses retain the same body/key. Later healthy requests and
  // another participant's terminal command cannot resurrect or settle again.
  h.advance(10000);assert.deepEqual(await h.service.action(customer,call.id,'end',body,key),ended);
  assert.deepEqual(await h.service.media(customer,call.id,{ready:true}),ended);
  assert.deepEqual(await h.service.media(listener,call.id,{ready:true}),ended);
  assert.deepEqual(await h.service.action(listener,call.id,'end',body,randomUUID()),ended);
  assert.deepEqual(await effects(call.id),{terminal:1,settlements:1,claims:0,holds:0});
  assert.equal((await h.service.wallet(customer.id)).balanceMicrocredits,before.balanceMicrocredits-ended.chargeMicrocredits);
});

test('End still rejects a genuinely stale version after committed media withdrawal',async()=>{
  const {customer,call}=await connected();
  const changed=await h.service.media(customer,call.id,{ready:false});assert.equal(changed.state,'reconnecting');assert.ok(changed.version>call.version);
  await assert.rejects(h.service.action(customer,call.id,'end',{expectedVersion:call.version},randomUUID()),{code:'STALE_VERSION'});
  assert.deepEqual(await effects(call.id),{terminal:0,settlements:0,claims:2,holds:1});
  assert.deepEqual(await h.service.call(customer.id,call.id),changed);
  assert.equal((await h.service.action(customer,call.id,'end',{expectedVersion:changed.version},randomUUID())).state,'ended');
  assert.deepEqual(await effects(call.id),{terminal:1,settlements:0,claims:0,holds:0});
});

test('End queued behind a concurrent committed state transition cannot accept the older observed version',async t=>{
  const {customer,call}=await connected(),changedInsideTransaction=deferred(),allowCommit=deferred(),endLookup=deferred();
  const original=h.db.tx.bind(h.db);let gated=false;
  const mock=t.mock.method(h.db,'tx',async<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>=>original(async c=>{
    const proxy=new Proxy(c,{get(target,key){if(key!=='query')return Reflect.get(target,key);return async(...args:any[])=>{
      const value=await (target.query as (...values:any[])=>Promise<any>).apply(target,args),sql=String(args[0]);
      if(!gated&&sql.startsWith('UPDATE call_sessions SET state=')&&args[1]?.[1]==='reconnecting'){
        gated=true;changedInsideTransaction.release();await allowCommit.promise;
      }else if(gated&&sql.startsWith('SELECT * FROM call_sessions WHERE id=')&&!sql.includes('FOR UPDATE'))endLookup.release();
      return value;
    };}});return fn(proxy);
  }));
  const withdrawal=h.service.media(customer,call.id,{ready:false});let outcome:Promise<unknown>|undefined;
  try{
    await bounded(changedInsideTransaction.promise);
    const ending=h.service.action(customer,call.id,'end',{expectedVersion:call.version},randomUUID());
    outcome=assert.rejects(ending,{code:'STALE_VERSION'});await bounded(endLookup.promise);allowCommit.release();
    const changed=await withdrawal;await outcome;
    assert.deepEqual(await h.service.call(customer.id,call.id),changed);
    assert.deepEqual(await effects(call.id),{terminal:0,settlements:0,claims:2,holds:1});
    assert.equal((await h.service.action(customer,call.id,'end',{expectedVersion:changed.version},randomUUID())).state,'ended');
  }finally{allowCommit.release();await Promise.allSettled([withdrawal,...(outcome?[outcome]:[])]);mock.mock.restore();}
});

test('End idempotency remains payload-bound and reauthorizes the current session before its cached response',async()=>{
  const {customer,call}=await connected(),key=randomUUID(),body={expectedVersion:call.version};
  const ended=await h.service.action(customer,call.id,'end',body,key);
  await assert.rejects(h.service.action(customer,call.id,'end',{expectedVersion:ended.version},key),{code:'IDEMPOTENCY_CONFLICT'});
  const current=await h.refresh(customer);
  await assert.rejects(h.service.action(customer,call.id,'end',body,key),{code:'UNAUTHENTICATED'});
  assert.deepEqual(await h.service.action(current,call.id,'end',body,key),ended);
  assert.deepEqual(await effects(call.id),{terminal:1,settlements:0,claims:0,holds:0});
});
