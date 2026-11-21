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
import {NightShiftService} from '../src/service';
import {PhoneAuthentication} from '../src/identity/phone-auth';
import {FirebaseIdentityProvider} from '../src/identity/firebase';
import {StaffAuthority,StaffPermission} from '../src/staff/authority';
import {StaffAppBinding} from '../src/staff/app-binding';
import {FirebaseStaffVerifier} from '../src/staff/firebase';
import {StaffPolicy} from '../src/staff/verifier';
import {StaffReviewQueries} from '../src/staff/review-queries';
import {StaffReviewController} from '../src/staff/review-http';
import {StaffReviewDecisions} from '../src/staff/review-decisions';
import {StaffReviewDecisionController} from '../src/staff/review-decision-http';
import {ApprovedReviewPolicy,ReviewOutcome} from '../src/staff/review-policy';
import {loadApprovedReviewPolicy} from '../src/staff/review-factory';
import {STAFF_COOKIE} from '../src/staff/http';
import {ListenerApplications,LocalReviewStorage} from '../src/listener-applications';
import {AccountLifecycle,DELETION_NOTICE_VERSION} from '../src/account-lifecycle';

const schema=`review_decisions_${randomUUID().replaceAll('-','')}`,project='staff-decision-fixture';
const digest=(value:Buffer|string)=>createHash('sha256').update(value).digest('hex');
const key=randomBytes(32).toString('hex'),cursorKey=randomBytes(32).toString('hex');
const signing=generateKeyPairSync('ed25519'),encode=(value:unknown)=>Buffer.from(JSON.stringify(value)).toString('base64url');
const providerUsers=new Map<string,{uid:string;phoneNumber:string;disabled:boolean;tokensValidAfterTime?:string}>();
let now=Date.now(),sequence=2000,db:Database,admin:Database,auth:Auth,phone:PhoneAuthentication,authority:StaffAuthority;
let applications:ListenerApplications,review:StaffReviewQueries,storage:ControlledStorage,directory:string;
let decisions:StaffReviewDecisions;
let app:Awaited<ReturnType<typeof NestFactory.create>>,base:string;
const config:Config={databaseUrl:'',redisUrl:'',port:0,devAccessKey:'synthetic-review-read-test-key',phoneAuth:{provider:'firebase',projectId:project,
  digestKey:key,consentVersion:'fixture-v1',dailyAdmissionLimit:1000}};
const policy:StaffPolicy={issuer:`https://securetoken.google.com/${project}`,audience:project,tenant:'',origin:'https://review-fixture.invalid',
  version:'review-fixture-v1',digestKey:randomBytes(32).toString('hex'),requiredMethods:['sms'],requireAppBinding:true,
  maxAuthenticationAgeSeconds:3600,sessionSeconds:1800,challengeSeconds:120,challengeLimitPerHour:1000,clientChallengeLimitPerHour:100,
  verificationTimeoutMs:500,maxConcurrentVerifications:4};
// This policy is confined to isolated signed fixtures, never normal bootstrap.
const approvedPolicy:ApprovedReviewPolicy={version:'synthetic_review_v1',approvalReference:'isolated-test-only-no-real-review-approval',
  checks:[
    {id:'declaration',label:{en:'Self-declaration reviewed; identity is not verified',ta:'சுய அறிவிப்பு மட்டும்; அடையாளச் சான்று அல்ல'},requiredForApproval:true,evidenceKinds:['self_declaration']},
    {id:'introduction',label:{en:'Synthetic introduction reviewed',ta:'சோதனை அறிமுகம் மதிப்பாய்வு'},requiredForApproval:true,evidenceKinds:['application']},
    {id:'communication',label:{en:'Synthetic communication sample reviewed',ta:'சோதனை குரல் மாதிரி மதிப்பாய்வு'},requiredForApproval:true,evidenceKinds:['voice_sample']}
  ],reasons:{
    approved:[{code:'complete',label:{en:'Fixture checks complete',ta:'சோதனை சரிபார்ப்புகள் முடிந்தன'},message:{en:'Your test application was approved.',ta:'உங்கள் சோதனை விண்ணப்பம் ஏற்கப்பட்டது.'}}],
    rejected:[{code:'incomplete',label:{en:'Fixture criteria unmet',ta:'சோதனை விதிகள் நிறைவேறவில்லை'},message:{en:'Your test application was not approved.',ta:'உங்கள் சோதனை விண்ணப்பம் ஏற்கப்படவில்லை.'}}],
    needs_information:[{code:'clarify',label:{en:'Fixture clarification required',ta:'சோதனை விளக்கம் தேவை'},message:{en:'Update the listed test checks and resubmit.',ta:'குறிப்பிட்ட சோதனைகளைப் புதுப்பித்து மீண்டும் அனுப்பவும்.'}}]
  }};
