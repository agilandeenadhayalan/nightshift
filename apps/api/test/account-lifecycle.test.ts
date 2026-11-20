import 'reflect-metadata';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { Actor, tokenHash } from '../src/auth';
import { AccountLifecycle, DELETION_NOTICE_VERSION } from '../src/account-lifecycle';
import { ApiError } from '../src/errors';
import { TEST_RATE } from '@nightshift/backend-domain';
import { createApplication } from '../src/http';
import { Config } from '../src/config';
import { PhoneAuthDependencies } from '../src/identity/phone-auth';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';

// Synthetic actors below deliberately model the trusted guard at this service
// boundary. No HTTP path accepts authTime or actor IDs from a client body.
const schema = `lifecycle_${randomUUID().replaceAll('-', '')}`;
const now = Date.now();
let db: Database, admin: Database, lifecycle: AccountLifecycle;
let databaseUrl: string, runtime: Awaited<ReturnType<typeof createApplication>> | undefined, base: string;
const priorEnvironment = process.env.NODE_ENV;
const providerIdentities = new Map<string,{uid:string;authTime:number}>();
const withdrawn: string[] = [];
const secret = () => randomBytes(32).toString('hex');
const submission = (receiptToken = secret()) => ({ noticeVersion: DELETION_NOTICE_VERSION, confirm: true, receiptToken });
const code = (expected: string) => (error: unknown) => error instanceof ApiError && error.code === expected;

before(async () => {
  process.env.NODE_ENV = 'test';
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a dedicated test database');
  const url = new URL(process.env.TEST_DATABASE_URL!);
  admin = new Database(url.toString()); await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  databaseUrl = url.toString(); db = new Database(databaseUrl); await migrate(db);
  await db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)', [TEST_RATE.id, TEST_RATE]);
  await db.pool.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES('platform:test','TEST_MICROCREDIT','platform_test'),('subsidy:test','TEST_PAISE','subsidy_test')");
  lifecycle = new AccountLifecycle(db, () => now, async id => { withdrawn.push(id); });
});
after(async () => {
  if (runtime) await runtime.close();
  if (db) await db.close();
  if (admin) { await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.close(); }
  if (priorEnvironment === undefined) delete process.env.NODE_ENV; else process.env.NODE_ENV = priorEnvironment;
});

