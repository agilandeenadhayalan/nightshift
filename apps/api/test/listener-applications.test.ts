import 'reflect-metadata';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { mkdtemp, readFile, readdir, rm, symlink, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { Database } from '../src/db';
import { migrate } from '../src/migrate';
import { Actor, tokenHash } from '../src/auth';
import { ListenerApplications, LocalReviewStorage, validateReviewWave } from '../src/listener-applications';
import { createApplication } from '../src/http';
import { AccountLifecycle, DELETION_NOTICE_VERSION } from '../src/account-lifecycle';

const schema=`listener_application_${randomUUID().replaceAll('-','')}`;
let db:Database, admin:Database, service:ListenerApplications, storage:LocalReviewStorage, directory:string;
let databaseUrl:string,runtime:Awaited<ReturnType<typeof createApplication>>|undefined;
const tokens=new Map<string,string>();
let now=Date.now();
const key=()=>randomUUID();
const digest=(bytes:Buffer)=>createHash('sha256').update(bytes).digest('hex');
const draft=()=>({bio:'I enjoy talking about books and everyday experiences.',topics:['everyday','hobbies'],
  languages:['ta','en'],voiceSampleConsent:true,consentVersion:'listener-review-v1'});

function wave(seconds=2){
  const size=seconds*8000*2, bytes=Buffer.alloc(44+size);
  bytes.write('RIFF',0);bytes.writeUInt32LE(36+size,4);bytes.write('WAVEfmt ',8);
  bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(1,22);
  bytes.writeUInt32LE(8000,24);bytes.writeUInt32LE(16000,28);bytes.writeUInt16LE(2,32);bytes.writeUInt16LE(16,34);
  bytes.write('data',36);bytes.writeUInt32LE(size,40);return bytes;
}
before(async()=>{
  assert.ok(process.env.TEST_DATABASE_URL,'Use a dedicated test database');
  const url=new URL(process.env.TEST_DATABASE_URL!);admin=new Database(url.toString());
  await admin.pool.query(`CREATE SCHEMA ${schema}`);url.searchParams.set('options',`-csearch_path=${schema}`);
  databaseUrl=url.toString();db=new Database(databaseUrl);await migrate(db);
  directory=await mkdtemp(path.join(os.tmpdir(),'nightshift-listener-test-'));storage=new LocalReviewStorage(directory);
  service=new ListenerApplications(db,{storage,capabilityKey:randomBytes(32).toString('hex')},()=>now);
});
after(async()=>{
  if(runtime)await runtime.close();
  if(db)await db.close();if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}
  if(directory){
    assert.equal(path.dirname(path.resolve(directory)),path.resolve(os.tmpdir()));
    assert.ok(path.basename(directory).startsWith('nightshift-listener-test-'));
    await rm(directory,{recursive:true,force:true});
  }
});
async function actor(adult=true):Promise<Actor>{
  const id=randomUUID(),token=randomUUID(),sessionHash=tokenHash(token);tokens.set(id,token);
  await db.pool.query("INSERT INTO users(id,display_name,adult_confirmed) VALUES($1,'Applicant',$2)",[id,adult]);
  await db.pool.query("INSERT INTO auth_sessions(token_hash,user_id,device_id,expires_at) VALUES($1,$2,'fixture',$3)",[sessionHash,id,new Date(now+3600000)]);
  return {id,sessionHash};
}
async function ready(owner:Actor,appId:string,bytes=wave()){
  const lease=await service.issueUpload(owner,appId,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  const result=await service.upload(owner,appId,lease.uploadId,lease.uploadToken,'audio/wav',bytes);
  return {lease,result,bytes};
}

test('eligible owner saves a private draft and duplicate create does not duplicate applications',async()=>{
  const owner=await actor(),requestKey=key(),body=draft();
  const [a,b]=await Promise.all([service.create(owner,body,requestKey),service.create(owner,body,requestKey)]);
  assert.equal(a.id,b.id);assert.equal(a.state,'draft');assert.equal(a.voiceSampleUploadId,null);
  assert.equal((await service.get(owner)).application!.bio,body.bio);
  assert.equal((await db.pool.query('SELECT count(*) FROM listener_applications WHERE user_id=$1',[owner.id])).rows[0].count,'1');
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[owner.id])).rows[0].listener_approved,false);
  await assert.rejects(service.create(owner,{...body,bio:'changed'},requestKey),{code:'IDEMPOTENCY_CONFLICT'});
});

