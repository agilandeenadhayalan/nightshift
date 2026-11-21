import {after,before,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import {TEST_RATE,TEST_VIDEO_RATE} from '@nightshift/backend-domain';
import {NightShiftService} from '../src/service';
import {PushTransport} from '../src/push-transport';
import {AccountLifecycle,DELETION_NOTICE_VERSION} from '../src/account-lifecycle';
import {createApplication} from '../src/http';
import {bounded,deferred,MatchingFixture,MatchingParticipant} from './matching-fixture';

const h=new MatchingFixture();
let senderAvailable=true;
const transport:PushTransport={available:()=>senderAvailable,send:async(_message,beforeDispatch?:()=>Promise<boolean>)=>
  beforeDispatch&&!await beforeDispatch()?{kind:'failed',code:'SUPPRESSED'}:{kind:'accepted',code:'ACCEPTED',messageId:'synthetic'}};
const prepareBody=(token=`synthetic-${randomUUID()}`,expectedVersion:number|null=null)=>({targetKind:'fcm_token',token,expectedVersion});
const activation=(r:{id:string;version:number;bindingId:string})=>({registrationId:r.id,expectedVersion:r.version,bindingId:r.bindingId,
  notificationPermission:'granted',backgroundInvitations:true,capabilityVersion:'android-audio-invitations-v1',consentVersion:'background-invitations-v1'});
async function register(owner:MatchingParticipant){
  const prepared=await h.service.push.prepare(owner,prepareBody(),randomUUID());
  return h.service.push.activate(owner,activation(prepared),randomUUID());
}
async function card(owner:MatchingParticipant,listener:MatchingParticipant){return(await h.service.directory.page(owner)).items.find(r=>r.id===listener.id);}
type HttpRequest=(path:string,owner?:MatchingParticipant,method?:string,body?:unknown,key?:string,raw?:boolean)=>Promise<{status:number;body:any;headers:Headers}>;
async function withHttp(check:(request:HttpRequest)=>Promise<void>){
  const runtime=await createApplication(h.config,h.clock,{firebase:{verifyIdToken:async token=>{
    const identity=h.identities.get(String(token));assert.ok(identity,'HTTP tests accept only synthetic fixture identities');return identity;
  }}},{pushTransport:transport});
  try{
    await runtime.app.listen(0,'127.0.0.1');const base=await runtime.app.getUrl();
    await check(async(path,owner,method='GET',body,key,raw=false)=>{
      const response=await fetch(`${base}/v1/${path}`,{method,headers:{...(owner?{Authorization:`Bearer ${owner.token}`}:{ }),
        ...(body===undefined?{}:{'Content-Type':'application/json'}),...(key?{'Idempotency-Key':key}:{})},
        body:body===undefined?undefined:raw?String(body):JSON.stringify(body)});
      return{status:response.status,body:await response.json(),headers:response.headers};
    });
  }finally{await runtime.close();}
}
before(async()=>{
  await h.open();
  await h.db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[TEST_VIDEO_RATE.id,TEST_VIDEO_RATE]);
  h.config.push={projectId:h.project,packageName:'com.agilandeenadhayalan.nightshift',credentialFile:'synthetic-unused-by-injected-transport',
    digestKey:randomBytes(32).toString('hex'),encryptionKey:randomBytes(32).toString('hex')};
  h.config.videoCallsEnabled=true;h.config.agoraAppId='a'.repeat(32);h.config.agoraAppCertificate='b'.repeat(32);
  h.service=new NightShiftService(h.db,h.presence,h.config,h.clock,{pushTransport:transport});
});
after(()=>h.close());
beforeEach(async()=>{
  senderAvailable=true;
  if(h.ids.size)await h.db.pool.query('UPDATE users SET suspended=true,desired_online=false WHERE id=ANY($1::uuid[])',[[...h.ids]]);
  h.advance(31*60_000);await h.service.recover();await h.service.matching.processPending(100);await h.service.push.processPending(100);
});