async function account(birth = '2000-01-01'): Promise<Actor> {
  const id = randomUUID(), sessionHash = secret(), device = randomUUID(), identity = randomUUID();
  const age = birth.startsWith('2015') ? false : true;
  await db.tx(async c => {
    await c.query("INSERT INTO users(id,display_name,adult_confirmed,listener_approved,mode,desired_online,languages) VALUES($1,'Public fixture',$2,true,'listener',true,ARRAY['ta'])", [id,age]);
    await c.query('INSERT INTO age_declarations(user_id,date_of_birth) VALUES($1,$2)', [id,birth]);
    await c.query("INSERT INTO profiles(user_id,date_of_birth,submitted_display_name,avatar_code,interface_language) VALUES($1,$2,'Private fixture name','moon','ta')", [id,birth]);
    await c.query("INSERT INTO consents(id,user_id,purpose,notice_version,granted) VALUES($1,$2,'adult_onboarding','adult-onboarding-v1',true)", [randomUUID(),id]);
    await c.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:msg91','lifecycle-fixture',$3)", [identity,id,secret()]);
    await c.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1", [identity]);
    await c.query("INSERT INTO devices(id,user_id,device_id,last_identity_issued_at,last_token_hash) VALUES($1,$2,'synthetic-phone',$3,$4)", [device,id,Math.floor(now/1000),sessionHash]);
    await c.query("INSERT INTO auth_sessions(token_hash,user_id,device_id,expires_at,auth_kind,device_record_id,identity_issued_at) VALUES($1,$2,'synthetic-phone',$3,'firebase',$4,$5)", [sessionHash,id,new Date(now+3600_000),device,Math.floor(now/1000)]);
  });
  return { id, sessionHash, identityAuthTime: Math.floor(now/1000) };
}
async function count(table: string, id: string) {
  return Number((await db.pool.query(`SELECT count(*) FROM ${table} WHERE user_id=$1`, [id])).rows[0].count);
}
async function ticket(actor: Actor) {
  const id = randomUUID();
  await db.pool.query("INSERT INTO support_tickets(id,actor_id,category,message) VALUES($1,$2,'privacy','Synthetic case; no real person')", [id,actor.id]);
  return id;
}
async function profileHold(actor: Actor, supportTicket = '') {
  const id = randomUUID(), supportId = supportTicket || await ticket(actor);
  await db.pool.query('INSERT INTO account_profile_evidence_holds(id,user_id,support_ticket_id) VALUES($1,$2,$3)', [id,actor.id,supportId]);
  return { id, supportId };
}
async function purchase(actor: Actor) {
  const id = randomUUID();
  await db.pool.query("INSERT INTO purchases(id,user_id,provider,purchase_token_digest,sku,amount_paise,credit_microcredits) VALUES($1,$2,'fixture',$3,'fixture-credits',1000,1000000)", [id,actor.id,secret()]);
  return id;
}
async function call(actor: Actor, state: 'ringing'|'ended' = 'ended', client = db.pool) {
  const peer = await account(), id = randomUUID();
  await client.query(`INSERT INTO call_sessions(id,customer_id,listener_id,state,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at,ended_at)
    VALUES($1,$2,$3,$4,$5,$6,60,$7,$8,$9)`, [id,actor.id,peer.id,state,TEST_RATE.id,TEST_RATE,new Date(now),new Date(now+30_000),state==='ended'?new Date(now):null]);
  return id;
}
async function ledger(actor: Actor) {
  const batch = `fixture:${randomUUID()}`;
  await db.tx(async c => {
    await c.query("INSERT INTO wallet_accounts(id,user_id,unit,kind) VALUES($1,$2,'TEST_MICROCREDIT','customer_test'),($3,$2,'TEST_PAISE','listener_test')", [`customer:${actor.id}`,actor.id,`listener:${actor.id}`]);
    await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'synthetic_grant')", [batch]);
    await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,1000000),($1,$3,-1000000),($1,$4,1180),($1,$5,-1180)', [batch,`customer:${actor.id}`,'platform:test',`listener:${actor.id}`,'subsidy:test']);
  });
  return batch;
}

test('versioned notice states test-credit, nonpayable earnings and unresolved retention effects', () => {
  const notice = lifecycle.deletionNotice();
  assert.equal(notice.noticeVersion, DELETION_NOTICE_VERSION);
  assert.equal(notice.retentionReviewRequired, true); assert.equal(notice.testOnly, true);
  assert.match(notice.text, /test credits become inaccessible/); assert.match(notice.text, /test earnings are nonpayable/);
  assert.match(notice.text, /no approved retention schedule/); assert.match(notice.text, /prevents sign-in or re-enrollment/);
});

test('consent history is owner-only, versioned and immutable', async () => {
  const owner = await account(), other = await account();
  const history = await lifecycle.consentHistory(owner);
  assert.equal(history.items.length,1); assert.equal(history.items[0]!.noticeVersion,'adult-onboarding-v1');
  assert.equal(history.items[0]!.granted,true); assert.ok(!JSON.stringify(history).includes(other.id));
  await assert.rejects(lifecycle.consentHistory({...owner,id:other.id}),code('UNAUTHENTICATED'));
  await assert.rejects(db.pool.query('UPDATE consents SET granted=false WHERE user_id=$1',[owner.id]),/append-only/);
  await assert.rejects(db.pool.query('DELETE FROM consents WHERE user_id=$1',[owner.id]),/append-only/);
});