test('underage, suspended and revoked sessions cannot create applications',async()=>{
  const child=await actor(false);await assert.rejects(service.create(child,draft(),key()),{code:'ADULT_ONLY'});
  const blocked=await actor();await db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[blocked.id]);
  await assert.rejects(service.create(blocked,draft(),key()),{code:'UNAUTHENTICATED'});
  const revoked=await actor();await db.pool.query('UPDATE auth_sessions SET revoked_at=now() WHERE token_hash=$1',[revoked.sessionHash]);
  await assert.rejects(service.create(revoked,draft(),key()),{code:'UNAUTHENTICATED'});
});

test('draft validation rejects forged state, unbounded text, invalid enum types and unknown codes',async()=>{
  const owner=await actor();
  for(const patch of [{state:'approved'},{bio:'a'.repeat(1001)},{topics:['unknown']},{topics:['everyday','everyday']},
    {languages:['fr']},{languages:'ta'},{voiceSampleConsent:'true'},{consentVersion:'stale'}]){
    await assert.rejects(service.create(owner,{...draft(),...patch},key()),error=>typeof error==='object' && error!==null && 'status' in error && error.status===400);
  }
});

test('valid WAV upload is private, bounded and capability retries do not persist raw secrets',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave(),requestKey=key();
  const descriptor={contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)};
  const first=await service.issueUpload(owner,app.id,descriptor,requestKey),again=await service.issueUpload(owner,app.id,descriptor,requestKey);
  assert.deepEqual(again,first);assert.equal(first.maxBytes,2097152);
  const uploaded=await service.upload(owner,app.id,first.uploadId,first.uploadToken,'audio/wav',bytes);
  assert.equal(uploaded.voiceSampleUploadId,first.uploadId);
  const read=await service.readUpload(owner,app.id,first.uploadId);assert.deepEqual(read.bytes,bytes);
  const stored=(await db.pool.query('SELECT row_to_json(u)::text payload FROM listener_review_uploads u WHERE id=$1',[first.uploadId])).rows[0].payload;
  assert.ok(!stored.includes(first.uploadToken));
  assert.deepEqual((await readdir(directory)).filter(n=>n.startsWith(first.uploadId)),[`${first.uploadId}.wav`]);
});

test('other applicants cannot read, replace or attach a private sample even with its capability',async()=>{
  const owner=await actor(),other=await actor(),app=await service.create(owner,draft(),key()),uploaded=await ready(owner,app.id);
  await assert.rejects(service.readUpload(other,app.id,uploaded.lease.uploadId),{code:'APPLICATION_NOT_FOUND'});
  await assert.rejects(service.upload(other,app.id,uploaded.lease.uploadId,uploaded.lease.uploadToken,'audio/wav',uploaded.bytes),{code:'APPLICATION_NOT_FOUND'});
  await assert.rejects(service.update(other,app.id,draft()),{code:'APPLICATION_NOT_FOUND'});
  await assert.rejects(service.update(owner,app.id,{...draft(),voiceSampleUploadId:uploaded.lease.uploadId}),{code:'INVALID_FIELD'});
});

test('interrupted upload remains retryable and invalid or expired capabilities never store data',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave();
  const lease=await service.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  await assert.rejects(service.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes.subarray(0,44)),{code:'UPLOAD_LENGTH_MISMATCH'});
  assert.equal((await db.pool.query('SELECT state FROM listener_review_uploads WHERE id=$1',[lease.uploadId])).rows[0].state,'pending');
  await assert.rejects(service.upload(owner,app.id,lease.uploadId,'wrong','audio/wav',bytes),{code:'UPLOAD_CAPABILITY_INVALID'});
  await service.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes);
  const later=await service.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  now+=300001;
  await assert.rejects(service.upload(owner,app.id,later.uploadId,later.uploadToken,'audio/wav',bytes),{code:'UPLOAD_EXPIRED'});
});

