import {after,before,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import {MICRO,TEST_RATE,TEST_VIDEO_RATE,TestRate} from '@nightshift/backend-domain';
import {NightShiftService} from '../src/service';
import {MatchingFixture,MatchingParticipant} from './matching-fixture';

const h=new MatchingFixture();
before(async()=>{
  await h.open();
  await h.db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[TEST_VIDEO_RATE.id,TEST_VIDEO_RATE]);
  // Synthetic configuration enables the existing video reservation path only;
  // these tests never request an RTC token or contact a media provider.
  h.config.videoCallsEnabled=true;h.config.agoraAppId='a'.repeat(32);h.config.agoraAppCertificate='b'.repeat(32);
  h.service=new NightShiftService(h.db,h.presence,h.config,h.clock);
});
after(()=>h.close());

async function balance(owner:MatchingParticipant,amount:number){
  const old=(await h.service.wallet(owner.id)).balanceMicrocredits,delta=amount-old;
  if(!delta)return;
  const id=`allowance-fixture:${randomUUID()}`;
  await h.db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'fictional_test_grant')",[id]);
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,$3),($1,'platform:test',$4)",[id,`customer:${owner.id}`,delta,-delta]);
  });
}
async function invite(rate:TestRate=TEST_RATE,seconds=60){
  const customer=await h.participant(),listener=await h.participant(true);
  await balance(customer,seconds*rate.microcreditsPerSecond);
  const body={listenerId:listener.id,quoteId:rate.id,...(rate.id===TEST_VIDEO_RATE.id?{mediaType:'video',videoConsent:true}:{})},key=randomUUID();
  const call=await h.service.createCall(customer,body,key);
  return{customer,listener,body,key,call};
}
type Invitation=Awaited<ReturnType<typeof invite>>;
async function healthy(pair:Invitation){
  const body={ready:true,...(pair.call.mediaType==='video'?{videoReady:true}:{})};
  await h.service.media(pair.customer,pair.call.id,body);return h.service.media(pair.listener,pair.call.id,body);
}
async function accept(pair:Invitation){
  await h.service.action(pair.listener,pair.call.id,'accept',{expectedVersion:pair.call.version,...(pair.call.mediaType==='video'?{videoConsent:true}:{})},randomUUID());
  return healthy(pair);
}
async function cancel(pair:Invitation){return h.service.action(pair.customer,pair.call.id,'cancel',{expectedVersion:pair.call.version},randomUUID());}
async function effects(id:string){
  return(await h.db.pool.query(`SELECT
    (SELECT count(*)::int FROM active_participant_claims WHERE call_id=$1) claims,
    (SELECT count(*)::int FROM spend_holds WHERE call_id=$1 AND released_at IS NULL) holds,
    (SELECT count(*)::int FROM journal_batches WHERE call_id=$1 AND kind='test_call_settlement') settlements,
    (SELECT count(*)::int FROM call_events WHERE call_id=$1 AND payload->>'state'='ended') terminal`,[id])).rows[0];
}
async function validator(name:string){
  const contract=JSON.parse(await readFile(path.resolve(__dirname,'../../../../packages/contracts/openapi.json'),'utf8'));
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);return ajv.compile({$defs:definitions,$ref:`#/$defs/${name}`});
}

test('audio and video distinguish the frozen credit allowance from the exact development cap',async()=>{
  for(const rate of [TEST_RATE,TEST_VIDEO_RATE])for(const seconds of [60,599,600,900]){
    const pair=await invite(rate,seconds);
    try{
      assert.equal(pair.call.maxDurationSeconds,Math.min(600,seconds));
      assert.equal((pair.call as any).durationLimitReason,seconds<600?'test_credit_balance':'test_duration_cap');
      const hold=(await h.db.pool.query('SELECT amount::text FROM spend_holds WHERE call_id=$1',[pair.call.id])).rows[0];
      assert.equal(Number(hold.amount),Math.min(600,seconds)*rate.microcreditsPerSecond);
      assert.equal(pair.call.connectedMs,0);assert.equal(pair.call.chargeMicrocredits,0);
      assert.deepEqual(pair.call.rate,rate);
    }finally{await cancel(pair);}
  }
});

test('allowance metadata cannot lower the existing minimum reservation or be supplied by a caller',async()=>{
  for(const rate of [TEST_RATE,TEST_VIDEO_RATE]){
    const customer=await h.participant(),listener=await h.participant(true);
    await balance(customer,60*rate.microcreditsPerSecond-1);
    const body={listenerId:listener.id,quoteId:rate.id,...(rate.id===TEST_VIDEO_RATE.id?{mediaType:'video',videoConsent:true}:{})};
    await assert.rejects(h.service.createCall(customer,body,randomUUID()),{code:'INSUFFICIENT_BALANCE'});
    await assert.rejects(h.service.createCall(customer,{...body,durationLimitReason:'test_duration_cap'},randomUUID()),{code:'INVALID_FIELD'});
    assert.equal((await h.db.pool.query('SELECT count(*)::int count FROM call_sessions WHERE customer_id=$1',[customer.id])).rows[0].count,0);
  }
});