test('reversible purpose preserves grant-withdraw-grant history while one-off consent stays idempotent', async () => {
  const owner = await account();
  for (const [index,granted] of [true,false,true].entries()) {
    await db.pool.query("INSERT INTO consents(id,user_id,purpose,notice_version,granted,created_at) VALUES($1,$2,'listener-review-material','listener-v1',$3,$4)",[randomUUID(),owner.id,granted,new Date(now+index)]);
  }
  const events = (await lifecycle.consentHistory(owner)).items.filter(x=>x.purpose==='listener-review-material');
  assert.deepEqual(events.map(x=>x.granted),[true,false,true]);
  for (let n=0;n<2;n++) await db.pool.query("INSERT INTO consents(id,user_id,purpose,notice_version,granted) VALUES($1,$2,'adult-service-onboarding','adult-onboarding-v1',true) ON CONFLICT DO NOTHING",[randomUUID(),owner.id]);
  assert.equal((await lifecycle.consentHistory(owner)).items.filter(x=>x.purpose==='adult-service-onboarding').length,1);
});

test('missing, stale, future and malformed step-up timestamps cannot delete', async () => {
  const owner = await account();
  for (const identityAuthTime of [undefined, Math.floor(now/1000)-301, Math.ceil(now/1000)+1, NaN, Infinity, -1, now/1000+0.5]) {
    await assert.rejects(lifecycle.requestDeletion({...owner,identityAuthTime},submission()),code('FRESH_SIGN_IN_REQUIRED'));
  }
  assert.equal(await count('deletion_requests',owner.id),0); assert.equal(await count('profiles',owner.id),1);
  const atBoundary = new AccountLifecycle(db,()=>Math.floor(now/1000)*1000);
  const result = await atBoundary.requestDeletion({...owner,identityAuthTime:Math.floor(now/1000)-300},submission());
  assert.equal(result.status,'review_required');
});

test('caller targeting, role, auth-time overrides, invalid notice and nonexplicit confirmation are rejected', async () => {
  const owner = await account(), other = await account();
  for (const injected of [{userId:other.id},{targetId:other.id},{role:'staff'},{identityAuthTime:Math.floor(now/1000)}]) {
    await assert.rejects(lifecycle.requestDeletion(owner,{...submission(),...injected}),code('INVALID_FIELD'));
  }
  await assert.rejects(lifecycle.requestDeletion(owner,{...submission(),noticeVersion:'old'}),code('NOTICE_OUTDATED'));
  await assert.rejects(lifecycle.requestDeletion(owner,{...submission(),confirm:'true'}),code('DELETION_CONFIRMATION_REQUIRED'));
  for (const receiptToken of [null, [], {}, 'x'.repeat(64), secret().toUpperCase(), 'abc']) {
    await assert.rejects(lifecycle.requestDeletion(owner,{...submission(),receiptToken}),code('INVALID_FIELD'));
  }
  await assert.rejects(lifecycle.requestDeletion({...owner,id:other.id},submission()),code('UNAUTHENTICATED'));
  await db.pool.query('UPDATE auth_sessions SET revoked_at=now() WHERE token_hash=$1',[owner.sessionHash]);
  await assert.rejects(lifecycle.requestDeletion(owner,submission()),code('UNAUTHENTICATED'));
  assert.equal(await count('deletion_requests',owner.id),0); assert.equal(await count('profiles',other.id),1);
});

test('active calls block deletion even when participant-claim recovery has not run', async () => {
  const owner = await account(), active = await call(owner,'ringing');
  await assert.rejects(lifecycle.requestDeletion(owner,submission()),code('CALL_ACTIVE'));
  assert.equal(await count('profiles',owner.id),1);
  await db.pool.query("UPDATE call_sessions SET state='ended',ended_at=$2 WHERE id=$1",[active,new Date(now)]);
  assert.equal((await lifecycle.requestDeletion(owner,submission())).status,'review_required');
});