test('registration rejects non-phone authority, invalid token/body and forged ownership',async()=>{
  const owner=await h.participant(true),ids=[randomUUID()],dev=(await h.developmentListeners(ids))[0]!;
  await assert.rejects(h.service.push.prepare(dev,prepareBody(),randomUUID()));
  for(const body of [{...prepareBody(),ownerId:owner.id},{...prepareBody(),token:''},{...prepareBody(),token:'x'.repeat(4097)},
    {...prepareBody(),token:'a\nb'},{...prepareBody(),targetKind:'fid'},{...prepareBody(),expectedVersion:0}]){
    await assert.rejects(h.service.push.prepare(owner,body,randomUUID()));
  }
  assert.equal((await h.service.push.get(owner)).registration,null);
});

test('prepared binding is not reachable and activation requires approved Listener availability',async()=>{
  const viewer=await h.participant(),listener=await h.participant(true),prepared=await h.service.push.prepare(listener,prepareBody(),randomUUID());
  await h.presence.clear(listener.id);
  assert.equal(prepared.state,'prepared');assert.equal(prepared.backgroundInvitations,false);
  assert.equal((await card(viewer,listener))!.available,false);
  const customer=await h.service.push.prepare(viewer,prepareBody(),randomUUID());
  await assert.rejects(h.service.push.activate(viewer,activation(customer),randomUUID()));
  const active=await h.service.push.activate(listener,activation(prepared),randomUUID());
  assert.equal(active.state,'active');assert.equal(active.backgroundInvitations,true);
  const reachable=(await card(viewer,listener))!;
  assert.equal(reachable.online,false);assert.equal(reachable.reachability,'background_eligible');assert.equal(reachable.available,true);
});

test('prepare and activation keep exact idempotent receipts without renewing the lease',async()=>{
  const owner=await h.participant(true),key=randomUUID(),body=prepareBody();
  const prepared=await h.service.push.prepare(owner,body,key),again=await h.service.push.prepare(owner,body,key);
  assert.equal(again.id,prepared.id);assert.equal(again.version,prepared.version);assert.equal(again.bindingId,prepared.bindingId);
  await assert.rejects(h.service.push.prepare(owner,{...body,token:'different-target'},key),{code:'IDEMPOTENCY_CONFLICT'});
  const activateKey=randomUUID(),intent=activation(prepared),active=await h.service.push.activate(owner,intent,activateKey);
  h.advance(60_000);const replay=await h.service.push.activate(owner,intent,activateKey);
  assert.equal(replay.leaseExpiresAt,active.leaseExpiresAt);assert.equal(replay.version,active.version);
  assert.ok(Date.parse(active.leaseExpiresAt!)<=h.now+29*60_000);
});

test('target rotation fences stale activation and revoke while keeping the new binding',async()=>{
  const owner=await h.participant(true),first=await register(owner);
  const rotated=await h.service.push.prepare(owner,prepareBody(undefined,first.version),randomUUID());
  assert.ok(rotated.version>first.version);assert.notEqual(rotated.bindingId,first.bindingId);
  await assert.rejects(h.service.push.activate(owner,activation(first),randomUUID()),{code:'PUSH_REGISTRATION_CHANGED'});
  await assert.rejects(h.service.push.revoke(owner,{registrationId:first.id,expectedVersion:first.version},randomUUID()),{code:'PUSH_REGISTRATION_CHANGED'});
  const next=await h.service.push.activate(owner,activation(rotated),randomUUID());
  assert.equal((await h.service.push.get(owner)).registration!.bindingId,next.bindingId);
});

test('concurrent first claims cannot transfer one opaque target between owners',async()=>{
  const owners=await Promise.all([h.participant(true),h.participant(true)]),body=prepareBody();
  const results=await Promise.allSettled(owners.map(owner=>h.service.push.prepare(owner,body,randomUUID())));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const failed=results.find(r=>r.status==='rejected') as PromiseRejectedResult;
  assert.equal(failed.reason.code,'PUSH_TARGET_CONFLICT');
  assert.ok(!JSON.stringify(failed.reason).includes(owners[0]!.id));assert.ok(!JSON.stringify(failed.reason).includes(owners[1]!.id));
});

