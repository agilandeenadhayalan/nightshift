import {after,before,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {copyFile,mkdtemp,readdir,rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {TEST_RATE,TEST_VIDEO_RATE} from '@nightshift/backend-domain';
import {Database} from '../src/db';
import {migrate} from '../src/migrate';
import {seed} from '../src/seed';

const migrationDirectory=path.resolve(__dirname,'../../../../db/migrations');
let admin:Database,baseUrl:URL,priorDirectory:string;
before(async()=>{
  assert.equal(process.env.NODE_ENV,'test');assert.ok(process.env.TEST_DATABASE_URL);
  baseUrl=new URL(process.env.TEST_DATABASE_URL);
  assert.ok(['localhost','127.0.0.1','::1'].includes(baseUrl.hostname));
  assert.match(decodeURIComponent(baseUrl.pathname.slice(1)),/^[a-z0-9_]+_test$/);
  admin=new Database(baseUrl.toString());
  priorDirectory=await mkdtemp(path.join(os.tmpdir(),'nightshift-rate-prior-'));
  for(const name of(await readdir(migrationDirectory)).filter(name=>/^\d{3}_.+\.sql$/.test(name)&&Number(name.slice(0,3))<=17)){
    await copyFile(path.join(migrationDirectory,name),path.join(priorDirectory,name));
  }
});
after(async()=>{
  if(admin)await admin.close();
  if(priorDirectory){
    assert.equal(path.dirname(path.resolve(priorDirectory)),path.resolve(os.tmpdir()));
    assert.ok(path.basename(priorDirectory).startsWith('nightshift-rate-prior-'));
    await rm(priorDirectory,{recursive:true,force:true});
  }
});
async function isolated<T>(run:(db:Database,url:URL)=>Promise<T>,prior=false){
  const schema=`rates_${randomUUID().replaceAll('-','')}`;
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  const url=new URL(baseUrl);url.searchParams.set('options',`-csearch_path=${schema}`);
  const db=new Database(url.toString());
  try{await migrate(db,prior?priorDirectory:migrationDirectory);return await run(db,url);}
  finally{await db.close();await admin.pool.query(`DROP SCHEMA ${schema} CASCADE`);}
}
async function insertRate(db:Database,rate=TEST_RATE,policy:unknown=rate){
  await db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[rate.id,policy]);
}
async function snapshot(db:Database){
  const result:Record<string,unknown>={};
  for(const table of ['rate_versions','users','wallet_accounts','journal_batches','journal_lines','listener_reviews','call_sessions','call_events','outbox_events']){
    // Compare the original financial fields across future metadata-only migrations.
    const record=table==='journal_batches'?"to_jsonb(t)-'sealed'":table==='users'?"to_jsonb(t)-'audio_enabled'-'video_enabled'":'to_jsonb(t)';
    result[table]=(await db.pool.query(`SELECT ${record} AS record FROM ${table} t ORDER BY id`)).rows;
  }
  return result;
}
function conflict(error:unknown){
  assert.equal((error as {code?:string}).code,'RATE_VERSION_CONFLICT');
  assert.equal((error as Error).message,'RATE_VERSION_CONFLICT');
  assert.ok(!String(error).includes('private-fixture-marker'));return true;
}

test('a persisted rate policy cannot be changed behind its version ID',async()=>isolated(async db=>{
  await insertRate(db);const before=await snapshot(db);
  await assert.rejects(db.pool.query("UPDATE rate_versions SET policy=jsonb_set(policy,'{coinsPerMinute}','1') WHERE id=$1",[TEST_RATE.id]),{code:'23514'});
  assert.deepEqual(await snapshot(db),before);
}));

test('seeding rejects existing bundled-rate drift before creating any fixture',async()=>isolated(async db=>{
  await insertRate(db,TEST_RATE,{...TEST_RATE,coinsPerMinute:1,marker:'private-fixture-marker'});
  const before=await snapshot(db);await assert.rejects(seed(db),conflict);assert.deepEqual(await snapshot(db),before);
}));

test('version identity timestamp and policy changes are rejected while semantic no-op updates are allowed',async()=>isolated(async db=>{
  await insertRate(db);const before=await snapshot(db);
  for(const statement of [
    "UPDATE rate_versions SET id='replacement-version' WHERE id=$1",
    "UPDATE rate_versions SET created_at=created_at+interval '1 microsecond' WHERE id=$1",
    'UPDATE rate_versions SET test_only=false WHERE id=$1',
  ])await assert.rejects(db.pool.query(statement,[TEST_RATE.id]),{code:'23514'});
  const reordered=Object.fromEntries(Object.entries(TEST_RATE).reverse());
  const result=await db.pool.query(`UPDATE rate_versions SET id=id,policy=jsonb_set($2::jsonb,'{coinsPerMinute}','60.0'),
    test_only=test_only,created_at=created_at WHERE id=$1 RETURNING id`,[TEST_RATE.id,reordered]);
  assert.equal(result.rowCount,1);assert.deepEqual(await snapshot(db),before);
}));

async function historyFixture(db:Database){
  await seed(db);
  const users=(await db.pool.query('SELECT id,test_handle FROM users')).rows;
  const customer=users.find(row=>row.test_handle==='customer')!.id,listener=users.find(row=>row.test_handle==='listener')!.id;
  const call=randomUUID(),event=randomUUID();
  await db.pool.query(`INSERT INTO call_sessions(id,customer_id,listener_id,state,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at,ended_at,reason)
    VALUES($1,$2,$3,'ended',$4,$5,600,'2026-11-21T10:00:00.123456Z','2026-11-21T10:00:30.123456Z','2026-11-21T10:00:31.123456Z','timeout')`,
    [call,customer,listener,TEST_RATE.id,TEST_RATE]);
  await db.pool.query("INSERT INTO call_events(id,call_id,version,kind,payload,created_at) VALUES($1,$2,1,'call.state_changed',$3,'2026-11-21T10:00:31.123456Z')",[event,call,{id:call,state:'ended',rate:TEST_RATE}]);
  await db.pool.query('INSERT INTO outbox_events(id,event_id,recipient_id) VALUES($1,$2,$3)',[randomUUID(),event,listener]);
}

test('unused deletion and cascading truncation cannot erase versions or referenced financial history',async()=>isolated(async db=>{
  await historyFixture(db);const before=await snapshot(db);
  await assert.rejects(db.pool.query('DELETE FROM rate_versions WHERE id=$1',[TEST_VIDEO_RATE.id]),{code:'23514'});
  // Plain TRUNCATE can fail on foreign keys without reaching our trigger.
  // CASCADE is confined to this unique schema and proves the statement guard.
  await assert.rejects(db.pool.query('TRUNCATE rate_versions CASCADE'),{code:'23514'});
  assert.deepEqual(await snapshot(db),before);
}));

test('new test-only versions can be inserted without changing earlier rates or call snapshots',async()=>isolated(async db=>{
  await historyFixture(db);const before=await snapshot(db),id=`synthetic-rate-${randomUUID()}`;
  await db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[id,{...TEST_RATE,id}]);
  await assert.rejects(db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,false)',[`${id}-live`,{...TEST_RATE,id:`${id}-live`}]),{code:'23514'});
  const after=await snapshot(db);assert.equal((after.rate_versions as unknown[]).length,3);
  after.rate_versions=(after.rate_versions as Array<{record:{id:string}}>).filter(row=>row.record.id!==id);
  assert.deepEqual(after,before);
}));