test('accepted deletion revokes access and identity, purges private fields, retains consent and ledger exactly', async () => {
  const owner = await account(), request = submission(), batch = await ledger(owner);
  const before = (await db.pool.query('SELECT * FROM journal_lines WHERE batch_id=$1 ORDER BY id',[batch])).rows;
  const result = await lifecycle.requestDeletion(owner,request);
  assert.equal(result.status,'review_required'); assert.ok(result.personalDataDeletedAt); assert.deepEqual(result.holds,[]);
  for(const table of ['profiles','age_declarations','devices','auth_sessions']) assert.equal(await count(table,owner.id),0,table);
  const user = (await db.pool.query('SELECT * FROM users WHERE id=$1',[owner.id])).rows[0];
  assert.equal(user.suspended,true); assert.equal(user.desired_online,false); assert.equal(user.listener_approved,false);
  assert.equal(user.display_name,'Deleted account'); assert.equal(user.mode,'customer'); assert.deepEqual(user.languages,['en']);
  const binding = (await db.pool.query('SELECT * FROM auth_identities WHERE user_id=$1',[owner.id])).rows[0];
  assert.equal(binding.state,'revoked'); assert.ok(binding.revoked_at);
  await assert.rejects(db.pool.query("UPDATE auth_identities SET state='verified',revoked_at=NULL WHERE user_id=$1",[owner.id]),/transition|timestamp/);
  await assert.rejects(db.pool.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,$3,$4,$5)",[randomUUID(),owner.id,binding.provider,binding.issuer,binding.subject_digest]),/duplicate key/);
  assert.deepEqual((await db.pool.query('SELECT * FROM journal_lines WHERE batch_id=$1 ORDER BY id',[batch])).rows,before);
  assert.equal(await count('consents',owner.id),2); assert.ok(withdrawn.includes(owner.id));
  const stored = (await db.pool.query('SELECT * FROM deletion_requests WHERE user_id=$1',[owner.id])).rows[0];
  assert.notEqual(stored.receipt_token_hash,request.receiptToken); assert.ok(!JSON.stringify(stored).includes(request.receiptToken));
  assert.deepEqual(await lifecycle.status({receiptToken:request.receiptToken}),result);
  for (const privateValue of [owner.id,'Private fixture name','2000-01-01',request.receiptToken,'1000000']) assert.ok(!JSON.stringify(result).includes(privateValue));
  await assert.rejects(lifecycle.consentHistory(owner),code('UNAUTHENTICATED'));
  await assert.rejects(db.pool.query('DELETE FROM account_deletion_events WHERE request_id=$1',[result.requestId]),/append-only/);
  await assert.rejects(db.pool.query('DELETE FROM journal_lines WHERE batch_id=$1',[batch]),/append-only/);
});

test('concurrent duplicate submission is idempotent; capabilities cannot cross accounts', async () => {
  const owner = await account(), other = await account(), request = submission();
  const [one,two] = await Promise.all([lifecycle.requestDeletion(owner,request),lifecycle.requestDeletion(owner,request)]);
  assert.deepEqual(one,two); assert.equal(await count('deletion_requests',owner.id),1);
  assert.equal((await db.pool.query("SELECT count(*) FROM account_deletion_events WHERE request_id=$1 AND kind='requested'",[one.requestId])).rows[0].count,'1');
  await assert.rejects(lifecycle.requestDeletion(owner,submission()),code('DELETION_REQUEST_EXISTS'));
  await assert.rejects(lifecycle.requestDeletion(other,request),code('DELETION_REQUEST_EXISTS'));
  assert.equal(await count('deletion_requests',other.id),0); assert.equal(await count('profiles',other.id),1);
  await assert.rejects(lifecycle.status({receiptToken:secret()}),code('DELETION_RECEIPT_NOT_FOUND'));
  await assert.rejects(lifecycle.status({receiptToken:request.receiptToken,userId:other.id}),code('INVALID_FIELD'));
});

