import {after,before,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {copyFile,mkdtemp,readdir,rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {TEST_RATE} from '@nightshift/backend-domain';
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
  priorDirectory=await mkdtemp(path.join(os.tmpdir(),'nightshift-journal-prior-'));
  for(const name of(await readdir(migrationDirectory)).filter(name=>/^\d{3}_.+\.sql$/.test(name)&&Number(name.slice(0,3))<=18)){
    await copyFile(path.join(migrationDirectory,name),path.join(priorDirectory,name));
  }
});
after(async()=>{
  if(admin)await admin.close();
  if(priorDirectory){
    assert.equal(path.dirname(path.resolve(priorDirectory)),path.resolve(os.tmpdir()));
    assert.ok(path.basename(priorDirectory).startsWith('nightshift-journal-prior-'));
    await rm(priorDirectory,{recursive:true,force:true});
  }
});
async function isolated<T>(run:(db:Database,url:URL)=>Promise<T>,prior=false){
  const schema=`journal_${randomUUID().replaceAll('-','')}`;
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  const url=new URL(baseUrl);url.searchParams.set('options',`-csearch_path=${schema}`);
  const db=new Database(url.toString());
  try{await migrate(db,prior?priorDirectory:migrationDirectory);return await run(db,url);}
  finally{await db.close();await admin.pool.query(`DROP SCHEMA ${schema} CASCADE`);}
}
async function accounts(db:Database){
  await db.pool.query(`INSERT INTO wallet_accounts(id,unit,kind) VALUES
    ('credit:a','TEST_MICROCREDIT','platform_test'),('credit:b','TEST_MICROCREDIT','platform_test'),
    ('credit:c','TEST_MICROCREDIT','platform_test'),('credit:d','TEST_MICROCREDIT','platform_test'),
    ('earning:a','TEST_PAISE','listener_test'),('earning:b','TEST_PAISE','subsidy_test')`);
}
async function post(db:Database,id='original'){
  await db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'synthetic_test_posting')",[id]);
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,'credit:a',100),($1,'credit:b',-100)",[id]);
  });
}
async function journalSnapshot(db:Database){
  return {
    accounts:(await db.pool.query('SELECT * FROM wallet_accounts ORDER BY id')).rows,
    batches:(await db.pool.query('SELECT id,call_id,kind,created_at::text FROM journal_batches ORDER BY id')).rows,
    lines:(await db.pool.query('SELECT * FROM journal_lines ORDER BY id')).rows,
    totals:(await db.pool.query(`SELECT a.unit,sum(l.amount)::text AS amount FROM journal_lines l
      JOIN wallet_accounts a ON a.id=l.account_id GROUP BY a.unit ORDER BY a.unit`)).rows,
  };
}

test('a committed batch cannot acquire a later balanced pair of journal lines',async()=>isolated(async db=>{
  await accounts(db);await post(db);const before=await journalSnapshot(db);
  await assert.rejects(db.tx(async c=>{
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('original','credit:c',7),('original','credit:d',-7)");
  }),{code:'23514'});
  assert.deepEqual(await journalSnapshot(db),before);
}));

test('a posted wallet account cannot be reclassified into another unit',async()=>isolated(async db=>{
  await accounts(db);await post(db);const before=await journalSnapshot(db);
  await assert.rejects(db.pool.query("UPDATE wallet_accounts SET unit='TEST_PAISE' WHERE id='credit:a'"),{code:'23514'});
  assert.deepEqual(await journalSnapshot(db),before);
}));

