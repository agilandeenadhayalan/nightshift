import 'reflect-metadata';
import {after,before,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {createHash,generateKeyPairSync,randomBytes,randomUUID,sign,verify} from 'node:crypto';
import {mkdtemp,rm,unlink,writeFile} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {Module} from '@nestjs/common';
import {NestFactory} from '@nestjs/core';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import {Database} from '../src/db';
import {migrate} from '../src/migrate';
import {Auth} from '../src/auth';
import {Config} from '../src/config';
import {Presence} from '../src/presence';
import {PhoneAuthentication} from '../src/identity/phone-auth';
import {FirebaseIdentityProvider} from '../src/identity/firebase';
import {StaffAuthority,StaffPermission} from '../src/staff/authority';
import {StaffAppBinding} from '../src/staff/app-binding';
import {FirebaseStaffVerifier} from '../src/staff/firebase';
import {StaffPolicy} from '../src/staff/verifier';
import {StaffReviewQueries} from '../src/staff/review-queries';
import {StaffReviewController} from '../src/staff/review-http';
import {STAFF_COOKIE} from '../src/staff/http';
import {ListenerApplications,LocalReviewStorage} from '../src/listener-applications';
import {AccountLifecycle,DELETION_NOTICE_VERSION} from '../src/account-lifecycle';

const schema=`review_reads_${randomUUID().replaceAll('-','')}`,project='staff-review-fixture';
const digest=(value:Buffer|string)=>createHash('sha256').update(value).digest('hex');
const key=randomBytes(32).toString('hex'),cursorKey=randomBytes(32).toString('hex');
const signing=generateKeyPairSync('ed25519'),encode=(value:unknown)=>Buffer.from(JSON.stringify(value)).toString('base64url');
const providerUsers=new Map<string,{uid:string;phoneNumber:string;disabled:boolean;tokensValidAfterTime?:string}>();
let now=Date.now(),sequence=2000,db:Database,admin:Database,auth:Auth,phone:PhoneAuthentication,authority:StaffAuthority;
let applications:ListenerApplications,review:StaffReviewQueries,storage:ControlledStorage,directory:string;
let app:Awaited<ReturnType<typeof NestFactory.create>>,base:string;
const config:Config={databaseUrl:'',redisUrl:'',port:0,devAccessKey:'synthetic-review-read-test-key',phoneAuth:{provider:'firebase',projectId:project,
  digestKey:key,consentVersion:'fixture-v1',dailyAdmissionLimit:1000}};
const policy:StaffPolicy={issuer:`https://securetoken.google.com/${project}`,audience:project,tenant:'',origin:'https://review-fixture.invalid',
  version:'review-fixture-v1',digestKey:randomBytes(32).toString('hex'),requiredMethods:['sms'],requireAppBinding:true,
  maxAuthenticationAgeSeconds:3600,sessionSeconds:1800,challengeSeconds:120,challengeLimitPerHour:1000,clientChallengeLimitPerHour:100,
  verificationTimeoutMs:500,maxConcurrentVerifications:4};
const defer=<T=void>()=>{let resolve!:(value?:T)=>void;const promise=new Promise<T>(r=>{resolve=value=>r(value as T);});return{resolve,promise};};
type Gate={id:string;entered:ReturnType<typeof defer>;release:ReturnType<typeof defer>};
class ControlledStorage extends LocalReviewStorage{
  gate:Gate|undefined;
  override async read(id:string){
    // Capture actual private file bytes before pausing: the final authorization
    // must deny their release even if withdrawal/deletion already erased disk.
    const bytes=await super.read(id),gate=this.gate;
    if(gate?.id===id){gate.entered.resolve();await gate.release.promise;}
    return bytes;
  }
}
const providerClient={
  async verifyIdToken(token:string,checkRevoked?:boolean){
    assert.equal(checkRevoked,true);const[h,p,s]=token.split('.');
    if(!h||!p||!s||!verify(null,Buffer.from(`${h}.${p}`),signing.publicKey,Buffer.from(s,'base64url')))throw{code:'auth/invalid-id-token'};
    const claims=JSON.parse(Buffer.from(p,'base64url').toString()),user=providerUsers.get(claims.uid);
    if(!user||user.disabled)throw{code:'auth/user-disabled'};
    if(user.tokensValidAfterTime&&claims.auth_time<Math.floor(Date.parse(user.tokensValidAfterTime)/1000))throw{code:'auth/id-token-revoked'};
    return claims;
  },
  async getUser(uid:string){const user=providerUsers.get(uid);if(!user)throw{code:'auth/user-not-found'};return{...user} as any;},
  async createCustomToken(){throw Error('No provider calls from review fixtures');}
};
const firebase=new FirebaseIdentityProvider(providerClient as any,project,()=>now);
const verifier=new FirebaseStaffVerifier(providerClient as any,project,key,()=>now);
const presence={async rateLimit(){return true;},async clear(){}} as unknown as Presence;
function proof(uid:string,mobile:string,authTime=Math.floor(now/1000)){
  const second=Math.floor(now/1000),claims={uid,sub:uid,iss:policy.issuer,aud:project,auth_time:authTime,iat:second,exp:second+3600,
    phone_number:mobile,firebase:{sign_in_provider:'phone',identities:{phone:[mobile]}}};
  const value=`${encode({alg:'EdDSA'})}.${encode(claims)}`;return`${value}.${sign(null,Buffer.from(value),signing.privateKey).toString('base64url')}`;
}
async function account(){
  const uid=`review:${randomUUID()}`,mobile=`+919${String(++sequence).padStart(9,'0')}`,device=randomUUID();
  providerUsers.set(uid,{uid,phoneNumber:mobile,disabled:false});const token=proof(uid,mobile),authTime=Math.floor(now/1000);
  const admission=await phone.admit({phone:mobile,deviceId:device,consentVersion:'fixture-v1'},randomUUID(),randomUUID());
  const enrolled=await auth.exchange({idToken:token,deviceId:device,attemptId:admission.attemptId},randomUUID());
  await db.pool.query("UPDATE users SET adult_confirmed=true,display_name='Public review alias' WHERE id=$1",[enrolled.userId]);
  return{uid,mobile,device,token,authTime,userId:enrolled.userId,actor:await auth.authenticate(token)};
}
async function staff(permissions:StaffPermission[]=['listener.review.read','listener.review.evidence.read']){
  const owner=await account(),request=await authority.accessRequest(owner.token,true);
  await authority.provision(request.requestId,owner.userId,permissions,true);
  const challenge=await authority.challenge(policy.origin,randomUUID(),owner.token);
  const session=await authority.exchange({proof:owner.token},policy.origin,challenge.cookie,challenge.csrfToken,owner.token);
  return{...owner,cookie:session.cookie,staffView:session.view,staffActor:await authority.authenticate(session.cookie)};
}
const draft=(languages=['ta','en'])=>({bio:'Private submitted review biography.',topics:['everyday','hobbies'],languages,
  voiceSampleConsent:true,consentVersion:'listener-review-v1'});
function wave(){const size=32000,bytes=Buffer.alloc(44+size);bytes.write('RIFF',0);bytes.writeUInt32LE(size+36,4);bytes.write('WAVEfmt ',8);
  bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(1,22);bytes.writeUInt32LE(8000,24);bytes.writeUInt32LE(16000,28);
  bytes.writeUInt16LE(2,32);bytes.writeUInt16LE(16,34);bytes.write('data',36);bytes.writeUInt32LE(size,40);return bytes;}
async function submitted(owner?:Awaited<ReturnType<typeof account>>){
  const a=owner??await account(),app=await applications.create(a.actor,draft(),randomUUID()),bytes=wave();
  const lease=await applications.issueUpload(a.actor,app.id,{contentType:'audio/wav',byteLength:bytes.length,sha256:digest(bytes)},randomUUID());
  await applications.upload(a.actor,app.id,lease.uploadId,lease.uploadToken,'audio/wav',bytes);
  await applications.submit(a.actor,app.id,randomUUID());return{owner:a,id:app.id,uploadId:lease.uploadId,bytes};
}
async function bulkSubmitted(count:number,languages=['ta'],submittedAt?:string){
  const ids:string[]=[];
  for(let i=0;i<count;i++){
    const owner=randomUUID(),id=randomUUID();ids.push(id);
    await db.pool.query("INSERT INTO users(id,display_name,adult_confirmed) VALUES($1,'Queue alias',true)",[owner]);
    await db.pool.query("INSERT INTO listener_applications(id,user_id,languages,bio,topics,voice_sample_consent,consent_version,created_at) VALUES($1,$2,$3,'Queue bio',ARRAY['everyday'],false,'listener-review-v1',$4)",[id,owner,languages,new Date(Date.parse(submittedAt??new Date(now-60000).toISOString())-1000)]);
    await db.pool.query("UPDATE listener_applications SET state='submitted',submitted_at=$2 WHERE id=$1",[id,submittedAt??new Date(now-60000).toISOString()]);
  }
  return ids;
}
async function sampleAudit(id:string){return Number((await db.pool.query("SELECT count(*) FROM staff_review_access_events WHERE application_id=$1 AND action='sample.read'",[id])).rows[0].count);}
async function businessSnapshot(){
  const tables=['users','listener_applications','listener_reviews','listener_review_uploads','staff_permission_grants','journal_batches','journal_lines','wallet_accounts','outbox_events'];
  const result:Record<string,unknown>={};
  for(const table of tables)result[table]=(await db.pool.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) value FROM ${table} t`)).rows[0].value;
  return result;
}
before(async()=>{
  assert.equal(process.env.NODE_ENV,'test');const target=new URL(process.env.TEST_DATABASE_URL!);
  assert.ok(['localhost','127.0.0.1'].includes(target.hostname));assert.match(target.pathname,/_test$/);assert.notEqual(target.pathname,'/nightshift_firebase_device');
  admin=new Database(target.toString());await admin.pool.query(`CREATE SCHEMA ${schema}`);target.searchParams.set('options',`-csearch_path=${schema}`);
  db=new Database(target.toString());await migrate(db);
  directory=await mkdtemp(path.join(os.tmpdir(),'nightshift-staff-review-'));storage=new ControlledStorage(directory);
  phone=new PhoneAuthentication(db,presence,config.phoneAuth,{firebase},()=>now);auth=new Auth(db,presence,config,phone,()=>now);
  authority=new StaffAuthority(db,policy,verifier,()=>now,new StaffAppBinding(auth,config.phoneAuth!,()=>now));
  applications=new ListenerApplications(db,{storage,capabilityKey:key},()=>now);
  review=new StaffReviewQueries(db,authority,{cursorKey,storage},()=>now);
  @Module({controllers:[StaffReviewController],providers:[{provide:StaffAuthority,useValue:authority},{provide:StaffReviewQueries,useValue:review}]}) class FixtureModule{}
  app=await NestFactory.create(FixtureModule,{logger:false});await app.listen(0,'127.0.0.1');base=await app.getUrl();
});
beforeEach(async()=>{
  now=Date.now();
  storage.gate?.release.resolve();storage.gate=undefined;
  // Keep each queue scenario independent within this uniquely owned schema.
  await db.pool.query("UPDATE listener_applications SET state='withdrawn' WHERE state IN ('draft','submitted','needs_information')");
});
after(async()=>{
  storage?.gate?.release.resolve();if(app)await app.close();if(db)await db.close();if(admin){await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.close();}
  if(directory){assert.equal(path.dirname(path.resolve(directory)),path.resolve(os.tmpdir()));assert.ok(path.basename(directory).startsWith('nightshift-staff-review-'));await rm(directory,{recursive:true,force:true});}
});

test('queue pages preserve microsecond tie ordering without repeating or skipping submissions',async()=>{
  const reviewer=await staff(),at=new Date(now-60000).toISOString().replace(/\.\d{3}Z$/,'.000123Z');
  const ids=await bulkSubmitted(41,['ta'],at),seen:string[]=[];let cursor:string|undefined;
  for(let page=0;page<4;page++){
    const result=await review.queue(reviewer.staffActor,{language:'ta',...(cursor?{cursor}:{})});
    assert.equal(result.decisionsEnabled,false);assert.ok(result.items.length<=20);seen.push(...result.items.map(item=>item.id));
    if(!result.nextCursor){cursor=undefined;break;}cursor=result.nextCursor;
  }
  assert.equal(cursor,undefined,'pagination must terminate');assert.equal(seen.length,41);assert.equal(new Set(seen).size,41);
  assert.deepEqual([...seen].sort(),ids.sort());
});

test('queue cursors bind staff session and language, reject tampering, and expire without becoming authority',async()=>{
  const reviewer=await staff(),other=await staff();await bulkSubmitted(22);
  const page=await review.queue(reviewer.staffActor,{language:'ta'});assert.ok(page.nextCursor);const cursor=page.nextCursor!;
  const next=await review.queue(reviewer.staffActor,{language:'ta',cursor});
  assert.deepEqual((await review.queue(reviewer.staffActor,{language:'ta',cursor})).items,next.items,'authorized read retry is stable');
  const tampered=cursor.slice(0,-1)+(cursor.endsWith('0')?'1':'0');
  for(const [actor,query] of [[reviewer.staffActor,{language:'ta',cursor:tampered}],[other.staffActor,{language:'ta',cursor}],[reviewer.staffActor,{language:'en',cursor}]] as const)
    await assert.rejects(review.queue(actor,query),{code:'INVALID_REVIEW_CURSOR'});
  now+=300001;await assert.rejects(review.queue(reviewer.staffActor,{language:'ta',cursor}),{code:'REVIEW_CURSOR_EXPIRED'});
});

test('queue cutoff excludes later submissions while following already issued pages',async()=>{
  const reviewer=await staff(),ids=await bulkSubmitted(21),first=await review.queue(reviewer.staffActor,{language:'ta'});
  const later=await bulkSubmitted(1,['ta'],new Date(now+60000).toISOString());assert.ok(first.nextCursor);
  const second=await review.queue(reviewer.staffActor,{language:'ta',cursor:first.nextCursor});
  const seen=[...first.items,...second.items].map(item=>item.id);assert.equal(seen.includes(later[0]!),false);assert.deepEqual(seen.sort(),ids.sort());
});

test('minimal queue and private detail expose neither account identity nor DOB nor proposed nickname',async()=>{
  const reviewer=await staff(),a=await submitted();
  await db.pool.query("INSERT INTO age_declarations(user_id,date_of_birth) VALUES($1,'1994-01-02')",[a.owner.userId]);
  await db.pool.query("INSERT INTO profiles(user_id,date_of_birth,submitted_display_name,avatar_code,interface_language) VALUES($1,'1994-01-02','PRIVATE_PENDING_NICKNAME','moon','ta')",[a.owner.userId]);
  const queue=await review.queue(reviewer.staffActor),item=queue.items.find(value=>value.id===a.id)!;
  assert.deepEqual(Object.keys(item).sort(),['alias','id','languages','state','submittedAt','voiceSampleAvailable'].sort());
  assert.equal(item.alias,'Public review alias');assert.equal(item.voiceSampleAvailable,true);assert.ok(!JSON.stringify(queue).includes(draft().bio));
  const detail=await review.detail(reviewer.staffActor,a.id);assert.equal(detail.decisionsEnabled,false);assert.equal(detail.application.adultStatus,'self_declared');
  assert.equal(detail.application.bio,draft().bio);assert.deepEqual(detail.application.voiceSample,{contentType:'audio/wav',byteLength:a.bytes.length});
  assert.deepEqual(Object.keys(detail.application).sort(),['id','alias','state','bio','topics','languages','submittedAt','materialVersion','adultStatus','voiceSample'].sort());
  for(const secret of [a.owner.userId,a.owner.uid,a.owner.mobile,a.owner.token,a.uploadId,'1994-01-02','PRIVATE_PENDING_NICKNAME'])assert.ok(!JSON.stringify({queue,detail}).includes(secret));
});

test('known self applications are excluded from queue and deny detail and sample despite all read grants',async()=>{
  const reviewer=await staff(),own=await submitted(reviewer);
  assert.equal((await review.queue(reviewer.staffActor)).items.some(item=>item.id===own.id),false);
  await assert.rejects(review.detail(reviewer.staffActor,own.id),{code:'REVIEW_NOT_AVAILABLE'});
  await assert.rejects(review.sampleBytes(reviewer.staffActor,own.id,'a'.repeat(64)),{code:'REVIEW_NOT_AVAILABLE'});
  assert.equal(await sampleAudit(own.id),0);
});

test('queue permission alone cannot reveal private detail or sample evidence',async()=>{
  const read=await staff(['listener.review.read']),evidence=await staff(['listener.review.evidence.read']),manager=await staff(['staff.access.manage']),a=await submitted();
  assert.equal((await review.queue(read.staffActor)).items.some(item=>item.id===a.id),true);
  await assert.rejects(review.detail(read.staffActor,a.id),{code:'STAFF_FORBIDDEN'});
  await assert.rejects(review.sampleBytes(read.staffActor,a.id,'a'.repeat(64)),{code:'STAFF_FORBIDDEN'});
  for(const actor of [evidence.staffActor,manager.staffActor]){
    await assert.rejects(review.queue(actor),{code:'STAFF_FORBIDDEN'});await assert.rejects(review.detail(actor,a.id),{code:'STAFF_FORBIDDEN'});
    await assert.rejects(review.sampleBytes(actor,a.id,'a'.repeat(64)),{code:'STAFF_FORBIDDEN'});
  }
  assert.equal(await sampleAudit(a.id),0);
});

test('draft, withdrawn, suspended and underage applications never become review material',async()=>{
  const reviewer=await staff(),owner=await account(),draftApp=await applications.create(owner.actor,draft(),randomUUID());
  await assert.rejects(review.detail(reviewer.staffActor,draftApp.id),{code:'REVIEW_NOT_AVAILABLE'});
  for(const restriction of ['withdrawn','suspended','underage']){
    const a=await submitted();
    if(restriction==='withdrawn')await applications.withdraw(a.owner.actor,a.id,randomUUID());
    else await db.pool.query(restriction==='suspended'?'UPDATE users SET suspended=true WHERE id=$1':'UPDATE users SET adult_confirmed=false WHERE id=$1',[a.owner.userId]);
    await assert.rejects(review.detail(reviewer.staffActor,a.id),{code:'REVIEW_NOT_AVAILABLE'});
    assert.equal((await review.queue(reviewer.staffActor)).items.some(item=>item.id===a.id),false);
  }
});

test('withdrawn or absent material consent hides sample metadata and blocks sample reads',async()=>{
  const reviewer=await staff();
  for(const change of ["voice_sample_consent=false","voice_sample_consent=false,consent_version=NULL"]){
    const a=await submitted();await db.pool.query(`UPDATE listener_applications SET ${change} WHERE id=$1`,[a.id]);
    const detail=await review.detail(reviewer.staffActor,a.id);assert.equal(detail.application.voiceSample,null);
    assert.equal((await review.queue(reviewer.staffActor)).items.find(item=>item.id===a.id)!.voiceSampleAvailable,false);
    await assert.rejects(review.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion),{code:'REVIEW_NOT_AVAILABLE'});
  }
});

test('successful private sample read audits the exact material once and changes no business state',async()=>{
  const reviewer=await staff(),a=await submitted(),before=await businessSnapshot();
  await review.queue(reviewer.staffActor);const detail=await review.detail(reviewer.staffActor,a.id);
  const result=await review.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion);
  assert.deepEqual(result.bytes,a.bytes);assert.equal(result.contentType,'audio/wav');assert.equal(result.materialVersion,detail.application.materialVersion);
  assert.deepEqual(await businessSnapshot(),before);
  const rows=(await db.pool.query('SELECT * FROM staff_review_access_events WHERE application_id=$1 ORDER BY created_at,id',[a.id])).rows;
  assert.deepEqual(rows.map(row=>row.action).sort(),['detail.read','queue.read','sample.read']);
  assert.equal(rows.find(row=>row.action==='sample.read').material_version,detail.application.materialVersion);
  assert.ok(rows.every(row=>row.principal_id===reviewer.staffActor.staffId&&row.session_id===reviewer.staffActor.sessionId));
  assert.ok(!JSON.stringify(rows).includes(draft().bio));
  await assert.rejects(db.pool.query("UPDATE staff_review_access_events SET action='queue.read' WHERE application_id=$1",[a.id]),{code:'23514'});
  await assert.rejects(db.pool.query('DELETE FROM staff_review_access_events WHERE application_id=$1',[a.id]),{code:'23514'});
});

test('file absence, corruption and malformed WAV never release bytes or record a sample-read audit',async()=>{
  const reviewer=await staff();
  for(const damage of ['missing','digest','format']){
    const a=await submitted(),file=path.join(directory,`${a.uploadId}.wav`);
    if(damage==='missing')await unlink(file);
    else{const bad=Buffer.from(a.bytes);bad[0]=0;await writeFile(file,bad);if(damage==='format')await db.pool.query('UPDATE listener_review_uploads SET sha256=$2 WHERE id=$1',[a.uploadId,digest(bad)]);}
    const detail=await review.detail(reviewer.staffActor,a.id);
    await assert.rejects(review.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion),{code:damage==='missing'?'REVIEW_NOT_AVAILABLE':'REVIEW_SAMPLE_UNAVAILABLE'});
    assert.equal(await sampleAudit(a.id),0);
  }
});

test('changed submitted material rejects an old version even when the private sample is unchanged',async()=>{
  const reviewer=await staff(),a=await submitted(),old=await review.detail(reviewer.staffActor,a.id);
  await db.pool.query("UPDATE listener_applications SET state='needs_information' WHERE id=$1",[a.id]);
  await applications.update(a.owner.actor,a.id,{...draft(),bio:'Updated submitted biography.'});await applications.submit(a.owner.actor,a.id,randomUUID());
  await assert.rejects(review.sampleBytes(reviewer.staffActor,a.id,old.application.materialVersion),{code:'REVIEW_MATERIAL_CHANGED'});
  const fresh=await review.detail(reviewer.staffActor,a.id);assert.notEqual(fresh.application.materialVersion,old.application.materialVersion);
  assert.deepEqual((await review.sampleBytes(reviewer.staffActor,a.id,fresh.application.materialVersion)).bytes,a.bytes);
  now+=1000;
  await db.pool.query("UPDATE listener_applications SET state='needs_information' WHERE id=$1",[a.id]);
  await applications.submit(a.owner.actor,a.id,randomUUID());
  const revised=await review.detail(reviewer.staffActor,a.id);
  assert.equal(revised.application.bio,fresh.application.bio);
  assert.notEqual(revised.application.materialVersion,fresh.application.materialVersion,'an identical-text resubmission is a new review revision');
  await assert.rejects(review.sampleBytes(reviewer.staffActor,a.id,fresh.application.materialVersion),{code:'REVIEW_MATERIAL_CHANGED'});
});

for(const race of ['staff-grant','provider-disabled','provider-phone-changed','provider-revoked','source-logout','applicant-withdrawal','applicant-deletion','material-change'] as const){
  test(`${race} committed during storage read denies already-buffered private sample`,async t=>{
    const reviewer=await staff(),a=await submitted(),detail=await review.detail(reviewer.staffActor,a.id);
    const gate:Gate={id:a.uploadId,entered:defer(),release:defer()};storage.gate=gate;t.after(()=>{gate.release.resolve();storage.gate=undefined;});
    const pending=review.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion);void pending.catch(()=>{});await gate.entered.promise;
    if(race==='staff-grant')await db.pool.query("UPDATE staff_permission_grants SET revoked_at=GREATEST(granted_at,now()) WHERE principal_id=$1 AND permission='listener.review.evidence.read' AND revoked_at IS NULL",[reviewer.staffActor.staffId]);
    if(race==='provider-disabled')providerUsers.get(reviewer.uid)!.disabled=true;
    if(race==='provider-phone-changed')providerUsers.get(reviewer.uid)!.phoneNumber='+919999888777';
    if(race==='provider-revoked')providerUsers.get(reviewer.uid)!.tokensValidAfterTime=new Date((reviewer.authTime+1)*1000).toISOString();
    if(race==='source-logout')await auth.logout(await auth.authenticate(reviewer.token));
    if(race==='applicant-withdrawal')await applications.withdraw(a.owner.actor,a.id,randomUUID());
    if(race==='applicant-deletion')await new AccountLifecycle(db,()=>now,async()=>{},id=>applications.erasePrivateMaterials(id)).requestDeletion(
      await auth.authenticate(a.owner.token),{noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
    if(race==='material-change'){
      await db.pool.query("UPDATE listener_applications SET state='needs_information' WHERE id=$1",[a.id]);
      await applications.update(a.owner.actor,a.id,{...draft(),topics:['work']});
      // Submit itself reads the same sample; do not gate this independent owner action.
      storage.gate=undefined;await applications.submit(a.owner.actor,a.id,randomUUID());
    }
    gate.release.resolve();
    const code=race==='staff-grant'||race==='source-logout'||race.startsWith('provider-')?'STAFF_UNAUTHENTICATED':race==='material-change'?'REVIEW_MATERIAL_CHANGED':'REVIEW_NOT_AVAILABLE';
    await assert.rejects(pending,{code});assert.equal(await sampleAudit(a.id),0);
  });
}

test('a timed-out storage read retains its capacity slot until actual work settles',async()=>{
  const reviewer=await staff(),a=await submitted(),gate=defer<Buffer>();let reads=0;
  const bounded=new StaffReviewQueries(db,authority,{cursorKey,readTimeoutMs:20,maxConcurrentReads:1,storage:{read(){reads++;return gate.promise;}}},()=>now);
  const detail=await bounded.detail(reviewer.staffActor,a.id);
  try{
    await assert.rejects(bounded.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion),{code:'REVIEW_SAMPLE_UNAVAILABLE'});
    await assert.rejects(bounded.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion),{code:'REVIEW_SAMPLE_BUSY'});assert.equal(reads,1);
  }finally{gate.resolve(a.bytes);}
  await new Promise<void>(resolve=>setImmediate(resolve));
  assert.deepEqual((await bounded.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion)).bytes,a.bytes);assert.equal(reads,2);
});

test('HTTP staff reads require the cookie boundary and never accept ordinary customer bearer authority',async()=>{
  const reviewer=await staff(),customer=await account(),a=await submitted(),readOnly=await staff(['listener.review.read']);
  const route=`${base}/v1/admin/listener-applications`;
  for(const headers of [{},{Authorization:`Bearer ${customer.token}`},{Cookie:`${STAFF_COOKIE}=${'a'.repeat(64)}`}] as Record<string,string>[]){
    const response=await fetch(route,{headers});assert.equal(response.status,401);
    assert.equal((await response.json() as any).error.code,'STAFF_UNAUTHENTICATED');
    assert.match(response.headers.get('cache-control')??'',/no-store/);
  }
  for(const path of [`/${a.id}`,`/${a.id}/voice-sample?version=${'a'.repeat(64)}`]){
    const response=await fetch(route+path,{headers:{Cookie:`${STAFF_COOKIE}=${readOnly.cookie}`}});
    assert.equal(response.status,403);assert.equal((await response.json() as any).error.code,'STAFF_FORBIDDEN');
  }
  const cross=await fetch(route,{headers:{Cookie:`${STAFF_COOKIE}=${reviewer.cookie}`,Origin:'https://other.invalid'}});
  assert.equal(cross.status,403);assert.equal((await cross.json() as any).error.code,'STAFF_ORIGIN_DENIED');
  const duplicate=await fetch(route,{headers:{Cookie:`${STAFF_COOKIE}=${reviewer.cookie}; ${STAFF_COOKIE}=${reviewer.cookie}`}});
  assert.equal(duplicate.status,401);
  await auth.logout(await auth.authenticate(reviewer.token));
  const revoked=await fetch(route,{headers:{Cookie:`${STAFF_COOKIE}=${reviewer.cookie}`}});assert.equal(revoked.status,401);
  assert.equal(await sampleAudit(a.id),0);
});

test('real HTTP queue, detail, errors and complete private WAV match the contract without decision endpoints',async()=>{
  const reviewer=await staff(),a=await submitted(),before=await businessSnapshot();
  const headers={Cookie:`${STAFF_COOKIE}=${reviewer.cookie}`,Origin:policy.origin};
  const route=`${base}/v1/admin/listener-applications`;
  const contract=require('@nightshift/contracts/staff.openapi.json');
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  const validate=(name:string,value:unknown)=>{const check=ajv.compile({$defs:definitions,$ref:`#/$defs/${name}`});assert.equal(check(value),true,JSON.stringify(check.errors));};
  const queued=await fetch(`${route}?language=ta`,{headers});assert.equal(queued.status,200);validate('StaffReviewQueue',await queued.json());
  const detailed=await fetch(`${route}/${a.id}`,{headers}),detail=await detailed.json() as any;
  assert.equal(detailed.status,200);validate('StaffReviewDetail',detail);
  const sample=await fetch(`${route}/${a.id}/voice-sample?version=${detail.application.materialVersion}`,{headers:{...headers,Range:'bytes=0-9','If-None-Match':'*'}});
  assert.equal(sample.status,200);assert.equal(sample.headers.get('content-type'),'audio/wav');
  assert.equal(sample.headers.get('content-length'),String(a.bytes.length));assert.match(sample.headers.get('cache-control')??'',/no-store/);
  assert.equal(sample.headers.get('x-content-type-options'),'nosniff');assert.equal(sample.headers.get('x-review-material-version'),detail.application.materialVersion);
  assert.equal(sample.headers.get('set-cookie'),null);assert.equal(sample.headers.get('access-control-allow-origin'),null);
  assert.equal(sample.headers.get('etag'),null);assert.equal(sample.headers.get('content-range'),null);
  assert.equal(sample.headers.get('location'),null);assert.deepEqual(Buffer.from(await sample.arrayBuffer()),a.bytes);
  for(const path of ['?language=fr','?language=ta&language=en','?limit=100',`/${a.id}?private=true`,
    `/${a.id}/voice-sample`,`/${a.id}/voice-sample?version=${'a'.repeat(64)}&version=${'b'.repeat(64)}`]){
    const response=await fetch(route+path,{headers});assert.equal(response.status,400,path);validate('StaffError',await response.json());
  }
  for(const action of ['approve','reject','needs-information']){
    const response=await fetch(`${route}/${a.id}/${action}`,{method:'POST',headers:{...headers,'Content-Type':'application/json'},body:'{}'});
    assert.equal(response.status,404);
  }
  assert.deepEqual(await businessSnapshot(),before);
});