test('write-only target is absent from registration receipts, journaled commands and raw database rows',async()=>{
  const owner=await h.participant(true),body=prepareBody(),prepared=await h.service.push.prepare(owner,body,randomUUID());
  const active=await h.service.push.activate(owner,activation(prepared),randomUUID());
  for(const response of [prepared,active,await h.service.push.get(owner)])assert.ok(!JSON.stringify(response).includes(body.token));
  const registrations=(await h.db.pool.query('SELECT row_to_json(r) value FROM push_registrations r')).rows;
  assert.ok(!JSON.stringify(registrations).includes(body.token),'The write-only token must not be stored as plaintext');
  const keys=(await h.db.pool.query('SELECT row_to_json(r) value FROM idempotency_keys r WHERE actor_id=$1',[owner.id])).rows;
  assert.ok(!JSON.stringify(keys).includes(body.token));
  const commands=(await h.db.pool.query('SELECT row_to_json(r) value FROM push_commands r WHERE user_id=$1',[owner.id])).rows;
  assert.ok(!JSON.stringify(commands).includes(body.token));
});

test('prepared and active grants expire at their absolute bounds and session expiry caps the lease',async()=>{
  const owner=await h.participant(true),prepared=await h.service.push.prepare(owner,prepareBody(),randomUUID());
  h.advance(300_001);await assert.rejects(h.service.push.activate(owner,activation(prepared),randomUUID()));
  assert.equal((await h.service.push.get(owner)).registration!.state,'expired');
  const fresh=await h.participant(true),expiry=h.now+45_000;
  await h.db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[fresh.sessionHash,new Date(expiry)]);
  const active=await register(fresh);assert.ok(Date.parse(active.leaseExpiresAt!)<=expiry);
  const viewer=await h.participant();await h.presence.clear(fresh.id);h.advance(45_001);
  assert.equal((await card(viewer,fresh))!.available,false);
});

test('disabled delivery still scrubs expired prepared and active token ciphertext without provider work',async()=>{
  let providerCalls=0;
  const tripwire:PushTransport={available:()=>{providerCalls++;return true;},send:async()=>{providerCalls++;throw Error('Disabled delivery cannot contact a provider');}};
  for(const disabled of ['configuration','transport'] as const){
    const preparedOwner=await h.participant(true),activeOwner=await h.participant(true);
    await h.service.push.prepare(preparedOwner,prepareBody(),randomUUID());await register(activeOwner);
    const owners=[preparedOwner.id,activeOwner.id];
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM push_registrations WHERE user_id=ANY($1::uuid[]) AND ciphertext IS NOT NULL',[owners])).rows[0].total,2);
    h.advance(30*60_000+1);
    const service=new NightShiftService(h.db,h.presence,disabled==='configuration'?{...h.config,push:undefined}:h.config,h.clock,
      disabled==='configuration'?{pushTransport:tripwire}:{});
    assert.deepEqual(await service.push.processPending(),{processed:0});
    const rows=(await h.db.pool.query('SELECT state,ciphertext FROM push_registrations WHERE user_id=ANY($1::uuid[])',[owners])).rows;
    assert.equal(rows.length,2);assert.ok(rows.every(row=>row.state==='expired'&&row.ciphertext===null),
      `Expired token ciphertext must be erased even when ${disabled} is disabled`);
    assert.equal(providerCalls,0);
  }
});