test('account identity owner and kind cannot change or be deleted while semantic no-op updates and new accounts remain valid',async()=>isolated(async db=>{
  await accounts(db);const owner=randomUUID(),other=randomUUID();
  await db.pool.query("INSERT INTO users(id,display_name) VALUES($1,'Synthetic owner'),($2,'Synthetic other')",[owner,other]);
  await db.pool.query("INSERT INTO wallet_accounts(id,user_id,unit,kind) VALUES('unused',$1,'TEST_MICROCREDIT','customer_test')",[owner]);
  const before=await journalSnapshot(db);
  for(const query of [
    "UPDATE wallet_accounts SET id='replacement' WHERE id='unused'",
    "UPDATE wallet_accounts SET user_id=NULL WHERE id='unused'",
    `UPDATE wallet_accounts SET user_id='${other}' WHERE id='unused'`,
    "UPDATE wallet_accounts SET kind='platform_test' WHERE id='unused'",
    "DELETE FROM wallet_accounts WHERE id='unused'",
  ])await assert.rejects(db.pool.query(query),{code:'23514'});
  const result=await db.pool.query('UPDATE wallet_accounts SET id=id,user_id=user_id,unit=unit,kind=kind RETURNING id');
  assert.equal(result.rowCount,7);assert.deepEqual(await journalSnapshot(db),before);
  await db.pool.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES('new-test-account','TEST_PAISE','subsidy_test')");
  await assert.rejects(db.pool.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES('real-money','INR','platform_test')"),{code:'23514'});
}));

test('same-transaction multi-statement postings and savepoint-created batches seal only after complete balanced posting',async()=>isolated(async db=>{
  await accounts(db);
  await db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('outer','synthetic_test_posting')");
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('outer','credit:a',25)");
    await c.query('SAVEPOINT inner_posting');
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('inner','synthetic_test_posting')");
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('inner','earning:a',3)");
    await c.query('RELEASE SAVEPOINT inner_posting');
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('outer','credit:b',-25),('inner','earning:b',-3)");
    await c.query('SAVEPOINT discarded_posting');
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('discarded','synthetic_test_posting')");
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('discarded','credit:c',99)");
    await c.query('ROLLBACK TO SAVEPOINT discarded_posting');
    assert.deepEqual((await c.query('SELECT id,sealed FROM journal_batches ORDER BY id')).rows,[{id:'inner',sealed:false},{id:'outer',sealed:false}]);
  });
  assert.deepEqual((await db.pool.query('SELECT id,sealed FROM journal_batches ORDER BY id')).rows,[{id:'inner',sealed:true},{id:'outer',sealed:true}]);
  assert.deepEqual((await journalSnapshot(db)).totals,[{unit:'TEST_MICROCREDIT',amount:'0'},{unit:'TEST_PAISE',amount:'0'}]);
}));

test('caller-supplied seal values cannot bypass creation validation or leave a committed batch open',async()=>isolated(async db=>{
  await accounts(db);
  for(const supplied of [true,false,null]){
    const id=`supplied-${supplied}`;
    await db.tx(async c=>{
      const inserted=await c.query("INSERT INTO journal_batches(id,kind,sealed) VALUES($1,'synthetic_test_posting',$2) RETURNING sealed",[id,supplied]);
      assert.deepEqual(inserted.rows,[{sealed:false}]);
      await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,'credit:a',1),($1,'credit:b',-1)",[id]);
    });
    assert.equal((await db.pool.query('SELECT sealed FROM journal_batches WHERE id=$1',[id])).rows[0].sealed,true);
  }
  await assert.rejects(db.pool.query("INSERT INTO journal_batches(id,kind,sealed) VALUES('empty-spoof','synthetic_test_posting',true)"),{code:'23514'});
  await assert.rejects(db.pool.query("UPDATE journal_batches SET sealed=false WHERE id='supplied-true'"),{code:'23514'});
  assert.equal((await db.pool.query("SELECT count(*)::int count FROM journal_batches WHERE sealed=false OR id='empty-spoof'")).rows[0].count,0);
}));