test('financial and dispute holds retain records but promptly erase unrelated profile and DOB', async () => {
  const owner = await account(), purchaseId = await purchase(owner), supportId = await ticket(owner), request = submission();
  const result = await lifecycle.requestDeletion(owner,request);
  assert.equal(result.status,'pending_hold'); assert.deepEqual(result.holds,['financial_pending','dispute_open']);
  assert.ok(result.personalDataDeletedAt); assert.equal(await count('profiles',owner.id),0); assert.equal(await count('age_declarations',owner.id),0);
  assert.equal(await count('purchases',owner.id),1);
  await db.pool.query("UPDATE purchases SET state='cancelled' WHERE id=$1",[purchaseId]);
  await db.pool.query("UPDATE support_tickets SET status='resolved' WHERE id=$1",[supportId]);
  await lifecycle.processPending();
  const final = await lifecycle.status({receiptToken:request.receiptToken});
  assert.equal(final.status,'review_required'); assert.deepEqual(final.holds,[]);
  assert.equal(final.personalDataDeletedAt,result.personalDataDeletedAt); assert.equal(final.retentionReviewRequired,true);
  assert.equal(await count('purchases',owner.id),1);
});

test('explicit scoped evidence delays only a submitted name, then closure scrubs it without financial loss', async () => {
  const owner = await account(), hold = await profileHold(owner), batch = await ledger(owner), request = submission();
  const before = (await db.pool.query('SELECT * FROM journal_lines WHERE batch_id=$1 ORDER BY id',[batch])).rows;
  const result = await lifecycle.requestDeletion(owner,request);
  assert.equal(result.personalDataDeletedAt,null); assert.deepEqual(result.holds,['dispute_open','profile_evidence']);
  assert.equal(await count('profiles',owner.id),0); assert.equal(await count('age_declarations',owner.id),0);
  let evidence = (await db.pool.query('SELECT * FROM account_profile_evidence_holds WHERE id=$1',[hold.id])).rows[0];
  assert.equal(evidence.retained_display_name,'Private fixture name'); assert.ok(!JSON.stringify(evidence).includes('2000-01-01'));
  await db.pool.query("UPDATE support_tickets SET status='closed' WHERE id=$1",[hold.supportId]);
  await lifecycle.processPending();
  const final = await lifecycle.status({receiptToken:request.receiptToken});
  assert.equal(final.status,'review_required'); assert.ok(final.personalDataDeletedAt); assert.deepEqual(final.holds,[]);
  evidence = (await db.pool.query('SELECT * FROM account_profile_evidence_holds WHERE id=$1',[hold.id])).rows[0];
  assert.equal(evidence.retained_display_name,null); assert.ok(evidence.released_at);
  await lifecycle.processPending(); assert.deepEqual(await lifecycle.status({receiptToken:request.receiptToken}),final);
  assert.deepEqual((await db.pool.query('SELECT * FROM journal_lines WHERE batch_id=$1 ORDER BY id',[batch])).rows,before);
});

test('underage declaration/profile is erased despite evidence hold; identity remains restricted for review', async () => {
  const owner = await account('2015-01-01'), hold = await profileHold(owner), request = submission();
  const result = await lifecycle.requestDeletion(owner,request);
  assert.ok(result.personalDataDeletedAt); assert.ok(result.holds.includes('age_safety_review')); assert.ok(!result.holds.includes('profile_evidence'));
  assert.equal(await count('profiles',owner.id),0); assert.equal(await count('age_declarations',owner.id),0);
  assert.equal((await db.pool.query('SELECT retained_display_name FROM account_profile_evidence_holds WHERE id=$1',[hold.id])).rows[0].retained_display_name,null);
  await db.pool.query("UPDATE support_tickets SET status='closed' WHERE id=$1",[hold.supportId]);
  await lifecycle.processPending();
  assert.deepEqual((await lifecycle.status({receiptToken:request.receiptToken})).holds,['age_safety_review']);
  assert.equal((await db.pool.query('SELECT state FROM auth_identities WHERE user_id=$1',[owner.id])).rows[0].state,'revoked');
});