test('same-device bearer refresh preserves binding but stale actor cannot recover cached private writes',async()=>{
  const owner=await h.participant(true),key=randomUUID(),body=prepareBody(),prepared=await h.service.push.prepare(owner,body,key);
  const active=await h.service.push.activate(owner,activation(prepared),randomUUID()),refreshed=await h.refresh(owner);
  await assert.rejects(h.service.push.prepare(owner,body,key),{code:'UNAUTHENTICATED'});
  await assert.rejects(h.service.push.get(owner),{code:'UNAUTHENTICATED'});
  const current=(await h.service.push.get(refreshed)).registration!;
  assert.equal(current.bindingId,active.bindingId);assert.equal(current.version,active.version);assert.equal(current.leaseExpiresAt,active.leaseExpiresAt);
});

for(const change of ['logout','fresh-sign-in','takeover','restriction','identity-revoke','deletion'] as const)
test(`${change} removes background eligibility even when Redis was already absent`,async()=>{
  const owner=await h.participant(true),viewer=await h.participant();await register(owner);await h.presence.clear(owner.id);
  if(change==='logout')await h.auth.logout(owner,c=>h.service.logoutCall(owner,c));
  if(change==='fresh-sign-in')await h.refresh(owner,true);
  if(change==='takeover')await h.refresh(owner,true,randomUUID());
  if(change==='restriction')await h.db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[owner.id]);
  if(change==='identity-revoke')await h.db.pool.query("UPDATE auth_identities SET state='revoked',revoked_at=GREATEST(created_at,$2::timestamptz) WHERE user_id=$1 AND state='verified'",[owner.id,new Date(h.now)]);
  if(change==='deletion')await new AccountLifecycle(h.db,h.clock,async()=>{}).requestDeletion(owner,{noticeVersion:DELETION_NOTICE_VERSION,confirm:true,receiptToken:'c'.repeat(64)});
  assert.notEqual((await card(viewer,owner))?.available,true);
  await assert.rejects(h.service.createCall(viewer,{listenerId:owner.id,quoteId:TEST_RATE.id},randomUUID()));
});

test('background notification reachability permits audio but never a video reservation',async()=>{
  const owner=await h.participant(),listener=await h.participant(true);await register(listener);await h.presence.clear(listener.id);
  const projected=(await card(owner,listener))!;assert.equal(projected.available,true);assert.equal(projected.online,false);
  await assert.rejects(h.service.createCall(owner,{listenerId:listener.id,quoteId:TEST_VIDEO_RATE.id,mediaType:'video',videoConsent:true},randomUUID()));
  const audio=await h.service.createCall(owner,{listenerId:listener.id,quoteId:TEST_RATE.id,mediaType:'audio'},randomUUID());
  assert.equal(audio.state,'ringing');assert.equal(audio.mediaType,'audio');assert.equal(audio.chargeMicrocredits,0);
});

test('sender unavailability and withdrawn availability cannot preserve background eligibility',async()=>{
  const owner=await h.participant(),listener=await h.participant(true);await register(listener);await h.presence.clear(listener.id);
  senderAvailable=false;assert.equal((await card(owner,listener))!.available,false);
  senderAvailable=true;await h.service.availability(listener,{online:false});
  assert.equal((await card(owner,listener))!.available,false);
});

test('restoring an account restriction cannot silently revive its previous invitation consent',async()=>{
  const owner=await h.participant(),listener=await h.participant(true);await register(listener);await h.presence.clear(listener.id);
  await h.db.pool.query('UPDATE users SET suspended=true WHERE id=$1',[listener.id]);
  await h.db.pool.query('UPDATE users SET suspended=false WHERE id=$1',[listener.id]);
  assert.equal((await h.service.push.get(listener)).registration!.state,'revoked');
  assert.equal((await card(owner,listener))!.available,false);
});