test('empty or individually unbalanced books fail at commit and roll back every batch in the transaction',async()=>isolated(async db=>{
  await accounts(db);const before=await journalSnapshot(db);
  await assert.rejects(db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('valid','synthetic_test_posting'),('empty','synthetic_test_posting')");
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('valid','credit:a',1),('valid','credit:b',-1)");
  }),{code:'23514'});
  assert.deepEqual(await journalSnapshot(db),before);
  await assert.rejects(db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('mixed-invalid','synthetic_test_posting')");
    // The cross-unit total is zero, but neither unit balances independently.
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('mixed-invalid','credit:a',1),('mixed-invalid','earning:b',-1)");
  }),/Unbalanced journal/);
  assert.deepEqual(await journalSnapshot(db),before);
}));

test('an explicit early seal closes further inserts without skipping deferred nonempty and balance checks',async()=>isolated(async db=>{
  await accounts(db);
  await db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('early','synthetic_test_posting')");
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('early','credit:a',2),('early','credit:b',-2)");
    await c.query("UPDATE journal_batches SET sealed=true WHERE id='early'");
    await c.query('SAVEPOINT later_append');
    await assert.rejects(c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('early','credit:c',3),('early','credit:d',-3)"),{code:'23514'});
    await c.query('ROLLBACK TO SAVEPOINT later_append');
  });
  for(const hasLine of [false,true])await assert.rejects(db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('invalid-early','synthetic_test_posting')");
    if(hasLine)await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('invalid-early','credit:a',2)");
    await c.query("UPDATE journal_batches SET sealed=true WHERE id='invalid-early'");
  }),{code:'23514'});
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM journal_batches')).rows[0].count,1);
}));

test('rolling back an early constraint check restores the open batch and still validates the final replacement posting',async()=>isolated(async db=>{
  await accounts(db);
  for(const replace of [false,true]){
    const operation=db.tx(async c=>{
      await c.query("INSERT INTO journal_batches(id,kind) VALUES('savepoint-seal','synthetic_test_posting')");
      await c.query('SAVEPOINT tentative_lines');
      await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('savepoint-seal','credit:a',2),('savepoint-seal','credit:b',-2)");
      await c.query('SET CONSTRAINTS ALL IMMEDIATE');
      assert.equal((await c.query("SELECT sealed FROM journal_batches WHERE id='savepoint-seal'")).rows[0].sealed,true);
      await c.query('ROLLBACK TO SAVEPOINT tentative_lines');
      assert.equal((await c.query("SELECT sealed FROM journal_batches WHERE id='savepoint-seal'")).rows[0].sealed,false);
      if(replace)await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('savepoint-seal','credit:c',3),('savepoint-seal','credit:d',-3)");
    });
    if(replace)await operation;else await assert.rejects(operation,{code:'23514'});
  }
  assert.deepEqual((await db.pool.query("SELECT account_id,amount::text FROM journal_lines WHERE batch_id='savepoint-seal' ORDER BY account_id")).rows,
    [{account_id:'credit:c',amount:'3'},{account_id:'credit:d',amount:'-3'}]);
}));

test('a failed posting rolls back its lines and batch and permits a corrected retry with the same new key',async()=>isolated(async db=>{
  await accounts(db);const before=await journalSnapshot(db);
  await assert.rejects(db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('retryable','synthetic_test_posting')");
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('retryable','credit:a',1),('retryable','credit:b',-1)");
    throw new Error('SYNTHETIC_AFTER_LINES_FAILURE');
  }),/SYNTHETIC_AFTER_LINES_FAILURE/);
  assert.deepEqual(await journalSnapshot(db),before);
  await post(db,'retryable');
  assert.equal((await db.pool.query("SELECT count(*)::int count FROM journal_lines WHERE batch_id='retryable'")).rows[0].count,2);
}));