test('later wallet credits do not change the frozen allowance reason or mutate the call on reads',async()=>{
  const pair=await invite(TEST_RATE,90);
  await balance(pair.customer,2000*MICRO);
  const before=(await h.db.pool.query('SELECT to_jsonb(c) value FROM call_sessions c WHERE id=$1',[pair.call.id])).rows[0].value;
  const financialBefore=await effects(pair.call.id);
  const current=await h.service.call(pair.customer.id,pair.call.id);
  assert.equal(current.maxDurationSeconds,90);assert.equal((current as any).durationLimitReason,'test_credit_balance');
  assert.deepEqual((await h.service.history(pair.listener.id)).items.find(c=>c.id===pair.call.id),current);
  assert.deepEqual((await h.db.pool.query('SELECT to_jsonb(c) value FROM call_sessions c WHERE id=$1',[pair.call.id])).rows[0].value,before);
  assert.deepEqual(await effects(pair.call.id),financialBefore);
  await cancel(pair);
});

test('the minimum charge jump leaves healthy allowance and preserves one balanced settlement for both rates',async()=>{
  for(const rate of [TEST_RATE,TEST_VIDEO_RATE]){
    const pair=await invite(rate,60);let call=await accept(pair);
    for(let i=0;i<40;i++){h.advance(1000);call=await healthy(pair);}
    assert.equal(call.connectedMs,40000);assert.equal(call.chargeMicrocredits,0);
    assert.equal(call.maxDurationSeconds*1000-call.connectedMs,20000);
    h.advance(1);call=await healthy(pair);
    assert.equal(call.connectedMs,40001);assert.equal(call.chargeMicrocredits,60*rate.microcreditsPerSecond);
    assert.equal(call.maxDurationSeconds*1000-call.connectedMs,19999);
    assert.equal((call as any).durationLimitReason,'test_credit_balance');
    // Held availability can be zero while delivered-time allowance remains.
    assert.equal((await h.service.wallet(pair.customer.id)).availableMicrocredits,0);
    const ended=await h.service.action(pair.customer,call.id,'end',{expectedVersion:call.version},randomUUID());
    assert.equal(ended.connectedMs,40001);assert.equal(ended.chargeMicrocredits,60*rate.microcreditsPerSecond);
    assert.deepEqual(await effects(call.id),{claims:0,holds:0,settlements:1,terminal:1});
    const batches=(await h.db.pool.query('SELECT b.id,sum(l.amount)::text total FROM journal_batches b JOIN journal_lines l ON l.batch_id=b.id WHERE b.call_id=$1 GROUP BY b.id',[call.id])).rows;
    assert.equal(batches.length,2);assert.ok(batches.every(row=>row.total==='0'));
  }
});

test('ringing and reconnect waits cannot spend or extend the frozen healthy-time allowance',async()=>{
  const pair=await invite(TEST_RATE,90);h.advance(5000);
  assert.equal((await h.service.call(pair.customer.id,pair.call.id)).connectedMs,0);
  let call=await accept(pair);
  for(let i=0;i<10;i++){h.advance(1000);call=await healthy(pair);}
  await h.service.media(pair.customer,call.id,{ready:false});h.advance(20000);await h.service.recover();
  call=await h.service.call(pair.customer.id,call.id);
  assert.equal(call.state,'reconnecting');assert.equal(call.connectedMs,10000);assert.equal(call.chargeMicrocredits,0);
  assert.equal(call.maxDurationSeconds,90);assert.equal((call as any).durationLimitReason,'test_credit_balance');
  assert.equal(call.maxDurationSeconds*1000-call.connectedMs,80000);
  await healthy(pair);h.advance(1000);call=await healthy(pair);assert.equal(call.connectedMs,11000);
  await h.service.action(pair.customer,call.id,'end',{expectedVersion:call.version},randomUUID());
});