test('holds must concern the account and cannot restore erased evidence or change scope', async () => {
  const owner = await account(), other = await account(), unrelatedTicket = await ticket(other);
  await assert.rejects(profileHold(owner,unrelatedTicket),/does not concern account/);
  const hold = await profileHold(owner);
  await assert.rejects(db.pool.query('UPDATE account_profile_evidence_holds SET user_id=$2 WHERE id=$1',[hold.id,other.id]),/immutable/);
  await lifecycle.requestDeletion(owner,submission());
  await assert.rejects(profileHold(owner,hold.supportId),/after deletion starts/);
  await db.pool.query('UPDATE account_profile_evidence_holds SET released_at=now(),retained_display_name=NULL WHERE id=$1',[hold.id]);
  await assert.rejects(db.pool.query("UPDATE account_profile_evidence_holds SET retained_display_name='Restored fixture' WHERE id=$1",[hold.id]),/restore released/);
});

test('unknown refund, payout and unreleased spend outcome stay held until their synthetic terminal states', async () => {
  const owner = await account(), purchaseId = await purchase(owner), refund = randomUUID(), payoutAccount = randomUUID(), payout = randomUUID();
  const ended = await call(owner), request = submission();
  await db.pool.query("UPDATE purchases SET state='verified' WHERE id=$1",[purchaseId]);
  await db.pool.query("UPDATE purchases SET state='fulfilled' WHERE id=$1",[purchaseId]);
  await db.pool.query("INSERT INTO refunds(id,purchase_id,user_id,provider,request_key,amount_paise) VALUES($1,$2,$3,'fixture','fixture-refund',100)",[refund,purchaseId,owner.id]);
  await db.pool.query("UPDATE refunds SET state='processing' WHERE id=$1",[refund]);
  await db.pool.query("UPDATE refunds SET state='unknown' WHERE id=$1",[refund]);
  await db.pool.query("INSERT INTO payout_accounts(id,user_id,provider,account_digest) VALUES($1,$2,'fixture',$3)",[payoutAccount,owner.id,secret()]);
  await db.pool.query("UPDATE payout_accounts SET state='verified',verified_at=now() WHERE id=$1",[payoutAccount]);
  await db.pool.query("INSERT INTO payout_requests(id,user_id,payout_account_id,provider,request_key,request_fingerprint,amount_paise) VALUES($1,$2,$3,'fixture','fixture-payout',$4,100)",[payout,owner.id,payoutAccount,secret()]);
  await db.pool.query("UPDATE payout_requests SET state='approved' WHERE id=$1",[payout]);
  await db.pool.query("UPDATE payout_requests SET state='processing' WHERE id=$1",[payout]);
  await db.pool.query("UPDATE payout_requests SET state='unknown' WHERE id=$1",[payout]);
  await db.pool.query('INSERT INTO spend_holds(call_id,user_id,amount) VALUES($1,$2,100)',[ended,owner.id]);
  const first = await lifecycle.requestDeletion(owner,request); assert.deepEqual(first.holds,['financial_pending']); assert.ok(first.personalDataDeletedAt);
  await db.pool.query("UPDATE refunds SET state='succeeded' WHERE id=$1",[refund]);
  await lifecycle.processPending(); assert.deepEqual((await lifecycle.status({receiptToken:request.receiptToken})).holds,['financial_pending']);
  await db.pool.query("UPDATE payout_requests SET state='paid' WHERE id=$1",[payout]);
  await lifecycle.processPending(); assert.deepEqual((await lifecycle.status({receiptToken:request.receiptToken})).holds,['financial_pending']);
  await db.pool.query('UPDATE spend_holds SET released_at=now() WHERE call_id=$1',[ended]);
  await lifecycle.processPending(); assert.deepEqual((await lifecycle.status({receiptToken:request.receiptToken})).holds,[]);
  for (const table of ['purchases','refunds','payout_requests','payout_accounts']) assert.equal(await count(table,owner.id),1,table);
});