for(const expires of ['session','lease'] as const)
test(`${expires} expiry during the final presence read cannot authorize background reservation`,async t=>{
  const owner=await h.participant(),listener=await h.participant(true),active=await register(listener);await h.presence.clear(listener.id);
  if(expires==='session')await h.db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[listener.sessionHash,new Date(h.now+500)]);
  else h.now=Date.parse(active.leaseExpiresAt!)-500;
  const entered=deferred(),release=deferred(),original=h.presence.online.bind(h.presence);let once=false;
  const mock=t.mock.method(h.presence,'online',async(...args:Parameters<typeof original>)=>{
    const value=await original(...args);if(!once&&args[0].includes(listener.id)){once=true;entered.release();await release.promise;}return value;
  });
  const pending=h.service.createCall(owner,{listenerId:listener.id,quoteId:TEST_RATE.id},randomUUID());
  const outcome=Promise.allSettled([pending]);
  try{
    await bounded(entered.promise);h.advance(1000);release.release();const result=(await outcome)[0]!;
    assert.equal(result.status,'rejected');if(result.status==='rejected')assert.equal(result.reason.code,'LISTENER_OFFLINE');
    const state=(await h.db.pool.query(`SELECT
      (SELECT count(*)::int FROM call_sessions WHERE customer_id=$1) calls,
      (SELECT count(*)::int FROM active_participant_claims WHERE user_id=$1) claims,
      (SELECT count(*)::int FROM spend_holds WHERE user_id=$1 AND released_at IS NULL) holds`,[owner.id])).rows[0];
    assert.deepEqual(state,{calls:0,claims:0,holds:0});
  }finally{release.release();await outcome;mock.mock.restore();}
});

test('session expiry during registration admission cannot authorize the prepared write',async t=>{
  const owner=await h.participant(true);await h.db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[owner.sessionHash,new Date(h.now+500)]);
  const entered=deferred(),release=deferred(),original=h.presence.rateLimit.bind(h.presence);let once=false;
  const mock=t.mock.method(h.presence,'rateLimit',async(...args:Parameters<typeof original>)=>{
    const result=await original(...args);if(!once){once=true;entered.release();await release.promise;}return result;
  });
  const pending=h.service.push.prepare(owner,prepareBody(),randomUUID()),denied=assert.rejects(pending,{code:'UNAUTHENTICATED'});
  const admission=Promise.race([bounded(entered.promise),denied.then(()=>{throw Error('Admission rejected before reaching the controlled rate-limit wait');})]);
  try{await admission;h.advance(1000);release.release();await denied;
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM push_registrations WHERE user_id=$1',[owner.id])).rows[0].total,0);
  }finally{release.release();await Promise.allSettled([denied]);mock.mock.restore();}
});

test('notification lease expiry after reachability cannot reserve an undeliverable call',async t=>{
  const owner=await h.participant(),listener=await h.participant(true);await register(listener);await h.presence.clear(listener.id);
  await h.db.pool.query('UPDATE push_registrations SET expires_at=$2 WHERE user_id=$1',[listener.id,new Date(h.now+500)]);
  const entered=deferred(),release=deferred(),original=h.service.wallet.bind(h.service);let once=false;
  const mock=t.mock.method(h.service,'wallet',async(...args:Parameters<typeof original>)=>{
    const value=await original(...args);if(!once&&args[0]===owner.id){once=true;entered.release();await release.promise;}return value;
  });
  const pending=h.service.createCall(owner,{listenerId:listener.id,quoteId:TEST_RATE.id},randomUUID()),outcome=Promise.allSettled([pending]);
  try{
    await bounded(entered.promise);h.advance(1000);release.release();const result=(await outcome)[0]!;
    assert.equal(result.status,'rejected','A formerly reachable notification lease must still cover final call admission');
    if(result.status==='rejected')assert.equal(result.reason.code,'LISTENER_OFFLINE');
    const state=(await h.db.pool.query(`SELECT
      (SELECT count(*)::int FROM call_sessions WHERE customer_id=$1) calls,
      (SELECT count(*)::int FROM active_participant_claims WHERE user_id=$1) claims,
      (SELECT count(*)::int FROM spend_holds WHERE user_id=$1 AND released_at IS NULL) holds`,[owner.id])).rows[0];
    assert.deepEqual(state,{calls:0,claims:0,holds:0});
  }finally{release.release();await outcome;mock.mock.restore();}
});