test('committed journal records cannot be updated deleted or reopened and correction needs a separate batch',async()=>isolated(async db=>{
  await accounts(db);await post(db);const before=await journalSnapshot(db);
  for(const query of [
    "UPDATE journal_batches SET kind='replacement' WHERE id='original'",
    "UPDATE journal_batches SET created_at=created_at+interval '1 microsecond' WHERE id='original'",
    "UPDATE journal_batches SET sealed=false WHERE id='original'",
    "DELETE FROM journal_batches WHERE id='original'",
    "UPDATE journal_lines SET amount=amount+1 WHERE batch_id='original'",
    "DELETE FROM journal_lines WHERE batch_id='original'",
  ])await assert.rejects(db.pool.query(query),/append-only/);
  assert.deepEqual(await journalSnapshot(db),before);
  await db.tx(async c=>{
    await c.query("INSERT INTO journal_batches(id,kind) VALUES('separate-fixture','synthetic_test_posting')");
    await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('separate-fixture','credit:a',-100),('separate-fixture','credit:b',100)");
  });
  // This demonstrates a separate append, not an implemented reversal workflow.
  assert.deepEqual((await db.pool.query("SELECT * FROM journal_lines WHERE batch_id='original' ORDER BY id")).rows,before.lines);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM journal_batches WHERE sealed=true')).rows[0].count,2);
}));

test('direct and cascading truncation cannot erase accounts batches or lines',async()=>isolated(async db=>{
  await accounts(db);await post(db);const before=await journalSnapshot(db);
  // CASCADE reaches the statement guards rather than failing at a FK precheck.
  for(const table of ['journal_lines','journal_batches','wallet_accounts']){
    await assert.rejects(db.pool.query(`TRUNCATE ${table} CASCADE`),{code:'23514'});
    assert.deepEqual(await journalSnapshot(db),before);
  }
}));

test('a different transaction cannot post into an uncommitted batch or into it after commit',async()=>isolated(async db=>{
  await accounts(db);const writer=await db.pool.connect();let committed=false;
  try{
    await writer.query('BEGIN');
    await writer.query("INSERT INTO journal_batches(id,kind) VALUES('private-uncommitted','synthetic_test_posting')");
    await writer.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('private-uncommitted','credit:a',1),('private-uncommitted','credit:b',-1)");
    const append=()=>db.pool.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('private-uncommitted','credit:c',2),('private-uncommitted','credit:d',-2)");
    await assert.rejects(append(),{code:'23514'});
    await writer.query('COMMIT');committed=true;
    await assert.rejects(append(),{code:'23514'});
    assert.equal((await db.pool.query('SELECT count(*)::int count FROM journal_lines')).rows[0].count,2);
  }finally{if(!committed)await writer.query('ROLLBACK');writer.release();}
}));

test('a same-key insert waiting for the creating transaction cannot reopen its committed batch',async()=>isolated(async(db,url)=>{
  await accounts(db);const writer=await db.pool.connect(),workerUrl=new URL(url),name=`journal-contender-${randomUUID()}`;
  workerUrl.searchParams.set('application_name',name);const worker=new Database(workerUrl.toString());
  let committed=false,outcome:Promise<{ok:boolean;error?:unknown}>|undefined;
  try{
    await writer.query('BEGIN');const pid=(await writer.query('SELECT pg_backend_pid() AS pid')).rows[0].pid;
    await writer.query("INSERT INTO journal_batches(id,kind) VALUES('same-key','synthetic_test_posting')");
    await writer.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('same-key','credit:a',1),('same-key','credit:b',-1)");
    outcome=worker.tx(async c=>{
      await c.query("INSERT INTO journal_batches(id,kind,sealed) VALUES('same-key','synthetic_test_posting',false) ON CONFLICT DO NOTHING");
      await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES('same-key','credit:c',2),('same-key','credit:d',-2)");
    }).then(()=>({ok:true}),error=>({ok:false,error}));
    let blocked=false;const deadline=Date.now()+5000;
    do{
      blocked=(await db.pool.query('SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name=$1 AND $2::int=ANY(pg_blocking_pids(pid))) AS blocked',[name,pid])).rows[0].blocked;
      if(blocked)break;await new Promise<void>(resolve=>setTimeout(resolve,10));
    }while(Date.now()<deadline);
    assert.equal(blocked,true,'The contender must actually wait for the creating transaction');
    await writer.query('COMMIT');committed=true;
    const result=await outcome;assert.equal(result.ok,false);assert.equal((result.error as {code?:string}).code,'23514');
    assert.equal((await db.pool.query('SELECT count(*)::int count FROM journal_lines')).rows[0].count,2);
  }finally{if(!committed)await writer.query('ROLLBACK');writer.release();if(outcome)await outcome;await worker.close();}
}));