test('queue excludes resubmitted material after preliminary read even with unchanged language and submitted time',async t=>{
  const reviewer=await staff(),a=await submitted(),entered=defer(),release=defer();
  const originalSubmitted=(await db.pool.query('SELECT submitted_at FROM listener_applications WHERE id=$1',[a.id])).rows[0].submitted_at;
  const original=db.pool.query.bind(db.pool);let intercepted=false;
  const mock=t.mock.method(db.pool,'query',async(...args:any[])=>{
    const result=await (original as any)(...args);
    if(!intercepted&&typeof args[0]==='string'&&args[0].includes('LIMIT 21')){intercepted=true;entered.resolve();await release.promise;}
    return result;
  });
  const pending=review.queue(reviewer.staffActor,{language:'ta'});void pending.catch(()=>{});await entered.promise;
  try{
    // These owner edits preserve both the language filter and original sort key.
    now=Date.now()+1;
    await original("UPDATE listener_applications SET state='needs_information' WHERE id=$1",[a.id]);
    await applications.update(a.owner.actor,a.id,{...draft(),bio:'Changed while the queue was waiting.'});
    await applications.submit(a.owner.actor,a.id,randomUUID());
    assert.deepEqual((await original('SELECT submitted_at FROM listener_applications WHERE id=$1',[a.id])).rows[0].submitted_at,originalSubmitted);
    release.resolve();assert.equal((await pending).items.some(item=>item.id===a.id),false);
    assert.equal((await original("SELECT count(*) FROM staff_review_access_events WHERE application_id=$1 AND action='queue.read'",[a.id])).rows[0].count,'0');
  }finally{release.resolve();mock.mock.restore();}
});

test('private sample capacity remains bounded after storage returns while provider revalidation waits',async t=>{
  const reviewer=await staff(),a=await submitted(),entered=defer(),release=defer();let reads=0;
  const bounded=new StaffReviewQueries(db,authority,{cursorKey,maxConcurrentReads:1,storage:{async read(id){reads++;return storage.read(id);}}},()=>now);
  const detail=await bounded.detail(reviewer.staffActor,a.id),original=verifier.currentIdentity.bind(verifier);
  const mock=t.mock.method(verifier,'currentIdentity',async(ref:Parameters<typeof original>[0])=>{const result=await original(ref);entered.resolve();await release.promise;return result;});
  const pending=bounded.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion);void pending.catch(()=>{});await entered.promise;
  try{
    await assert.rejects(bounded.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion),{code:'REVIEW_SAMPLE_BUSY'});
    assert.equal(reads,1);release.resolve();assert.deepEqual((await pending).bytes,a.bytes);
  }finally{release.resolve();mock.mock.restore();}
  assert.deepEqual((await bounded.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion)).bytes,a.bytes);
  assert.equal(reads,2);
});