test('type/signature/digest/duration and declared byte limits are enforced',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key());
  await assert.rejects(service.issueUpload(owner,app.id,{contentType:'image/png',byteLength:100,sha256:'a'.repeat(64)},key()),{code:'INVALID_UPLOAD'});
  await assert.rejects(service.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:2097153,sha256:'a'.repeat(64)},key()),{code:'INVALID_UPLOAD'});
  for(const bytes of [Buffer.alloc(100),wave(1),wave(61)]){
    const lease=await service.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
    await assert.rejects(service.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes),{code:'INVALID_WAV'});
  }
  const bytes=wave(),lease=await service.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:'a'.repeat(64)},key());
  await assert.rejects(service.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes),{code:'UPLOAD_DIGEST_MISMATCH'});
});

test('submission is idempotent, requires consent and ready sample, and never grants Listener entitlement',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key());
  await assert.rejects(service.submit(owner,app.id,key()),{code:'APPLICATION_INCOMPLETE'});
  await ready(owner,app.id);const requestKey=key();
  const results=await Promise.all([service.submit(owner,app.id,requestKey),service.submit(owner,app.id,requestKey)]);
  assert.equal(results[0].state,'submitted');assert.deepEqual(results[0],results[1]);
  assert.equal((await service.submit(owner,app.id,key())).state,'submitted');
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[owner.id])).rows[0].listener_approved,false);
  await assert.rejects(service.update(owner,app.id,draft()),{code:'APPLICATION_NOT_EDITABLE'});
});

test('withdrawing material consent makes an uploaded sample unreadable and removes its private file',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),uploaded=await ready(owner,app.id);
  const updated=await service.update(owner,app.id,{...draft(),voiceSampleConsent:false,consentVersion:'listener-review-v1'});
  assert.equal(updated.voiceSampleUploadId,null);assert.equal(updated.voiceSampleConsent,false);
  await assert.rejects(service.readUpload(owner,app.id,uploaded.lease.uploadId),{code:'UPLOAD_NOT_FOUND'});
  await assert.rejects(readFile(path.join(directory,`${uploaded.lease.uploadId}.wav`)),{code:'ENOENT'});
  await assert.rejects(service.submit(owner,app.id,key()),{code:'APPLICATION_INCOMPLETE'});
});

test('needs-information and rejected outcomes remain visible without client-controlled review decisions',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key());await ready(owner,app.id);await service.submit(owner,app.id,key());
  await db.pool.query("UPDATE listener_applications SET state='needs_information' WHERE id=$1",[app.id]);
  assert.equal((await service.get(owner)).application!.state,'needs_information');
  await service.update(owner,app.id,{...draft(),bio:'Updated private application.'});
  assert.equal((await service.submit(owner,app.id,key())).state,'submitted');
  await db.pool.query("UPDATE listener_applications SET state='rejected',decided_at=now() WHERE id=$1",[app.id]);
  assert.equal((await service.get(owner)).application!.state,'rejected');
  await assert.rejects(service.submit(owner,app.id,key()),{code:'APPLICATION_NOT_EDITABLE'});
  const next=await service.create(owner,draft(),key());assert.notEqual(next.id,app.id);
});

test('withdrawal is idempotent, prevents submission and scrubs its sample',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),uploaded=await ready(owner,app.id);
  const requestKey=key();const first=await service.withdraw(owner,app.id,requestKey),again=await service.withdraw(owner,app.id,requestKey);
  assert.equal(first.state,'withdrawn');assert.deepEqual(again,first);
  await assert.rejects(service.readUpload(owner,app.id,uploaded.lease.uploadId),{code:'UPLOAD_NOT_FOUND'});
  await assert.rejects(service.submit(owner,app.id,key()),{code:'APPLICATION_NOT_EDITABLE'});
});

test('private-material erasure removes all files and private application/idempotency payloads',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),uploaded=await ready(owner,app.id);
  await service.erasePrivateMaterials(owner.id);await service.erasePrivateMaterials(owner.id);
  await assert.rejects(readFile(path.join(directory,`${uploaded.lease.uploadId}.wav`)),{code:'ENOENT'});
  const row=(await db.pool.query('SELECT bio,topics,voice_sample_upload_id FROM listener_applications WHERE id=$1',[app.id])).rows[0];
  assert.equal(row.bio,'');assert.deepEqual(row.topics,[]);assert.equal(row.voice_sample_upload_id,null);
  assert.equal((await db.pool.query("SELECT count(*) FROM idempotency_keys WHERE actor_id=$1 AND operation LIKE 'listener.application.%'",[owner.id])).rows[0].count,'0');
});

