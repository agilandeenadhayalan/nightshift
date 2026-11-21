import {after,before,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import {TEST_RATE} from '@nightshift/backend-domain';
import {MatchingFixture,MatchingParticipant} from './matching-fixture';

const h=new MatchingFixture();
let validPage:ReturnType<Ajv['compile']>;
before(async()=>{
  await h.open();
  const contract=JSON.parse(await readFile(path.resolve(__dirname,'../../../../packages/contracts/openapi.json'),'utf8'));
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  validPage=ajv.compile({$defs:definitions,$ref:'#/$defs/CallPage'});
});
after(()=>h.close());

async function pair(){return{customer:await h.participant(),listener:await h.participant(true)};}
type Pair=Awaited<ReturnType<typeof pair>>;
/** Failed completed calls are synthetic read fixtures, not simulated provider
 * evidence. Timestamp text goes directly to PostgreSQL: using JS Date here
 * would erase the very precision the pagination regression must exercise. */
async function failedCalls(people:Pair,timestamps:string[],ids:string[]=timestamps.map(()=>randomUUID())){
  assert.equal(ids.length,timestamps.length);
  await h.db.pool.query(`INSERT INTO call_sessions
    (id,customer_id,listener_id,state,version,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at,ended_at,reason)
    SELECT id,$1,$2,'ended',2,$3,$4,600,stamp::timestamptz,stamp::timestamptz+interval '30 seconds',
      stamp::timestamptz+interval '31 seconds','timeout'
    FROM unnest($5::uuid[],$6::text[]) AS fixture(id,stamp)`,
    [people.customer.id,people.listener.id,TEST_RATE.id,TEST_RATE,ids,timestamps]);
  return ids;
}
async function orderedIds(owner:MatchingParticipant){
  return(await h.db.pool.query('SELECT id FROM call_sessions WHERE customer_id=$1 OR listener_id=$1 ORDER BY created_at DESC,id DESC',[owner.id])).rows.map(row=>row.id as string);
}
async function httpPage(owner:MatchingParticipant,cursor?:string){
  const result=await h.request(`calls${cursor===undefined?'':`?cursor=${encodeURIComponent(cursor)}`}`,owner);
  assert.equal(result.status,200);assert.equal(validPage(result.body),true,JSON.stringify(validPage.errors));
  assert.ok(result.body.items.length<=20);
  return result.body as {items:Array<{id:string;createdAt:string;state:string;reason:string|null;connectedMs:number;chargeMicrocredits:number;earningPaise:number}>;nextCursor:string|null};
}
async function allPages(owner:MatchingParticipant){
  const ids:string[]=[],sizes:number[]=[],times:string[]=[];let cursor:string|undefined;
  for(let page=0;page<20;page++){
    const result=await httpPage(owner,cursor);sizes.push(result.items.length);
    ids.push(...result.items.map(item=>item.id));times.push(...result.items.map(item=>item.createdAt));
    if(result.nextCursor===null)return{ids,sizes,times};
    assert.equal(result.nextCursor,result.items.at(-1)?.id,'Cursor is the last returned stable session ID');
    assert.notEqual(result.nextCursor,cursor,'Continuation must advance');cursor=result.nextCursor;
  }
  assert.fail('Bounded history fixture must finish paging');
}

test('microsecond call timestamps survive HTTP cursor boundaries without skipped or duplicated sessions',async()=>{
  const people=await pair();
  await failedCalls(people,Array.from({length:45},(_,i)=>`2026-11-20T12:00:00.${123010+i*10}Z`));
  const precision=(await h.db.pool.query("SELECT count(DISTINCT created_at)::int exact,count(DISTINCT date_trunc('milliseconds',created_at))::int rounded FROM call_sessions WHERE customer_id=$1",[people.customer.id])).rows[0];
  assert.deepEqual(precision,{exact:45,rounded:1});
  const expected=await orderedIds(people.customer);
  for(const owner of [people.customer,people.listener]){
    const result=await allPages(owner);
    assert.deepEqual(result.ids,expected);assert.equal(new Set(result.ids).size,45);
    assert.deepEqual(result.sizes,[20,20,5]);assert.equal(new Set(result.times).size,1,'Public millisecond timestamps are not the cursor authority');
  }
});

test('identical full-precision timestamps use descending UUID ties across every page',async()=>{
  const people=await pair(),ids=Array.from({length:45},()=>randomUUID()).sort();
  // Deliberately insert in the opposite order to the required UUID tie-breaker.
  await failedCalls(people,ids.map(()=>'2026-11-20T12:00:00.123456Z'),ids);
  const result=await allPages(people.listener);
  assert.deepEqual(result.ids,[...ids].reverse());assert.deepEqual(result.sizes,[20,20,5]);
});

test('empty and exact-boundary histories retain the twenty-row limit and terminate correctly',async()=>{
  for(const count of [0,1,20,21,40,41]){
    const people=await pair();await failedCalls(people,Array.from({length:count},()=> '2026-11-20T12:00:00.000Z'));
    const result=await allPages(people.customer),expected=await orderedIds(people.customer);
    assert.deepEqual(result.ids,expected);assert.equal(new Set(result.ids).size,count);
    const sizes=count===0?[0]:Array.from({length:Math.ceil(count/20)},(_,i)=>Math.min(20,count-i*20));
    assert.deepEqual(result.sizes,sizes);
  }
});

test('a large valid history combines both participant positions without including other accounts',async()=>{
  const owner=await h.participant(),customerPeer=await h.participant(),listenerPeer=await h.participant(true),foreign=await pair();
  const stamps=Array.from({length:121},(_,i)=>new Date(Date.UTC(2026,10,20,12,0,i)).toISOString());
  await failedCalls({customer:owner,listener:listenerPeer},stamps.slice(0,61));
  await failedCalls({customer:customerPeer,listener:owner},stamps.slice(61));
  const foreignIds=await failedCalls(foreign,stamps);
  const result=await allPages(owner);
  assert.deepEqual(result.ids,await orderedIds(owner));assert.equal(new Set(result.ids).size,121);
  assert.deepEqual(result.sizes,[20,20,20,20,20,20,1]);assert.ok(result.ids.every(id=>!foreignIds.includes(id)));
});

test('history cursors and call details reject nonparticipants without disclosing whether the ID exists',async()=>{
  const people=await pair(),other=await pair();
  const [id]=await failedCalls(people,['2026-11-20T12:00:00.123456Z']);
  await failedCalls(other,['2026-11-20T12:00:00.999999Z']);
  for(const owner of [people.customer,people.listener]){
    const detail=await h.request(`calls/${id}`,owner);assert.equal(detail.status,200);assert.equal(detail.body.id,id);
    const tail=await httpPage(owner,id);assert.deepEqual(tail.items,[]);assert.equal(tail.nextCursor,null);
  }
  for(const foreignCursor of [id!,randomUUID()]){
    const cursor=await h.request(`calls?cursor=${foreignCursor}`,other.customer);
    const detail=await h.request(`calls/${foreignCursor}`,other.customer);
    for(const result of [cursor,detail]){assert.equal(result.status,404);assert.equal(result.body.error.code,'CALL_NOT_FOUND');assert.equal(result.body.items,undefined);}
  }
  assert.equal((await h.request('calls')).status,401);assert.equal((await h.request(`calls/${id}`)).status,401);
});

test('missing and empty cursors start history while malformed cursors fail before paging',async()=>{
  const people=await pair();await failedCalls(people,Array.from({length:21},()=> '2026-11-20T12:00:00.000Z'));
  assert.deepEqual(await httpPage(people.customer,''),await httpPage(people.customer));
  for(const cursor of ['not-a-uuid','00000000-0000-0000-0000-not-a-valid!','%']){
    const result=await h.request(`calls?cursor=${encodeURIComponent(cursor)}`,people.customer);
    assert.equal(result.status,400);assert.equal(result.body.error.code,'INVALID_ID');assert.equal(result.body.items,undefined);
  }
  const absent=await h.request(`calls?cursor=${randomUUID()}`,people.customer);
  assert.equal(absent.status,404);assert.equal(absent.body.error.code,'CALL_NOT_FOUND');
});

test('newer calls inserted after page one do not duplicate or displace its older continuation',async()=>{
  const people=await pair();await failedCalls(people,Array.from({length:41},(_,i)=>`2026-11-20T12:00:00.${123010+i*10}Z`));
  const expected=await orderedIds(people.customer),first=await httpPage(people.customer);assert.ok(first.nextCursor);
  const [newer]=await failedCalls(people,['2026-11-20T12:00:01.999999Z']);
  const second=await httpPage(people.customer,first.nextCursor);assert.ok(second.nextCursor);
  const third=await httpPage(people.customer,second.nextCursor);
  const combined=[...first.items,...second.items,...third.items].map(item=>item.id);
  assert.deepEqual(combined,expected);assert.equal(new Set(combined).size,41);assert.ok(!combined.includes(newer!));assert.equal(third.nextCursor,null);
  assert.equal((await httpPage(people.customer)).items[0]!.id,newer);
});

test('paging failed completed calls preserves zero charge, exact rows and financial effects',async()=>{
  const people=await pair();await failedCalls(people,Array.from({length:21},()=> '2026-11-20T12:00:00.123456Z'));
  const snapshot=async()=>(await h.db.pool.query(`SELECT
    (SELECT jsonb_agg(to_jsonb(c) ORDER BY id) FROM call_sessions c WHERE customer_id=$1) calls,
    (SELECT count(*)::int FROM journal_batches) batches,(SELECT count(*)::int FROM journal_lines) lines,
    (SELECT count(*)::int FROM spend_holds) holds,(SELECT count(*)::int FROM active_participant_claims) claims,
    (SELECT count(*)::int FROM call_events) events,(SELECT count(*)::int FROM outbox_events) outbox`,[people.customer.id])).rows[0];
  const before=await snapshot(),first=await httpPage(people.listener),second=await httpPage(people.listener,first.nextCursor!);
  assert.equal(first.items.length+second.items.length,21);
  for(const call of [...first.items,...second.items]){
    assert.equal(call.state,'ended');assert.equal(call.reason,'timeout');assert.equal(call.connectedMs,0);
    assert.equal(call.chargeMicrocredits,0);assert.equal(call.earningPaise,0);
  }
  assert.deepEqual(await snapshot(),before);
});