const defer=<T=void>()=>{let resolve!:(value?:T)=>void;const promise=new Promise<T>(r=>{resolve=value=>r(value as T);});return{resolve,promise};};
function validateDto(name:string,value:unknown,staffContract=true){
  const schema=require(staffContract?'@nightshift/contracts/staff.openapi.json':'@nightshift/contracts/openapi.json');
  const definitions=JSON.parse(JSON.stringify(schema.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  const check=ajv.compile({$defs:definitions,$ref:`#/$defs/${name}`});assert.equal(check(value),true,JSON.stringify(check.errors));
}
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
async function staff(permissions:StaffPermission[]=['listener.review.read','listener.review.evidence.read','listener.review.decide']){
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
async function decisionBody(reviewer:Awaited<ReturnType<typeof staff>>,a:Awaited<ReturnType<typeof submitted>>,outcome:ReviewOutcome='approved'){
  const detail=await review.detail(reviewer.staffActor,a.id);
  await review.sampleBytes(reviewer.staffActor,a.id,detail.application.materialVersion);
  // Database submission time has microseconds; advance the injected decision
  // clock beyond the completed fixture writes instead of backdating decisions.
  now=Math.max(now,Date.now()+1);
  const configured=await decisions.policy();
  return{expectedMaterialVersion:detail.application.materialVersion,policyVersion:approvedPolicy.version,policyDigest:configured.digest,
    outcome,checks:approvedPolicy.checks.map(check=>({id:check.id,result:outcome==='approved'?'pass':'fail',evidenceKinds:[...check.evidenceKinds]})),
    reasonCode:approvedPolicy.reasons[outcome][0]!.code};
}
async function effectCounts(decisionId:string){
  const count=async(table:string)=>Number((await db.pool.query(`SELECT count(*) FROM ${table} WHERE decision_id=$1`,[decisionId])).rows[0].count);
  return{events:await count('listener_review_outbox'),entitlements:await count('listener_review_entitlements'),notices:await count('listener_review_notifications')};
}
async function effects(decisionId:string){return(await db.pool.query('SELECT consumer,state,reason_code FROM listener_review_effects WHERE event_id=(SELECT id FROM listener_review_outbox WHERE decision_id=$1) ORDER BY consumer',[decisionId])).rows;}
async function moneySnapshot(){
  const tables=['journal_batches','journal_lines','wallet_accounts','outbox_events'];const result:Record<string,unknown>={};
  for(const table of tables)result[table]=(await db.pool.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) value FROM ${table} t`)).rows[0].value;
  return result;
}
async function businessSnapshot(){
  const tables=['users','listener_applications','listener_reviews','listener_review_uploads','staff_permission_grants','journal_batches','journal_lines','wallet_accounts','outbox_events',
    'listener_review_policy_versions','listener_review_decisions','listener_review_outbox','listener_review_effects','listener_review_entitlements','listener_review_notifications'];
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
  decisions=new StaffReviewDecisions(db,authority,review,approvedPolicy,()=>now);
  @Module({controllers:[StaffReviewController,StaffReviewDecisionController],providers:[{provide:StaffAuthority,useValue:authority},{provide:StaffReviewQueries,useValue:review},{provide:StaffReviewDecisions,useValue:decisions}]}) class FixtureModule{}
  app=await NestFactory.create(FixtureModule,{logger:false});await app.listen(0,'127.0.0.1');base=await app.getUrl();
});

test('normal decision service has no configured policy and cannot create decisions, grants or notices',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),before=await businessSnapshot();
  const off=new StaffReviewDecisions(db,authority,review,undefined,()=>now);
  await assert.rejects(off.decide(reviewer.staffActor,a.id,body,randomUUID()),{code:'REVIEW_POLICY_UNAVAILABLE'});
  assert.deepEqual(await off.processPending(),{processed:0});assert.deepEqual(await businessSnapshot(),before);
});

test('read and evidence grants without decide never authorize approval',async()=>{
  const reviewer=await staff(['listener.review.read','listener.review.evidence.read']),a=await submitted(),body=await decisionBody(reviewer,a),before=await businessSnapshot();
  await assert.rejects(decisions.decide(reviewer.staffActor,a.id,body,randomUUID()),{code:'STAFF_FORBIDDEN'});
  assert.deepEqual(await businessSnapshot(),before);
});

test('approval commits one immutable reasoned decision and event, then one grant and owner notice without money or automatic availability',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),money=await moneySnapshot();
  const receipt=await decisions.decide(reviewer.staffActor,a.id,body,randomUUID());
  assert.equal(receipt.applicationId,a.id);assert.equal(receipt.outcome,'approved');assert.equal(receipt.recordedAt,new Date(now).toISOString());
  assert.deepEqual(receipt.effects,{entitlement:'pending',notification:'pending'});
  assert.deepEqual(await effectCounts(receipt.decisionId),{events:1,entitlements:0,notices:0});
  assert.deepEqual((await db.pool.query('SELECT listener_approved,mode,desired_online FROM users WHERE id=$1',[a.owner.userId])).rows[0],{listener_approved:false,mode:'customer',desired_online:false});
  const row=(await db.pool.query('SELECT * FROM listener_review_decisions WHERE id=$1',[receipt.decisionId])).rows[0];
  assert.equal(row.principal_id,reviewer.staffActor.staffId);assert.equal(row.session_id,reviewer.staffActor.sessionId);
  assert.equal(row.material_version,body.expectedMaterialVersion);assert.equal(row.policy_version,approvedPolicy.version);assert.equal(row.reason_code,'complete');
  assert.deepEqual(row.checks.map((check:any)=>({id:check.id,result:check.result,evidenceKinds:check.evidence.map((e:any)=>e.kind)})),[...body.checks].sort((a,b)=>a.id.localeCompare(b.id)));
  for(const check of row.checks)for(const evidence of check.evidence){
    const access=(await db.pool.query('SELECT principal_id,application_id,material_version,action FROM staff_review_access_events WHERE id=$1',[evidence.accessEventId])).rows[0];
    assert.deepEqual(access,{principal_id:reviewer.staffActor.staffId,application_id:a.id,material_version:body.expectedMaterialVersion,action:evidence.kind==='voice_sample'?'sample.read':'detail.read'});
  }
  assert.deepEqual(await decisions.processPending(),{processed:2});
  assert.deepEqual(await effectCounts(receipt.decisionId),{events:1,entitlements:1,notices:1});
  assert.deepEqual((await db.pool.query('SELECT listener_approved,mode,desired_online FROM users WHERE id=$1',[a.owner.userId])).rows[0],{listener_approved:true,mode:'customer',desired_online:false});
  assert.deepEqual(await moneySnapshot(),money);
  const status=await decisions.ownerStatus(a.owner.actor);assert.equal(status.applicationId,a.id);assert.equal(status.review!.entitlement,'active');assert.ok(status.review!.notification);
  validateDto('ListenerReviewState',status,false);
  assert.deepEqual(status.review!.message,approvedPolicy.reasons.approved[0]!.message);
  const serialized=JSON.stringify(status);for(const hidden of [reviewer.staffActor.staffId,reviewer.uid,reviewer.mobile,approvedPolicy.approvalReference])assert.ok(!serialized.includes(hidden));
  for(const table of ['listener_review_decisions','listener_review_policy_versions','listener_review_outbox','listener_review_entitlements']){
    await assert.rejects(db.pool.query(`DELETE FROM ${table}`),{code:'23514'});
  }
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

test('stale policy and material cannot commit decisions against previously viewed evidence',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),before=await businessSnapshot();
  for(const change of [{policyVersion:'superseded_fixture'},{policyDigest:'0'.repeat(64)}])
    await assert.rejects(decisions.decide(reviewer.staffActor,a.id,{...body,...change},randomUUID()),{code:'REVIEW_POLICY_CHANGED'});
  assert.deepEqual(await businessSnapshot(),before);
  now+=1000;await db.pool.query("UPDATE listener_applications SET state='needs_information' WHERE id=$1",[a.id]);
  await applications.update(a.owner.actor,a.id,{...draft(),bio:'New owner-submitted evidence.'});await applications.submit(a.owner.actor,a.id,randomUUID());
  const revised=await businessSnapshot();
  await assert.rejects(decisions.decide(reviewer.staffActor,a.id,body,randomUUID()),{code:'REVIEW_MATERIAL_CHANGED'});
  assert.deepEqual(await businessSnapshot(),revised);
});

test('required check failures, omissions, duplicates and unauthorized evidence kinds are rejected without writes',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),before=await businessSnapshot();
  const invalid=[
    {...body,checks:body.checks.slice(1)},
    {...body,checks:[...body.checks,body.checks[0]]},
    {...body,checks:body.checks.map((check,i)=>i===0?{...check,result:'fail'}:check)},
    {...body,checks:body.checks.map((check,i)=>i===0?{...check,result:'not_checked'}:check)},
    {...body,checks:body.checks.map((check,i)=>i===0?{...check,evidenceKinds:['voice_identity_proof']}:check)},
    {...body,reasonCode:'unapproved_reason'}
  ];
  for(const input of invalid)await assert.rejects(decisions.decide(reviewer.staffActor,a.id,input,randomUUID()),{code:'INVALID_REVIEW_DECISION'});
  await assert.rejects(decisions.decide(reviewer.staffActor,a.id,{...body,privateNotes:'No arbitrary private notes'},randomUUID()),{code:'INVALID_FIELD'});
  assert.deepEqual(await businessSnapshot(),before);
});

test('a matching decision retry is idempotent and changed payload under the same key conflicts',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),requestKey=randomUUID();
  const first=await decisions.decide(reviewer.staffActor,a.id,body,requestKey);
  assert.deepEqual(await decisions.decide(reviewer.staffActor,a.id,body,requestKey),first);
  await assert.rejects(decisions.decide(reviewer.staffActor,a.id,{...body,outcome:'rejected',reasonCode:'incomplete'},requestKey),{code:'IDEMPOTENCY_CONFLICT'});
  assert.deepEqual(await decisions.receipt(reviewer.staffActor,a.id,requestKey),first);
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:0,notices:0});
  await decisions.processPending();
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
});

test('current authorization is rechecked before any cached decision receipt is returned',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),requestKey=randomUUID();
  await decisions.decide(reviewer.staffActor,a.id,body,requestKey);await decisions.processPending();
  await auth.logout(await auth.authenticate(reviewer.token));const before=await businessSnapshot();
  await assert.rejects(decisions.decide(reviewer.staffActor,a.id,body,requestKey),{code:'STAFF_UNAUTHENTICATED'});
  await assert.rejects(decisions.receipt(reviewer.staffActor,a.id,requestKey),{code:'STAFF_UNAUTHENTICATED'});
  assert.deepEqual(await businessSnapshot(),before);
});

test('decision receipts remain recoverable with policy disabled but new decisions and consumers stay disabled',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),requestKey=randomUUID();
  const first=await decisions.decide(reviewer.staffActor,a.id,body,requestKey),off=new StaffReviewDecisions(db,authority,review,undefined,()=>now);
  assert.deepEqual(await off.receipt(reviewer.staffActor,a.id,requestKey),first);
  assert.deepEqual(await off.decide(reviewer.staffActor,a.id,body,requestKey),first);
  await assert.rejects(off.decide(reviewer.staffActor,a.id,body,randomUUID()),{code:'REVIEW_POLICY_UNAVAILABLE'});
  assert.deepEqual(await off.processPending(),{processed:0});assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:0,notices:0});
  await decisions.processPending();assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
});

test('concurrent consumers and a new worker instance produce exactly one grant and notification',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),requestKey=randomUUID();
  const first=await decisions.decide(reviewer.staffActor,a.id,body,requestKey);
  const restarted=new StaffReviewDecisions(db,authority,review,approvedPolicy,()=>now);
  const results=await Promise.all([decisions.processPending(),restarted.processPending()]);
  assert.equal(results.reduce((sum,result)=>sum+result.processed,0),2);
  assert.deepEqual(await restarted.processPending(),{processed:0});
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
  assert.deepEqual((await effects(first.decisionId)).map(row=>({consumer:row.consumer,state:row.state})),[{consumer:'entitlement',state:'applied'},{consumer:'notification',state:'applied'}]);
  const recovered=await restarted.receipt(reviewer.staffActor,a.id,requestKey);assert.deepEqual(recovered.effects,{entitlement:'active',notification:'available'});
});

test('account deletion before event processing withholds entitlement and suppresses private notification',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a);
  const first=await decisions.decide(reviewer.staffActor,a.id,body,randomUUID());
  await new AccountLifecycle(db,()=>now,async()=>{},id=>applications.erasePrivateMaterials(id)).requestDeletion(await auth.authenticate(a.owner.token),
    {noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
  await decisions.processPending();assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:0,notices:0});
  assert.deepEqual((await effects(first.decisionId)).map(row=>({consumer:row.consumer,state:row.state})),[{consumer:'entitlement',state:'withheld'},{consumer:'notification',state:'suppressed'}]);
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[a.owner.userId])).rows[0].listener_approved,false);
  await assert.rejects(decisions.ownerStatus(a.owner.actor),{code:'UNAUTHENTICATED'});
});

test('deletion erases an available notification and event replay cannot restore removed access',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a);
  const first=await decisions.decide(reviewer.staffActor,a.id,body,randomUUID());await decisions.processPending();
  await new AccountLifecycle(db,()=>now,async()=>{},id=>applications.erasePrivateMaterials(id)).requestDeletion(await auth.authenticate(a.owner.token),
    {noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
  assert.deepEqual(await decisions.processPending(),{processed:0});
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:0});
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[a.owner.userId])).rows[0].listener_approved,false);
});

test('known self and linked-account conflicts deny decisions and cached receipts',async()=>{
  const reviewer=await staff(),a=await submitted(),body=await decisionBody(reviewer,a),own=await submitted(reviewer),requestKey=randomUUID();
  await assert.rejects(decisions.decide(reviewer.staffActor,own.id,body,randomUUID()),{code:'REVIEW_CONFLICT'});
  const first=await decisions.decide(reviewer.staffActor,a.id,body,requestKey);await decisions.processPending();
  await db.pool.query("INSERT INTO staff_review_conflicts(principal_id,user_id,reason_code,source_reference) VALUES($1,$2,'known_self','synthetic-declared-related-account')",[reviewer.staffActor.staffId,a.owner.userId]);
  const before=await businessSnapshot();
  await assert.rejects(decisions.decide(reviewer.staffActor,a.id,body,requestKey),{code:'REVIEW_CONFLICT'});
  await assert.rejects(decisions.receipt(reviewer.staffActor,a.id,requestKey),{code:'REVIEW_CONFLICT'});
  assert.deepEqual(await businessSnapshot(),before);assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
  await assert.rejects(db.pool.query('DELETE FROM staff_review_conflicts WHERE principal_id=$1',[reviewer.staffActor.staffId]),{code:'23514'});
});

test('two staff decisions on the same material have one winner and one durable outcome',async()=>{
  const one=await staff(),two=await staff(),a=await submitted();
  const yes=await decisionBody(one,a),no=await decisionBody(two,a,'rejected');
  const results=await Promise.allSettled([decisions.decide(one.staffActor,a.id,yes,randomUUID()),decisions.decide(two.staffActor,a.id,no,randomUUID())]);
  const success=results.filter(result=>result.status==='fulfilled') as PromiseFulfilledResult<Awaited<ReturnType<StaffReviewDecisions['decide']>>>[];
  assert.equal(success.length,1);assert.equal((results.find(result=>result.status==='rejected') as PromiseRejectedResult).reason.code,'REVIEW_ALREADY_DECIDED');
  const receipt=success[0]!.value;assert.equal((await db.pool.query('SELECT count(*) FROM listener_review_decisions WHERE application_id=$1',[a.id])).rows[0].count,'1');
  await decisions.processPending();assert.deepEqual(await effectCounts(receipt.decisionId),{events:1,entitlements:receipt.outcome==='approved'?1:0,notices:1});
});

test('needs-information exposes only approved localized guidance and a resubmission requires fresh evidence',async()=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a,'needs_information');
  input.checks=input.checks.map((check,i)=>({...check,result:i===2?'not_checked':'pass',evidenceKinds:i===2?[]:check.evidenceKinds}));
  const first=await decisions.decide(reviewer.staffActor,a.id,input,randomUUID());await decisions.processPending();
  const status=await decisions.ownerStatus(a.owner.actor);assert.equal(status.state,'needs_information');assert.equal(status.review!.entitlement,'not_applicable');
  assert.deepEqual(status.review!.message,approvedPolicy.reasons.needs_information[0]!.message);
  assert.deepEqual(status.review!.missingChecks,[{id:'communication',label:approvedPolicy.checks[2]!.label}]);
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:0,notices:1});
  now+=1000;await applications.update(a.owner.actor,a.id,{...draft(),bio:'Resubmitted after synthetic clarification.'});await applications.submit(a.owner.actor,a.id,randomUUID());
  assert.equal((await decisions.ownerStatus(a.owner.actor)).review,null);
  await assert.rejects(decisions.decide(reviewer.staffActor,a.id,{...input,outcome:'approved',reasonCode:'complete'},randomUUID()),{code:'REVIEW_MATERIAL_CHANGED'});
  const current=await decisionBody(reviewer,a),second=await decisions.decide(reviewer.staffActor,a.id,current,randomUUID());
  assert.notEqual(second.decisionId,first.decisionId);await decisions.processPending();
  assert.equal((await decisions.ownerStatus(a.owner.actor)).review!.entitlement,'active');
  assert.deepEqual(await effectCounts(second.decisionId),{events:1,entitlements:1,notices:1});
});

test('receipts and applicant result reads do not cross account or staff ownership',async()=>{
  const reviewer=await staff(),other=await staff(),a=await submitted(),stranger=await account(),input=await decisionBody(reviewer,a),requestKey=randomUUID();
  await decisions.decide(reviewer.staffActor,a.id,input,requestKey);await decisions.processPending();
  await assert.rejects(decisions.receipt(other.staffActor,a.id,requestKey),{code:'REVIEW_DECISION_NOT_FOUND'});
  assert.deepEqual(await decisions.ownerStatus(stranger.actor),{applicationId:null,state:null,review:null});
  await auth.logout(await auth.authenticate(a.owner.token));
  await assert.rejects(decisions.ownerStatus(a.owner.actor),{code:'UNAUTHENTICATED'});
});

test('private sample withdrawal after approval preserves the outcome and does not require indefinite audio retention',async()=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a);
  const first=await decisions.decide(reviewer.staffActor,a.id,input,randomUUID());
  await applications.withdraw(a.owner.actor,a.id,randomUUID());
  await decisions.processPending();assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
  assert.equal((await decisions.ownerStatus(a.owner.actor)).review!.entitlement,'active');
  assert.equal((await db.pool.query('SELECT voice_sample_consent FROM listener_applications WHERE id=$1',[a.id])).rows[0].voice_sample_consent,false);
  await assert.rejects(storage.read(a.uploadId),{status:404});
});

test('an interrupted consumer transaction rolls back projection and receipts, and a replacement worker completes once',async t=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a);
  const first=await decisions.decide(reviewer.staffActor,a.id,input,randomUUID()),original=db.tx.bind(db);let interrupted=0;
  const mock=t.mock.method(db,'tx',async(fn:Parameters<Database['tx']>[0])=>original(async client=>{
    await fn(client);interrupted++;throw Error('Synthetic process loss immediately before transaction commit');
  }));
  try{await decisions.processPending().catch(()=>{});assert.ok(interrupted>0);}
  finally{mock.mock.restore();}
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:0,notices:0});
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[a.owner.userId])).rows[0].listener_approved,false);
  assert.ok((await effects(first.decisionId)).every(row=>row.state==='pending'));
  const replacement=new StaffReviewDecisions(db,authority,review,approvedPolicy,()=>now);
  assert.deepEqual(await replacement.processPending(),{processed:2});assert.deepEqual(await replacement.processPending(),{processed:0});
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
});

for(const race of ['grant','source_logout','applicant_deletion','conflict'] as const){
  test(`${race} before final decision authorization denies stale work without a decision or event`,async t=>{
    const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a),entered=defer(),release=defer();
    const original=authority.authorize.bind(authority);let gated=false;
    const mock=t.mock.method(authority,'authorize',async(...args:Parameters<typeof original>)=>{
      if(!gated&&args[2]==='listener.review.decide'){gated=true;entered.resolve();await release.promise;}
      return original(...args);
    });
    const pending=decisions.decide(reviewer.staffActor,a.id,input,randomUUID());void pending.catch(()=>{});await entered.promise;
    try{
      if(race==='grant')await db.pool.query("UPDATE staff_permission_grants SET revoked_at=GREATEST(granted_at,now()) WHERE principal_id=$1 AND permission='listener.review.decide'",[reviewer.staffActor.staffId]);
      if(race==='source_logout')await auth.logout(await auth.authenticate(reviewer.token));
      if(race==='applicant_deletion')await new AccountLifecycle(db,()=>now,async()=>{},id=>applications.erasePrivateMaterials(id)).requestDeletion(await auth.authenticate(a.owner.token),
        {noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:randomBytes(32).toString('hex')});
      if(race==='conflict')await db.pool.query("INSERT INTO staff_review_conflicts(principal_id,user_id,reason_code,source_reference) VALUES($1,$2,'known_self','synthetic-racing-conflict')",[reviewer.staffActor.staffId,a.owner.userId]);
      release.resolve();
      await assert.rejects(pending,{code:race==='conflict'?'REVIEW_CONFLICT':race==='applicant_deletion'?'REVIEW_NOT_AVAILABLE':'STAFF_UNAUTHENTICATED'});
      assert.equal((await db.pool.query('SELECT count(*) FROM listener_review_decisions WHERE application_id=$1',[a.id])).rows[0].count,'0');
    }finally{release.resolve();mock.mock.restore();}
  });
}

test('HTTP decisions require current staff cookies, exact Origin, CSRF and one idempotency key',async()=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a),requestKey=randomUUID();
  const route=`${base}/v1/admin/listener-applications/${a.id}/decisions`;
  const headers:Record<string,string>={Cookie:`${STAFF_COOKIE}=${reviewer.cookie}`,Origin:policy.origin,'X-CSRF-Token':reviewer.staffView.csrfToken,'Content-Type':'application/json','Idempotency-Key':requestKey};
  const policyResponse=await fetch(`${base}/v1/admin/listener-review-policy`,{headers});assert.equal(policyResponse.status,200);
  validateDto('StaffReviewPolicy',await policyResponse.json());validateDto('StaffReviewDecision',input);
  for(const missing of ['Cookie','Origin','X-CSRF-Token']){
    const without={...headers};delete without[missing];const response=await fetch(route,{method:'POST',headers:without,body:JSON.stringify(input)});
    assert.equal(response.status,403);assert.equal((await db.pool.query('SELECT count(*) FROM listener_review_decisions WHERE application_id=$1',[a.id])).rows[0].count,'0');
  }
  const forged=await fetch(route,{method:'POST',headers:{...headers,Origin:'https://other.invalid'},body:JSON.stringify(input)});assert.equal(forged.status,403);
  const missingKey={...headers};delete missingKey['Idempotency-Key'];
  const noKey=await fetch(route,{method:'POST',headers:missingKey,body:JSON.stringify(input)});assert.equal(noKey.status,400);
  const accepted=await fetch(route,{method:'POST',headers,body:JSON.stringify(input)}),receipt=await accepted.json() as any;
  assert.equal(accepted.status,200);assert.equal(accepted.headers.get('cache-control'),'no-store');assert.equal(accepted.headers.get('set-cookie'),null);
  validateDto('StaffReviewReceipt',receipt);
  const recovered=await fetch(`${base}/v1/admin/listener-applications/${a.id}/decision-receipt`,{headers});
  assert.equal(recovered.status,200);assert.deepEqual(await recovered.json(),receipt);
  const repeated=await fetch(route,{method:'POST',headers,body:JSON.stringify(input)});assert.equal(repeated.status,200);assert.deepEqual(await repeated.json(),receipt);
  await decisions.processPending();assert.deepEqual(await effectCounts(receipt.decisionId),{events:1,entitlements:1,notices:1});
});

test('a configured policy must be explicit, bounded, valid and detached from caller mutation',async()=>{
  assert.equal(await loadApprovedReviewPolicy(),undefined);
  await assert.rejects(loadApprovedReviewPolicy('relative-policy.json'),{code:'REVIEW_POLICY_UNAVAILABLE'});
  await assert.rejects(loadApprovedReviewPolicy(path.join(directory,'absent.json')),{code:'REVIEW_POLICY_UNAVAILABLE'});
  const file=path.join(directory,`${randomUUID()}.json`);
  for(const bytes of ['{',JSON.stringify({...approvedPolicy,approvalReference:''}),JSON.stringify({...approvedPolicy,unexpected:true}),
    JSON.stringify({...approvedPolicy,checks:[approvedPolicy.checks[0],approvedPolicy.checks[0]]}), ' '.repeat(524289)]){
    await writeFile(file,bytes);await assert.rejects(loadApprovedReviewPolicy(file),{code:'REVIEW_POLICY_UNAVAILABLE'});
  }
  await writeFile(file,JSON.stringify(approvedPolicy));const loaded=(await loadApprovedReviewPolicy(file))!;
  assert.deepEqual(loaded,approvedPolicy);
  const service=new StaffReviewDecisions(db,authority,review,loaded,()=>now),before=service.policy();
  loaded.checks[0]!.label.en='Caller changes must not rewrite approved policy';loaded.reasons.approved[0]!.message.en='Changed outside the service';
  assert.deepEqual(service.policy(),before);assert.ok(!JSON.stringify(before).includes(approvedPolicy.approvalReference));
  await unlink(file);
});

test('policy rotation governs new decisions while preserving committed outcomes from an immutable previous policy',async()=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a),requestKey=randomUUID();
  const first=await decisions.decide(reviewer.staffActor,a.id,input,requestKey);
  const nextPolicy=structuredClone(approvedPolicy);nextPolicy.version='synthetic_review_v2';nextPolicy.approvalReference='isolated-approved-second-version';
  const rotated=new StaffReviewDecisions(db,authority,review,nextPolicy,()=>now);
  assert.deepEqual(await rotated.receipt(reviewer.staffActor,a.id,requestKey),first);
  assert.deepEqual(await rotated.processPending(),{processed:2});
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
  const b=await submitted(),oldInput=await decisionBody(reviewer,b),before=await businessSnapshot();
  await assert.rejects(rotated.decide(reviewer.staffActor,b.id,oldInput,randomUUID()),{code:'REVIEW_POLICY_CHANGED'});
  assert.deepEqual(await businessSnapshot(),before);
  const next=await rotated.decide(reviewer.staffActor,b.id,{...oldInput,policyVersion:nextPolicy.version,policyDigest:rotated.policy().digest},randomUUID());
  assert.equal(next.policyVersion,nextPolicy.version);await rotated.processPending();
  assert.deepEqual(await effectCounts(next.decisionId),{events:1,entitlements:1,notices:1});
  const rewritten=structuredClone(approvedPolicy);rewritten.checks[0]!.label.en='Changed under the same approved version';
  const changed=new StaffReviewDecisions(db,authority,review,rewritten,()=>now),c=await submitted(),body=await decisionBody(reviewer,c),snapshot=await businessSnapshot();
  await assert.rejects(changed.decide(reviewer.staffActor,c.id,{...body,policyDigest:changed.policy().digest},randomUUID()),{code:'REVIEW_POLICY_CHANGED'});
  assert.deepEqual(await businessSnapshot(),snapshot);
});

test('later reviewer authority revocation prevents receipt access but does not cancel an already committed valid decision',async()=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a),requestKey=randomUUID();
  const first=await decisions.decide(reviewer.staffActor,a.id,input,requestKey);
  await db.pool.query("UPDATE staff_permission_grants SET revoked_at=GREATEST(granted_at,now()) WHERE principal_id=$1",[reviewer.staffActor.staffId]);
  await auth.logout(await auth.authenticate(reviewer.token));
  await assert.rejects(decisions.receipt(reviewer.staffActor,a.id,requestKey),{code:'STAFF_UNAUTHENTICATED'});
  assert.deepEqual(await decisions.processPending(),{processed:2});
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
  assert.equal((await decisions.ownerStatus(a.owner.actor)).review!.entitlement,'active');
});

test('an approval pending consumption prevents a second application and later projection revocation survives replay',async()=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a),requestKey=randomUUID();
  const first=await decisions.decide(reviewer.staffActor,a.id,input,requestKey),before=await businessSnapshot();
  await assert.rejects(applications.create(a.owner.actor,draft(),randomUUID()),{code:'APPLICATION_EXISTS'});
  assert.deepEqual(await businessSnapshot(),before);
  await decisions.processPending();
  await db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[a.owner.userId]);
  assert.equal((await decisions.ownerStatus(a.owner.actor)).review!.entitlement,'withheld');
  assert.equal((await decisions.receipt(reviewer.staffActor,a.id,requestKey)).effects.entitlement,'withheld');
  assert.equal((await decisions.decide(reviewer.staffActor,a.id,input,requestKey)).effects.entitlement,'withheld');
  assert.deepEqual(await new StaffReviewDecisions(db,authority,review,approvedPolicy,()=>now).processPending(),{processed:0});
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[a.owner.userId])).rows[0].listener_approved,false);
  assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:1,notices:1});
});

test('same-clock needs-information rounds return the current missing checks regardless of UUID ordering',async t=>{
  const reviewer=await staff(),a=await submitted(),firstInput=await decisionBody(reviewer,a,'needs_information');
  // Both decisions intentionally have identical server time. A random UUID is
  // not chronology; force the second UUID to sort before the first one.
  const fixed=now=Date.now()+5000;
  firstInput.checks=firstInput.checks.map((check,i)=>({...check,result:i===2?'not_checked':'pass',evidenceKinds:i===2?[]:check.evidenceKinds}));
  const fixedDecision=async(id:string,input:typeof firstInput)=>{
    const crypto=require('node:crypto') as typeof import('node:crypto'),original=crypto.randomUUID.bind(crypto);let first=true,restore=()=>{};
    const authorize=authority.authorize.bind(authority);
    // The real authorization writes its own independent audit UUID first.
    const authorized=t.mock.method(authority,'authorize',async(...args:Parameters<typeof authorize>)=>{
      const view=await authorize(...args);
      if(args[2]==='listener.review.decide'){
        const mocked=t.mock.method(crypto,'randomUUID',()=>{if(first){first=false;return id as ReturnType<typeof randomUUID>;}return original();});
        restore=()=>mocked.mock.restore();
      }
      return view;
    });
    try{return await decisions.decide(reviewer.staffActor,a.id,input,'round-'+id);}finally{restore();authorized.mock.restore();}
  };
  const first=await fixedDecision('ffffffff-ffff-4fff-8fff-ffffffffffff',firstInput);await decisions.processPending();
  assert.deepEqual((await decisions.ownerStatus(a.owner.actor)).review!.missingChecks,[{id:'communication',label:approvedPolicy.checks[2]!.label}]);
  await applications.update(a.owner.actor,a.id,{...draft(),bio:'New material at an unchanged server decision clock.'});
  await applications.submit(a.owner.actor,a.id,randomUUID());
  assert.equal((await decisions.ownerStatus(a.owner.actor)).review,null);
  const secondInput=await decisionBody(reviewer,a,'needs_information');assert.equal(now,fixed);
  secondInput.checks=secondInput.checks.map((check,i)=>({...check,result:i===1?'not_checked':'pass',evidenceKinds:i===1?[]:check.evidenceKinds}));
  const second=await fixedDecision('00000000-0000-4000-8000-000000000001',secondInput);await decisions.processPending();
  assert.equal(second.recordedAt,first.recordedAt);assert.ok(second.decisionId<first.decisionId);
  const current=(await decisions.ownerStatus(a.owner.actor)).review!;
  assert.equal(current.decisionId,second.decisionId);
  assert.deepEqual(current.missingChecks,[{id:'introduction',label:approvedPolicy.checks[1]!.label}]);
  assert.notEqual(current.notification!.id,(await db.pool.query('SELECT id FROM listener_review_notifications WHERE decision_id=$1',[first.decisionId])).rows[0].id);
});

test('evidence read by another staff principal cannot be used to assert personal review findings',async()=>{
  const one=await staff(),two=await staff(),a=await submitted(),input=await decisionBody(one,a),before=await businessSnapshot();
  await assert.rejects(decisions.decide(two.staffActor,a.id,input,randomUUID()),{code:'INVALID_REVIEW_DECISION'});
  assert.deepEqual(await businessSnapshot(),before);
  await review.detail(two.staffActor,a.id);
  await assert.rejects(decisions.decide(two.staffActor,a.id,input,randomUUID()),{code:'INVALID_REVIEW_DECISION'});
  await review.sampleBytes(two.staffActor,a.id,input.expectedMaterialVersion);
  const receipt=await decisions.decide(two.staffActor,a.id,input,randomUUID());
  assert.equal(receipt.outcome,'approved');await decisions.processPending();
});

test('a newly known related-account conflict before consumption withholds the grant permanently',async()=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a);
  const first=await decisions.decide(reviewer.staffActor,a.id,input,randomUUID());
  await db.pool.query("INSERT INTO staff_review_conflicts(principal_id,user_id,reason_code,source_reference) VALUES($1,$2,'known_self','isolated-post-decision-discovery')",[reviewer.staffActor.staffId,a.owner.userId]);
  await decisions.processPending();assert.deepEqual(await effectCounts(first.decisionId),{events:1,entitlements:0,notices:1});
  assert.equal((await decisions.ownerStatus(a.owner.actor)).review!.entitlement,'withheld');
  assert.deepEqual(await decisions.processPending(),{processed:0});
  assert.equal((await db.pool.query('SELECT listener_approved FROM users WHERE id=$1',[a.owner.userId])).rows[0].listener_approved,false);
});

test('Listener mode and availability consume the granted entitlement only after processing and explicit owner choices',async()=>{
  const leases=new Map<string,string>();
  const boundedPresence={
    async clear(id:string){leases.delete(id);},
    async heartbeat(id:string,version:string){leases.set(id,version);},
    async online(ids:string[],versions:Map<string,string>){return ids.filter(id=>leases.get(id)===versions.get(id));}
  } as unknown as Presence;
  const service=new NightShiftService(db,boundedPresence,config,()=>now);
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a);
  await assert.rejects(service.mode(a.owner.actor,{mode:'listener'}),{code:'LISTENER_NOT_APPROVED'});
  await assert.rejects(service.availability(a.owner.actor,{online:true}),{code:'LISTENER_NOT_APPROVED'});
  const receipt=await decisions.decide(reviewer.staffActor,a.id,input,randomUUID());
  await assert.rejects(service.mode(a.owner.actor,{mode:'listener'}),{code:'LISTENER_NOT_APPROVED'});
  await assert.rejects(service.availability(a.owner.actor,{online:true}),{code:'LISTENER_NOT_APPROVED'});
  assert.equal(leases.size,0);await decisions.processPending();
  assert.deepEqual(await effectCounts(receipt.decisionId),{events:1,entitlements:1,notices:1});
  const customer=await service.user(a.owner.userId);assert.equal(customer.mode,'customer');assert.equal(customer.online,false);
  await assert.rejects(service.availability(a.owner.actor,{online:true}),{code:'LISTENER_NOT_APPROVED'});
  const listener=await service.mode(a.owner.actor,{mode:'listener'});
  assert.equal(listener.listenerApproved,true);assert.equal(listener.mode,'listener');assert.equal(listener.online,false);assert.equal(leases.size,0);
  assert.equal((await service.availability(a.owner.actor,{online:true})).online,true);
  assert.equal((await service.mode(a.owner.actor,{mode:'customer'})).online,false);assert.equal(leases.size,0);
});

test('an approved 80-code-point policy version remains valid in the decision request',async()=>{
  const p=structuredClone(approvedPolicy);p.version='\u{1f4d8}'.repeat(80);p.approvalReference='isolated-unicode-version';
  const service=new StaffReviewDecisions(db,authority,review,p,()=>now),reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a);
  const receipt=await service.decide(reviewer.staffActor,a.id,{...input,policyVersion:p.version,policyDigest:service.policy().digest},randomUUID());
  assert.equal(receipt.policyVersion,p.version);await service.processPending();
  assert.deepEqual(await effectCounts(receipt.decisionId),{events:1,entitlements:1,notices:1});
});

test('provider disablement observed by an in-flight current-identity read denies a cached receipt',async t=>{
  const reviewer=await staff(),a=await submitted(),input=await decisionBody(reviewer,a),requestKey=randomUUID();
  await decisions.decide(reviewer.staffActor,a.id,input,requestKey);await decisions.processPending();
  const entered=defer(),release=defer(),original=providerClient.getUser.bind(providerClient),before=await businessSnapshot();
  const mocked=t.mock.method(providerClient,'getUser',async(uid:string)=>{if(uid===reviewer.uid){entered.resolve();await release.promise;}return original(uid);});
  const pending=decisions.decide(reviewer.staffActor,a.id,input,requestKey);void pending.catch(()=>{});await entered.promise;
  try{providerUsers.get(reviewer.uid)!.disabled=true;release.resolve();await assert.rejects(pending,{code:'STAFF_UNAUTHENTICATED'});}
  finally{release.resolve();mocked.mock.restore();}
  assert.deepEqual(await businessSnapshot(),before);
});