test('unconfigured storage fails closed and path-like identifiers cannot access files',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave();
  const disabled=new ListenerApplications(db,{capabilityKey:'fixture-key-at-least-24-characters'},()=>now);
  await assert.rejects(disabled.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key()),{code:'REVIEW_UPLOAD_UNAVAILABLE'});
  await assert.rejects(storage.read('../outside'),{code:'INVALID_ID'});
  await assert.rejects(storage.write('../outside',bytes),{code:'INVALID_ID'});
});

test('retry recovers a disk write whose database transaction was interrupted',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave();let fail=true;
  class InterruptedStorage extends LocalReviewStorage{override async write(id:string,body:Buffer){await super.write(id,body);if(fail){fail=false;throw new Error('Synthetic interrupted transaction');}}}
  const instance=new ListenerApplications(db,{storage:new InterruptedStorage(directory),capabilityKey:'synthetic-interrupted-upload-key'},()=>now);
  const lease=await instance.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  await assert.rejects(instance.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes),/Synthetic interrupted/);
  assert.equal((await db.pool.query('SELECT state FROM listener_review_uploads WHERE id=$1',[lease.uploadId])).rows[0].state,'pending');
  assert.equal((await instance.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes)).voiceSampleUploadId,lease.uploadId);
});

test('retrying withdrawal resumes failed file cleanup instead of trusting cached success',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),uploaded=await ready(owner,app.id);let fail=true;
  class FailedCleanupStorage extends LocalReviewStorage{override async remove(id:string){if(fail){fail=false;throw new Error('Synthetic cleanup interruption');}await super.remove(id);}}
  const instance=new ListenerApplications(db,{storage:new FailedCleanupStorage(directory),capabilityKey:'synthetic-cleanup-retry-key'},()=>now),requestKey=key();
  await assert.rejects(instance.withdraw(owner,app.id,requestKey),/Synthetic cleanup/);
  assert.equal((await instance.withdraw(owner,app.id,requestKey)).state,'withdrawn');
  await assert.rejects(readFile(path.join(directory,`${uploaded.lease.uploadId}.wav`)),{code:'ENOENT'});
});

test('consent withdrawal invalidates pending capabilities and later consent creates a new audit event',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave();
  const lease=await service.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  await service.update(owner,app.id,{...draft(),voiceSampleConsent:false});
  await service.update(owner,app.id,draft());
  await assert.rejects(service.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes),{code:'UPLOAD_NOT_FOUND'});
  assert.deepEqual((await db.pool.query('SELECT granted FROM listener_application_consents WHERE application_id=$1 ORDER BY recorded_at,id',[app.id])).rows.map(r=>r.granted),[true,false,true]);
  assert.equal((await db.pool.query("SELECT count(*) FROM consents WHERE user_id=$1 AND purpose='listener-review-material'",[owner.id])).rows[0].count,'3');
});

test('missing private file cannot be submitted as a complete review application',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),uploaded=await ready(owner,app.id);
  await unlink(path.join(directory,`${uploaded.lease.uploadId}.wav`));
  await assert.rejects(service.submit(owner,app.id,key()),{code:'UPLOAD_NOT_FOUND'});
  assert.equal((await service.get(owner)).application!.state,'draft');
});

test('storage rejects symlink roots and file targets without reading outside the private directory',async()=>{
  const target=path.join(directory,'outside-fixture'),link=path.join(directory,`${randomUUID()}.wav`),rootLink=path.join(directory,'root-link');
  await import('node:fs/promises').then(fs=>fs.mkdir(target));
  await writeFile(path.join(target,'marker'),'fixture');
  await symlink(target,link,'junction');await symlink(target,rootLink,'junction');
  try{
    const id=path.basename(link,'.wav');
    await assert.rejects(storage.read(id),{code:'REVIEW_UPLOAD_UNAVAILABLE'});
    await assert.rejects(storage.write(id,wave()),{code:'REVIEW_UPLOAD_UNAVAILABLE'});
    await assert.rejects(new LocalReviewStorage(rootLink).read(randomUUID()),{code:'REVIEW_UPLOAD_UNAVAILABLE'});
    assert.equal(await readFile(path.join(target,'marker'),'utf8'),'fixture');
  }finally{await unlink(link);await unlink(rootLink);}
});