test('current HTTP calls, snapshots, histories and durable events publish the reason only to participants',async()=>{
  const pair=await invite(TEST_RATE,90),outsider=await h.participant();
  const schemas={Call:await validator('Call'),Snapshot:await validator('Snapshot'),CallPage:await validator('CallPage'),Event:await validator('Event')};
  const current=await h.request(`calls/${pair.call.id}`,pair.customer);
  assert.equal(current.status,200);assert.equal(current.body.durationLimitReason,'test_credit_balance');
  assert.equal(schemas.Call(current.body),true,JSON.stringify(schemas.Call.errors));
  const snapshot=await h.request('snapshot',pair.listener);assert.equal(snapshot.status,200);
  assert.equal(schemas.Snapshot(snapshot.body),true,JSON.stringify(schemas.Snapshot.errors));
  assert.equal(snapshot.body.activeCall.durationLimitReason,'test_credit_balance');
  const history=await h.request('calls',pair.customer);assert.equal(schemas.CallPage(history.body),true,JSON.stringify(schemas.CallPage.errors));
  const events=await h.request('events',pair.customer);assert.equal(events.status,200);
  const own=events.body.items.filter((event:any)=>event.entityId===pair.call.id);assert.equal(own.length,1);
  assert.equal(own[0].data.durationLimitReason,'test_credit_balance');assert.equal(schemas.Event(own[0]),true,JSON.stringify(schemas.Event.errors));
  assert.equal((await h.request(`calls/${pair.call.id}`,outsider)).status,404);
  assert.equal((await h.request(`calls/${pair.call.id}`)).status,401);
  const foreignHistory=await h.request('calls',outsider),foreignEvents=await h.request('events',outsider);
  assert.ok(!JSON.stringify(foreignHistory.body).includes(pair.call.id));assert.ok(!JSON.stringify(foreignEvents.body).includes(pair.call.id));
  await cancel(pair);
});

test('legacy cached receipts remain field-absent, schema-valid and currently authorized without new effects',async()=>{
  const pair=await invite(TEST_RATE,90);
  // Represent a receipt written by the previous deployed API before this
  // additive field existed. Runtime reads must not rewrite historical replies.
  await h.db.pool.query("UPDATE idempotency_keys SET response=response-'durationLimitReason' WHERE actor_id=$1 AND operation='create-call' AND key=$2",[pair.customer.id,pair.key]);
  const saved=(await h.db.pool.query("SELECT response FROM idempotency_keys WHERE actor_id=$1 AND operation='create-call' AND key=$2",[pair.customer.id,pair.key])).rows[0].response;
  const before=await effects(pair.call.id),response=await h.request('calls',pair.customer,'POST',pair.body,pair.key);
  assert.equal(response.status,201);assert.deepEqual(response.body,saved);assert.equal(Object.hasOwn(response.body,'durationLimitReason'),false);
  const valid=await validator('Call');assert.equal(valid(response.body),true,JSON.stringify(valid.errors));
  assert.deepEqual(await effects(pair.call.id),before);
  assert.deepEqual((await h.db.pool.query("SELECT response FROM idempotency_keys WHERE actor_id=$1 AND operation='create-call' AND key=$2",[pair.customer.id,pair.key])).rows[0].response,saved);
  const replacement=await h.refresh(pair.customer);
  assert.equal((await h.request('calls',pair.customer,'POST',pair.body,pair.key)).status,401);
  assert.deepEqual((await h.request('calls',replacement,'POST',pair.body,pair.key)).body,saved);
  assert.equal((await h.request('calls',replacement,'POST',{...pair.body,listenerId:replacement.id},pair.key)).status,400);
  await h.service.action(replacement,pair.call.id,'cancel',{expectedVersion:pair.call.version},randomUUID());
});

test('legacy durable event payloads stay byte-for-byte absent while current history derives the new reason',async()=>{
  const pair=await invite(TEST_RATE,600);await cancel(pair);
  // A pre-upgrade event is an immutable observation, not a current projection.
  // The isolated fixture removes only the newly introduced field before reads.
  await h.db.pool.query("UPDATE call_events SET payload=payload-'durationLimitReason' WHERE call_id=$1",[pair.call.id]);
  const before=(await h.db.pool.query('SELECT id,payload::text payload FROM call_events WHERE call_id=$1 ORDER BY version',[pair.call.id])).rows;
  const events=await h.request('events',pair.customer),valid=await validator('Event');
  assert.equal(events.status,200);
  const own=events.body.items.filter((e:any)=>e.entityId===pair.call.id);assert.equal(own.length,2);
  for(const event of own){
    assert.equal(Object.hasOwn(event.data,'durationLimitReason'),false);assert.equal(valid(event),true,JSON.stringify(valid.errors));
  }
  const history=await h.request('calls',pair.customer);
  assert.equal(history.body.items.find((c:any)=>c.id===pair.call.id).durationLimitReason,'test_duration_cap');
  assert.deepEqual((await h.db.pool.query('SELECT id,payload::text payload FROM call_events WHERE call_id=$1 ORDER BY version',[pair.call.id])).rows,before);
});