test('unchanged seeding is idempotent and accepts JSONB-equivalent key ordering',async()=>isolated(async db=>{
  await insertRate(db,TEST_RATE,Object.fromEntries(Object.entries(TEST_RATE).reverse()));
  await seed(db);const before=await snapshot(db);
  await seed(db);await seed(db);assert.deepEqual(await snapshot(db),before);
  assert.equal((before.rate_versions as unknown[]).length,2);assert.equal((before.users as unknown[]).length,3);
  assert.equal((before.journal_batches as unknown[]).length,3);assert.equal((before.listener_reviews as unknown[]).length,1);
}));

test('a second-rate conflict rolls back the first missing rate and all fixture writes',async()=>isolated(async db=>{
  await insertRate(db,TEST_VIDEO_RATE,{...TEST_VIDEO_RATE,microcreditsPerSecond:1,marker:'private-fixture-marker'});
  const before=await snapshot(db);await assert.rejects(seed(db),conflict);assert.deepEqual(await snapshot(db),before);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM rate_versions WHERE id=$1',[TEST_RATE.id])).rows[0].count,0);
}));

test('concurrent seeds create one consistent pair of versions and one set of fixture grants',async()=>isolated(async db=>{
  await Promise.all(Array.from({length:8},()=>seed(db)));const before=await snapshot(db);
  assert.equal((before.rate_versions as unknown[]).length,2);assert.equal((before.users as unknown[]).length,3);
  assert.equal((before.journal_batches as unknown[]).length,3);assert.equal((before.journal_lines as unknown[]).length,6);
  assert.equal((before.listener_reviews as unknown[]).length,1);
  await seed(db);assert.deepEqual(await snapshot(db),before);
}));