test('WAV signatures are byte-exact and sample data must follow its PCM format',()=>{
  for(const index of [0,8,12,36]){
    const bytes=wave();bytes[index]=bytes[index]!|0x80;
    assert.throws(()=>validateReviewWave(bytes),{code:'INVALID_WAV'});
  }
  const bytes=wave(),reordered=Buffer.concat([bytes.subarray(0,12),bytes.subarray(36),bytes.subarray(12,36)]);
  assert.throws(()=>validateReviewWave(reordered),{code:'INVALID_WAV'});
});

test('consent can be withdrawn after a terminal staff decision without changing its outcome',async()=>{
  for(const state of ['approved','rejected']){
    const owner=await actor(),app=await service.create(owner,draft(),key()),uploaded=await ready(owner,app.id);
    await service.submit(owner,app.id,key());
    await db.pool.query('UPDATE listener_applications SET state=$2,decided_at=now() WHERE id=$1',[app.id,state]);
    const requestKey=key(),result=await service.withdraw(owner,app.id,requestKey);
    assert.equal(result.state,state);assert.equal(result.voiceSampleConsent,false);assert.equal(result.voiceSampleUploadId,null);
    assert.deepEqual(await service.withdraw(owner,app.id,requestKey),result);
    await assert.rejects(service.readUpload(owner,app.id,uploaded.lease.uploadId),{code:'UPLOAD_NOT_FOUND'});
    await assert.rejects(readFile(path.join(directory,`${uploaded.lease.uploadId}.wav`)),{code:'ENOENT'});
    assert.deepEqual((await db.pool.query('SELECT granted FROM listener_application_consents WHERE application_id=$1 ORDER BY recorded_at,id',[app.id])).rows.map(r=>r.granted),[true,false]);
  }
});

test('upload limits apply to the owner across withdrawn applications and bound pending leases to three',async()=>{
  const owner=await actor(),bytes=wave(),descriptor={contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)};
  let app=await service.create(owner,draft(),key());
  for(let n=0;n<3;n++)await service.issueUpload(owner,app.id,descriptor,key());
  await assert.rejects(service.issueUpload(owner,app.id,descriptor,key()),{code:'UPLOAD_LIMIT'});
  for(let count=3;count<20;count++){
    await service.withdraw(owner,app.id,key());app=await service.create(owner,draft(),key());
    await service.issueUpload(owner,app.id,descriptor,key());
  }
  await service.withdraw(owner,app.id,key());app=await service.create(owner,draft(),key());
  await assert.rejects(service.issueUpload(owner,app.id,descriptor,key()),{code:'UPLOAD_LIMIT'});
});

test('autonomous sweeper recovers abandoned disk writes and retries failed withdrawal cleanup fairly',async()=>{
  now+=300001;await service.sweepExpiredUploads();
  const owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave();
  class AbandonedStorage extends LocalReviewStorage{override async write(id:string,body:Buffer){await super.write(id,body);throw new Error('Synthetic lost transaction');}}
  const abandoned=new ListenerApplications(db,{storage:new AbandonedStorage(directory),capabilityKey:'synthetic-abandoned-upload-key'},()=>now);
  const descriptor={contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)};
  const first=await abandoned.issueUpload(owner,app.id,descriptor,key()),second=await abandoned.issueUpload(owner,app.id,descriptor,key());
  for(const lease of [first,second])await assert.rejects(abandoned.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes),/Synthetic lost/);
  now+=300001;let blocked=true;
  class RetryStorage extends LocalReviewStorage{override async remove(id:string){if(blocked && id===first.uploadId)throw new Error('Synthetic disk busy');await super.remove(id);}}
  const retry=new ListenerApplications(db,{storage:new RetryStorage(directory),capabilityKey:'synthetic-cleanup-sweep-key'},()=>now);
  // Stable order when two leases share the injected creation timestamp.
  await db.pool.query('UPDATE listener_review_uploads SET cleanup_attempted_at=now() WHERE id=$1',[second.uploadId]);
  assert.deepEqual(await retry.sweepExpiredUploads(1),{purged:0,failed:1});
  assert.deepEqual(await retry.sweepExpiredUploads(1),{purged:1,failed:0});
  await assert.rejects(readFile(path.join(directory,`${second.uploadId}.wav`)),{code:'ENOENT'});
  blocked=false;assert.deepEqual(await retry.sweepExpiredUploads(),{purged:1,failed:0});
  await assert.rejects(readFile(path.join(directory,`${first.uploadId}.wav`)),{code:'ENOENT'});
  const remaining=await ready(owner,app.id);blocked=true;
  class WithdrawalStorage extends LocalReviewStorage{override async remove(id:string){if(blocked && id===remaining.lease.uploadId)throw new Error('Synthetic withdrawal interruption');await super.remove(id);}}
  const withdrawal=new ListenerApplications(db,{storage:new WithdrawalStorage(directory),capabilityKey:'synthetic-withdrawal-sweep-key'},()=>now);
  await assert.rejects(withdrawal.withdraw(owner,app.id,key()),/Synthetic withdrawal/);
  blocked=false;assert.equal((await withdrawal.sweepExpiredUploads()).purged,1);
  await assert.rejects(readFile(path.join(directory,`${remaining.lease.uploadId}.wav`)),{code:'ENOENT'});
  assert.deepEqual(await withdrawal.sweepExpiredUploads(),{purged:0,failed:0});
});