test('Redis cleanup failure does not undo authoritative withdrawal or lose capability receipt', async () => {
  const owner = await account(), request = submission();
  const failingPresence = new AccountLifecycle(db,()=>now,async()=>{throw new Error('Synthetic Redis outage');});
  const result = await failingPresence.requestDeletion(owner,request);
  assert.ok(result.personalDataDeletedAt); assert.equal((await db.pool.query('SELECT suspended FROM users WHERE id=$1',[owner.id])).rows[0].suspended,true);
  assert.deepEqual(await lifecycle.status({receiptToken:request.receiptToken}),result);
});

test('private-storage cleanup failure stays durable and retries without delaying unrelated erasure', async () => {
  const owner = await account(), request = submission();
  let unavailable = true, attempts = 0;
  const storage = new AccountLifecycle(db,()=>now,async()=>{},async id=>{
    assert.equal(id,owner.id); attempts++;
    if (unavailable) throw new Error('Synthetic private-storage outage');
  });
  const first = await storage.requestDeletion(owner,request);
  assert.equal(first.status,'pending_hold'); assert.equal(first.personalDataDeletedAt,null);
  assert.deepEqual(first.holds,['private_material_cleanup']); assert.equal(await count('profiles',owner.id),0);
  assert.equal(await count('devices',owner.id),0); assert.equal(attempts,1);
  // A worker without the storage adapter cannot falsely clear the pending work.
  await lifecycle.processPending(); assert.equal((await lifecycle.status({receiptToken:request.receiptToken})).personalDataDeletedAt,null);
  unavailable = false; await storage.processPending();
  const final = await lifecycle.status({receiptToken:request.receiptToken});
  assert.ok(final.personalDataDeletedAt); assert.deepEqual(final.holds,[]); assert.equal(final.status,'review_required');
  assert.equal(attempts,2);
});