test('existing seeding remains atomic and idempotent without reopening closed grants',async()=>isolated(async db=>{
  await Promise.all([seed(db),seed(db),seed(db)]);const before=await journalSnapshot(db);
  assert.equal(before.batches.length,3);assert.equal(before.lines.length,6);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM journal_batches WHERE sealed=true')).rows[0].count,3);
  await seed(db);assert.deepEqual(await journalSnapshot(db),before);
}));

for(const anomalous of [false,true])test(`forward upgrade closes and exactly preserves ${anomalous?'legacy anomalous':'valid'} history without repair`,async()=>isolated(async db=>{
  await seed(db);const users=(await db.pool.query('SELECT id,test_handle FROM users')).rows;
  const customer=users.find(row=>row.test_handle==='customer')!.id,listener=users.find(row=>row.test_handle==='listener')!.id;
  const call=randomUUID(),event=randomUUID();
  await db.pool.query(`INSERT INTO call_sessions(id,customer_id,listener_id,state,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at,ended_at,reason)
    VALUES($1,$2,$3,'ended',$4,$5,600,'2026-11-21T10:00:00.123456Z','2026-11-21T10:00:30.123456Z','2026-11-21T10:00:31.123456Z','timeout')`,[call,customer,listener,TEST_RATE.id,TEST_RATE]);
  await db.pool.query("INSERT INTO call_events(id,call_id,version,kind,payload,created_at) VALUES($1,$2,1,'call.state_changed',$3,'2026-11-21T10:00:31.123456Z')",[event,call,{id:call,state:'ended'}]);
  await db.pool.query('INSERT INTO outbox_events(id,event_id,recipient_id) VALUES($1,$2,$3)',[randomUUID(),event,listener]);
  if(anomalous){
    await db.pool.query("INSERT INTO journal_batches(id,kind) VALUES('legacy-empty','legacy_test_fixture')");
    await db.pool.query("UPDATE wallet_accounts SET unit='TEST_PAISE' WHERE id=$1",[`customer:${customer}`]);
  }
  const before=await journalSnapshot(db),history=(await db.pool.query(`SELECT (SELECT jsonb_agg(to_jsonb(c)) FROM call_sessions c) AS calls,
    (SELECT jsonb_agg(to_jsonb(e)) FROM call_events e) AS events,(SELECT jsonb_agg(to_jsonb(o)) FROM outbox_events o) AS outbox`)).rows;
  const checksums=(await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name')).rows;
  assert.equal(checksums.length,18);await migrate(db);await migrate(db);
  assert.deepEqual(await journalSnapshot(db),before);
  assert.deepEqual((await db.pool.query(`SELECT (SELECT jsonb_agg(to_jsonb(c)) FROM call_sessions c) AS calls,
    (SELECT jsonb_agg(to_jsonb(e)) FROM call_events e) AS events,(SELECT jsonb_agg(to_jsonb(o)) FROM outbox_events o) AS outbox`)).rows,history);
  assert.deepEqual((await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name LIMIT 18')).rows,checksums);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM schema_migrations')).rows[0].count,21);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM journal_batches WHERE sealed=true')).rows[0].count,before.batches.length);
  await db.pool.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES('future:a','TEST_MICROCREDIT','platform_test'),('future:b','TEST_MICROCREDIT','platform_test')");
  await assert.rejects(db.pool.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,'future:a',1),($1,'future:b',-1)",[before.batches[0].id]),{code:'23514'});
},true));