test('real HTTP registration CRUD enforces current owner authority and published response schemas',async()=>{
  const owner=await h.participant(true),other=await h.participant(true),contract=require('@nightshift/contracts/openapi.json');
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);
  const validate=(name:string,value:unknown)=>{const check=ajv.compile({$defs:definitions,$ref:`#/$defs/${name}`});assert.equal(check(value),true,JSON.stringify(check.errors));};
  await withHttp(async request=>{
    const path='me/push/registration',key=randomUUID(),body=prepareBody();
    assert.equal((await request(path,undefined)).status,401);
    assert.equal((await request(path,undefined,'PUT',body,key)).status,401);
    assert.equal((await request(path,owner,'PUT',body)).status,400);
    assert.equal((await request(`${path}?owner=${other.id}`,owner,'PUT',body,key)).status,400);
    assert.equal((await request(path,owner,'PUT',{...body,ownerId:other.id},key)).status,400);
    const prepared=await request(path,owner,'PUT',body,key);assert.equal(prepared.status,200);validate('PushRegistration',prepared.body);
    assert.equal(prepared.headers.get('cache-control'),'no-store');assert.equal(prepared.body.state,'prepared');
    const replay=await request(path,owner,'PUT',body,key);assert.equal(replay.status,200);assert.equal(replay.body.bindingId,prepared.body.bindingId);
    const foreign=await request(path,other);assert.equal(foreign.status,200);validate('CurrentPushRegistration',foreign.body);assert.equal(foreign.body.registration,null);
    const active=await request(`${path}/activate`,owner,'POST',activation(prepared.body),randomUUID());assert.equal(active.status,200);validate('PushRegistration',active.body);assert.equal(active.body.state,'active');
    const current=await request(path,owner);assert.equal(current.status,200);validate('CurrentPushRegistration',current.body);assert.equal(current.body.registration.bindingId,active.body.bindingId);
    const stale=await request(path,owner,'DELETE',{registrationId:active.body.id,expectedVersion:active.body.version+1},randomUUID());assert.equal(stale.status,409);
    const revoked=await request(path,owner,'DELETE',{registrationId:active.body.id,expectedVersion:active.body.version},randomUUID());assert.equal(revoked.status,200);validate('PushRegistration',revoked.body);assert.equal(revoked.body.state,'revoked');
    for(const receipt of [prepared.body,active.body,current.body,revoked.body]){
      const serialized=JSON.stringify(receipt);for(const secret of [body.token,owner.token,owner.mobile,owner.uid,owner.id,owner.sessionHash])assert.ok(!serialized.includes(secret));
    }
    await h.auth.logout(owner,c=>h.service.logoutCall(owner,c));
    assert.equal((await request(path,owner,'PUT',body,key)).status,401,'Cached receipt cannot outlive current authentication');
  });
});

test('HTTP registration parser bounds raw request bytes and returns sanitized errors',async()=>{
  const owner=await h.participant(true);
  await withHttp(async request=>{
    const path='me/push/registration',privateMarker=`synthetic-private-${randomUUID()}`;
    for(const endpoint of [path,`${path}/activate`]){
      const oversized=await request(endpoint,owner,endpoint===path?'PUT':'POST',{token:privateMarker+'x'.repeat(8192)},randomUUID());
      assert.equal(oversized.status,413);assert.equal(oversized.body.error.code,'INVALID_PUSH_REGISTRATION');assert.ok(!JSON.stringify(oversized.body).includes(privateMarker));
    }
    const malformed=await request(path,owner,'PUT',`{"token":"${privateMarker}",`,randomUUID(),true);
    assert.equal(malformed.status,400);assert.equal(malformed.body.error.code,'INVALID_PUSH_REGISTRATION');assert.ok(!JSON.stringify(malformed.body).includes(privateMarker));
    assert.equal((await request(path,owner)).body.registration,null);
  });
});