test('a conflicting insert committed while seeding waits is checked before any grant',async()=>isolated(async(db,url)=>{
  const writer=await db.pool.connect(),workerUrl=new URL(url),name=`rate-seed-${randomUUID()}`;
  workerUrl.searchParams.set('application_name',name);const worker=new Database(workerUrl.toString());
  let outcome:Promise<{ok:boolean;error?:unknown}>|undefined,committed=false;
  try{
    await writer.query('BEGIN');const pid=(await writer.query('SELECT pg_backend_pid() AS pid')).rows[0].pid;
    await writer.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[TEST_VIDEO_RATE.id,{...TEST_VIDEO_RATE,marker:'private-fixture-marker'}]);
    outcome=seed(worker).then(()=>({ok:true}),error=>({ok:false,error}));
    let blocked=false;const deadline=Date.now()+5000;
    do{
      blocked=(await db.pool.query('SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name=$1 AND $2::int=ANY(pg_blocking_pids(pid))) AS blocked',[name,pid])).rows[0].blocked;
      if(blocked)break;await new Promise<void>(resolve=>setTimeout(resolve,10));
    }while(Date.now()<deadline);
    assert.equal(blocked,true,'The seed must actually wait on the competing uncommitted insert');
    await writer.query('COMMIT');committed=true;
    const result=await outcome;assert.equal(result.ok,false);conflict(result.error);
    const rows=await snapshot(db);
    assert.equal((rows.rate_versions as unknown[]).length,1);assert.equal((rows.users as unknown[]).length,0);
    assert.equal((rows.wallet_accounts as unknown[]).length,0);assert.equal((rows.journal_batches as unknown[]).length,0);
    assert.equal((await db.pool.query('SELECT policy FROM rate_versions WHERE id=$1',[TEST_VIDEO_RATE.id])).rows[0].policy.marker,'private-fixture-marker');
  }finally{
    if(!committed)await writer.query('ROLLBACK');writer.release();if(outcome)await outcome;await worker.close();
  }
}));

for(const conflicting of [false,true])test(`forward upgrade preserves ${conflicting?'conflicting':'valid'} rates and exact call journal outbox records`,async()=>isolated(async db=>{
  await historyFixture(db);
  if(conflicting)await db.pool.query("UPDATE rate_versions SET policy=policy||'{\"marker\":\"private-fixture-marker\"}'::jsonb WHERE id=$1",[TEST_RATE.id]);
  const before=await snapshot(db),checksums=(await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name')).rows;
  assert.equal(checksums.length,17);
  await migrate(db);await migrate(db);assert.deepEqual(await snapshot(db),before);
  assert.deepEqual((await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name LIMIT 17')).rows,checksums);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM schema_migrations')).rows[0].count,21);
  if(conflicting)await assert.rejects(seed(db),conflict);else await seed(db);
  assert.deepEqual(await snapshot(db),before);
  await assert.rejects(db.pool.query("UPDATE rate_versions SET policy='{}'::jsonb WHERE id=$1",[TEST_RATE.id]),{code:'23514'});
},true));