test('account deletion serializes with an in-flight upload and prevents stale uploads from recreating private data',async()=>{
  const owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave();
  await db.pool.query("INSERT INTO age_declarations(user_id,date_of_birth) VALUES($1,'2000-01-01')",[owner.id]);
  await db.pool.query("INSERT INTO profiles(user_id,date_of_birth,submitted_display_name,avatar_code,interface_language) VALUES($1,'2000-01-01','Fixture','moon','en')",[owner.id]);
  let entered!:()=>void,release!:()=>void,writes=0;
  const started=new Promise<void>(resolve=>{entered=resolve;}),gate=new Promise<void>(resolve=>{release=resolve;});
  class GatedStorage extends LocalReviewStorage{override async write(id:string,body:Buffer){writes++;entered();await gate;await super.write(id,body);}}
  const instance=new ListenerApplications(db,{storage:new GatedStorage(directory),capabilityKey:'synthetic-deletion-race-key'},()=>now);
  const lifecycle=new AccountLifecycle(db,()=>now,async()=>{},id=>instance.erasePrivateMaterials(id));
  const lease=await instance.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  const upload=instance.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes);await started;
  const deletion=lifecycle.requestDeletion({...owner,identityAuthTime:Math.floor(now/1000)},
    {noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
  release();await upload;const receipt=await deletion;
  assert.ok(receipt.personalDataDeletedAt);assert.ok(!receipt.holds.includes('private_material_cleanup'));
  assert.equal((await db.pool.query('SELECT count(*) FROM profiles WHERE user_id=$1',[owner.id])).rows[0].count,'0');
  assert.equal((await db.pool.query('SELECT bio FROM listener_applications WHERE id=$1',[app.id])).rows[0].bio,'');
  await assert.rejects(readFile(path.join(directory,`${lease.uploadId}.wav`)),{code:'ENOENT'});
  await assert.rejects(instance.upload(owner,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes),{code:'UNAUTHENTICATED'});
  assert.equal(writes,1);
  const next=await actor(),nextApp=await service.create(next,draft(),key());
  const nextLease=await instance.issueUpload(next,nextApp.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  await lifecycle.requestDeletion({...next,identityAuthTime:Math.floor(now/1000)},
    {noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
  await assert.rejects(instance.upload(next,nextApp.id,nextLease.uploadId,nextLease.uploadToken,'audio/wav',bytes),{code:'UNAUTHENTICATED'});
  assert.equal(writes,1);
});

test('HTTP application, raw upload, private download and idempotent submit enforce the generated route shapes',async()=>{
  assert.ok(process.env.REDIS_URL,'Use the local test Redis');
  runtime=await createApplication({databaseUrl,redisUrl:process.env.REDIS_URL!,port:0,
    devAccessKey:'listener-http-test-private-key',privateReviewDirectory:directory},()=>now);
  await runtime.app.listen(0,'127.0.0.1');const base=await runtime.app.getUrl();
  const owner=await actor(),other=await actor(),bytes=wave();
  const headers={Authorization:`Bearer ${tokens.get(owner.id)}`,'Content-Type':'application/json','Idempotency-Key':key()};
  let response=await fetch(`${base}/v1/me/listener-application`,{headers});
  assert.equal(response.status,200);assert.deepEqual(await response.json(),{application:null});
  response=await fetch(`${base}/v1/listener-applications`,{method:'POST',headers,body:JSON.stringify(draft())});
  assert.equal(response.status,201);const app=await response.json() as {id:string;state:string};assert.equal(app.state,'draft');
  response=await fetch(`${base}/v1/listener-applications/${app.id}/uploads`,{method:'POST',headers:{...headers,'Idempotency-Key':key()},body:JSON.stringify({contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)})});
  assert.equal(response.status,201);const lease=await response.json() as {uploadId:string;uploadToken:string};
  const url=`${base}/v1/listener-applications/${app.id}/uploads/${lease.uploadId}`;
  response=await fetch(url,{method:'PUT',headers:{Authorization:headers.Authorization,'Content-Type':'audio/wav','X-Upload-Token':lease.uploadToken},body:bytes});
  assert.equal(response.status,200);assert.equal((await response.json() as {voiceSampleUploadId:string}).voiceSampleUploadId,lease.uploadId);
  response=await fetch(url,{headers:{Authorization:headers.Authorization}});assert.equal(response.status,200);
  assert.equal(response.headers.get('Content-Type'),'audio/wav');assert.equal(response.headers.get('Cache-Control'),'no-store');
  assert.deepEqual(Buffer.from(await response.arrayBuffer()),bytes);
  response=await fetch(url,{headers:{Authorization:`Bearer ${tokens.get(other.id)}`}});assert.equal(response.status,404);
  const submitKey=key(),submit=()=>fetch(`${base}/v1/listener-applications/${app.id}/submit`,{method:'POST',headers:{...headers,'Idempotency-Key':submitKey},body:'{}'});
  response=await submit();assert.equal(response.status,201);const submitted=await response.json();
  response=await submit();assert.equal(response.status,201);assert.deepEqual(await response.json(),submitted);
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[owner.id])).rows[0].listener_approved,false);
});