async function startHttp() {
  if(runtime)return;
  const config: Config = { databaseUrl,redisUrl:process.env.TEST_REDIS_URL??'redis://127.0.0.1:56379/15',port:0,
    devAccessKey:'synthetic-lifecycle-key-only',phoneAuth:{projectId:'lifecycle-fixture',digestKey:secret(),
      consentVersion:'phone-signin-v1',msg91WidgetId:'fixture-widget',msg91AuthKey:'fixture-key',dailySendLimit:10} };
  const dependencies: PhoneAuthDependencies = {otp:{
    async request(){throw new Error('No SMS in lifecycle tests');},async verify(){throw new Error('No SMS in lifecycle tests');},
  },firebase:{async verifyIdToken(raw){
    const identity=typeof raw==='string'?providerIdentities.get(raw):undefined;
    if(!identity)throw new ApiError(401,'INVALID_ID_TOKEN','Sign in again.');
    return {uid:identity.uid,authTime:identity.authTime,issuedAt:Math.floor(now/1000),expiresAt:Math.floor(now/1000)+3600,
      issuer:'https://securetoken.google.com/lifecycle-fixture',audience:'lifecycle-fixture'};
  }}};
  runtime=await createApplication(config,()=>now,dependencies);await runtime.app.listen(0,'127.0.0.1');base=await runtime.app.getUrl();
}
async function httpIdentity(owner: Actor, authTime=Math.floor(now/1000)) {
  const token=`fixture-${secret()}`; providerIdentities.set(token,{uid:owner.id,authTime});
  await db.pool.query('UPDATE auth_sessions SET token_hash=$2 WHERE user_id=$1',[owner.id,tokenHash(token)]);
  await db.pool.query('UPDATE devices SET last_token_hash=$2 WHERE user_id=$1',[owner.id,tokenHash(token)]);
  return token;
}
async function requestHttp(route:string,method='GET',token?:string,body?:unknown) {
  const response=await fetch(`${base}/v1/${route}`,{method,headers:{...(token?{Authorization:`Bearer ${token}`}:{}) ,...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});
  return {status:response.status,body:await response.json() as any};
}

test('HTTP guards reject anonymous and development callers and caller-supplied step-up', async () => {
  await startHttp();
  assert.equal((await requestHttp('me/deletion-requests','POST',undefined,submission())).status,401);
  const owner=await account(),token=secret();
  await db.pool.query("UPDATE auth_sessions SET token_hash=$2,auth_kind='development',device_record_id=NULL,identity_issued_at=NULL WHERE user_id=$1",[owner.id,tokenHash(token)]);
  const denied=await requestHttp('me/deletion-requests','POST',token,submission());
  assert.equal(denied.status,403);assert.equal(denied.body.error.code,'FRESH_SIGN_IN_REQUIRED');
  const forged=await requestHttp('me/deletion-requests','POST',token,{...submission(),identityAuthTime:Math.floor(now/1000)});
  assert.equal(forged.status,400);assert.equal(forged.body.error.code,'INVALID_FIELD');
  assert.equal(await count('deletion_requests',owner.id),0);
});

test('HTTP fresh identity receives contract receipt; public capability survives revoked login without exposing another owner', async () => {
  await startHttp();
  const owner=await account(),other=await account(),token=await httpIdentity(owner),request=submission();
  const history=await requestHttp('me/consents','GET',token);
  assert.equal(history.status,200);assert.equal(history.body.items.length,1);
  const ownConsent=(await db.pool.query('SELECT id FROM consents WHERE user_id=$1',[owner.id])).rows[0].id;
  const otherConsent=(await db.pool.query('SELECT id FROM consents WHERE user_id=$1',[other.id])).rows[0].id;
  assert.equal(history.body.items[0].id,ownConsent);assert.ok(!JSON.stringify(history.body).includes(otherConsent));
  const notice=await requestHttp('me/deletion-notice','GET',token);assert.equal(notice.status,200);assert.equal(notice.body.noticeVersion,DELETION_NOTICE_VERSION);
  const forged=await requestHttp('me/deletion-requests','POST',token,{...request,userId:other.id});assert.equal(forged.status,400);
  const deleted=await requestHttp('me/deletion-requests','POST',token,request);assert.equal(deleted.status,201);
  const contract=JSON.parse(await readFile(path.resolve(__dirname,'../../../../packages/contracts/openapi.json'),'utf8'));
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  const validate=ajv.compile({$defs:definitions,$ref:'#/$defs/DeletionReceipt'});
  assert.equal(validate(deleted.body),true,JSON.stringify(validate.errors));
  assert.equal((await requestHttp('me/consents','GET',token)).status,401);
  assert.equal((await requestHttp('me/deletion-requests','POST',token,request)).status,401);
  const recovered=await requestHttp('account-deletion/status','POST',undefined,{receiptToken:request.receiptToken});
  assert.equal(recovered.status,201);assert.deepEqual(recovered.body,deleted.body);
  const wrong=await requestHttp('account-deletion/status','POST',undefined,{receiptToken:secret()});
  assert.equal(wrong.status,404);assert.equal(wrong.body.error.code,'DELETION_RECEIPT_NOT_FOUND');
  assert.equal((await requestHttp('account-deletion/status','POST',undefined,{receiptToken:'bad'})).status,400);
  assert.equal(await count('profiles',other.id),1);
});

test('HTTP stale provider auth_time cannot be refreshed by a client-issued timestamp', async () => {
  await startHttp();
  const owner=await account(),token=await httpIdentity(owner,Math.floor(now/1000)-301);
  const denied=await requestHttp('me/deletion-requests','POST',token,submission());
  assert.equal(denied.status,403);assert.equal(denied.body.error.code,'FRESH_SIGN_IN_REQUIRED');
  assert.equal(await count('deletion_requests',owner.id),0);
});