test('HTTP raw upload rejects unauthorized, oversized, compressed, non-WAV and wrong-digest input with safe errors',async()=>{
  assert.ok(runtime);const base=await runtime.app.getUrl(),owner=await actor(),app=await service.create(owner,draft(),key()),bytes=wave();
  const lease=await runtime.applications.issueUpload(owner,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},key());
  const url=`${base}/v1/listener-applications/${app.id}/uploads/${lease.uploadId}`;
  const headers={Authorization:`Bearer ${tokens.get(owner.id)}`,'Content-Type':'audio/wav','X-Upload-Token':lease.uploadToken};
  for(const scenario of [
    {headers:{'Content-Type':'audio/wav'},body:bytes,status:401,code:'UNAUTHENTICATED'},
    {headers:{'Content-Type':'audio/wav'},body:Buffer.alloc(2097153),status:413,code:'UPLOAD_TOO_LARGE'},
    {headers,body:Buffer.alloc(2097153),status:413,code:'UPLOAD_TOO_LARGE'},
    {headers:{...headers,'Content-Encoding':'gzip'},body:bytes,status:400,code:'INVALID_UPLOAD'},
    {headers:{...headers,'Content-Type':'image/png'},body:bytes,status:400,code:'INVALID_UPLOAD'},
    {headers,body:Buffer.alloc(bytes.length),status:400,code:'UPLOAD_DIGEST_MISMATCH'},
  ]){
    const response=await fetch(url,{method:'PUT',headers:scenario.headers as Record<string,string>,body:scenario.body});
    assert.equal(response.status,scenario.status);const body=await response.json() as {error:{code:string};requestId:string};
    assert.equal(body.error.code,scenario.code);assert.equal(typeof body.requestId,'string');
    assert.ok(!JSON.stringify(body).includes(directory));assert.ok(!JSON.stringify(body).includes(lease.uploadToken));
  }
  assert.equal((await db.pool.query('SELECT state FROM listener_review_uploads WHERE id=$1',[lease.uploadId])).rows[0].state,'pending');
  await assert.rejects(readFile(path.join(directory,`${lease.uploadId}.wav`)),{code:'ENOENT'});
});
