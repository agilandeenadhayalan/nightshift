import {after,before,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {PoolClient} from 'pg';
import {TEST_RATE,TEST_VIDEO_RATE} from '@nightshift/backend-domain';
import {Database} from '../src/db';
import {NightShiftService} from '../src/service';
import {FcmHttpTransport,PushOutcome,PushSend,PushTransport} from '../src/push-transport';
import {bounded,deferred,MatchingFixture,MatchingParticipant,matchBody} from './matching-fixture';

const h=new MatchingFixture(),sent:PushSend[]=[];
let sendResult:(message:PushSend)=>Promise<PushOutcome>=async()=>({kind:'accepted',code:'ACCEPTED',messageId:'synthetic'});
const transport:PushTransport={available:()=>true,send:async(message,beforeDispatch?:()=>Promise<boolean>)=>{
  if(beforeDispatch&&!await beforeDispatch())return{kind:'failed',code:'SUPPRESSED'};
  sent.push(structuredClone(message));return sendResult(message);
}};
const activation=(r:{id:string;version:number;bindingId:string})=>({registrationId:r.id,expectedVersion:r.version,bindingId:r.bindingId,
  notificationPermission:'granted',backgroundInvitations:true,capabilityVersion:'android-audio-invitations-v1',consentVersion:'background-invitations-v1'});
async function register(listener:MatchingParticipant,expectedVersion:number|null=null){
  const prepared=await h.service.push.prepare(listener,{targetKind:'fcm_token',token:`synthetic-${randomUUID()}`,expectedVersion},randomUUID());
  return h.service.push.activate(listener,activation(prepared),randomUUID());
}
async function invitation(background=true){
  const customer=await h.participant(),listener=await h.participant(true),registration=await register(listener);
  if(background)await h.presence.clear(listener.id);
  const call=await h.service.createCall(customer,{listenerId:listener.id,quoteId:TEST_RATE.id,mediaType:'audio'},randomUUID());
  return{customer,listener,registration,call};
}
async function cancel(customer:MatchingParticipant,call:{id:string;version:number}){
  return h.service.action(customer,call.id,'cancel',{expectedVersion:call.version},randomUUID());
}
before(async()=>{
  await h.open();await h.db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[TEST_VIDEO_RATE.id,TEST_VIDEO_RATE]);
  h.config.push={projectId:h.project,packageName:'com.agilandeenadhayalan.nightshift',credentialFile:'synthetic-unused-by-injected-transport',
    digestKey:randomBytes(32).toString('hex'),encryptionKey:randomBytes(32).toString('hex')};
  h.config.videoCallsEnabled=true;h.config.agoraAppId='a'.repeat(32);h.config.agoraAppCertificate='b'.repeat(32);
  h.service=new NightShiftService(h.db,h.presence,h.config,h.clock,{pushTransport:transport});
});
after(()=>h.close());
beforeEach(async()=>{
  sendResult=async()=>({kind:'accepted',code:'ACCEPTED',messageId:'synthetic'});
  if(h.ids.size)await h.db.pool.query('UPDATE users SET suspended=true,desired_online=false WHERE id=ANY($1::uuid[])',[[...h.ids]]);
  h.advance(31*60_000);await h.service.recover();await h.service.matching.processPending(100);await h.service.push.processPending(100);sent.length=0;
});

test('socket completion cannot consume the private data-only push job or prove media readiness',async()=>{
  const {customer,listener,registration,call}=await invitation();assert.equal(sent.length,0);
  await h.db.pool.query('UPDATE outbox_events SET delivered_at=now() WHERE event_id IN (SELECT id FROM call_events WHERE call_id=$1)',[call.id]);
  await h.service.push.processPending();assert.equal(sent.length,1);
  const message=sent[0]!;assert.equal(message.data.type,'call.invitation');assert.equal(message.data.callId,call.id);
  assert.equal(message.data.registrationId,registration.id);assert.equal(message.data.registrationVersion,String(registration.version));
  assert.equal(message.data.bindingId,registration.bindingId);assert.equal(message.deadlineAt,Date.parse(call.expiresAt!));
  assert.deepEqual(Object.keys(message.data).sort(),['schemaVersion','type','callId','eventId','callVersion','expiresAt','registrationId','registrationVersion','bindingId'].sort());
  for(const privateValue of [customer.token,customer.mobile,customer.uid,customer.id,listener.token,listener.mobile,listener.uid,listener.id]){
    assert.ok(!JSON.stringify(message.data).includes(privateValue));
  }
  const current=await h.service.call(customer.id,call.id);assert.equal(current.state,'ringing');assert.equal(current.acceptedAt,null);assert.equal(current.chargeMicrocredits,0);
  await h.service.push.processPending();assert.equal(sent.length,1,'Provider acceptance is not retried while awaiting a handset acknowledgment');
});

test('cancel before dispatch suppresses the older invitation but sends its terminal dismissal',async()=>{
  const {customer,call}=await invitation(),ended=await cancel(customer,call);
  await h.service.push.processPending();assert.equal(sent.length,1);assert.equal(sent[0]!.data.type,'call.terminal');
  assert.equal(sent[0]!.data.callVersion,String(ended.version));assert.equal(sent[0]!.deadlineAt,Date.parse(call.expiresAt!));
  assert.equal((await h.service.call(customer.id,call.id)).chargeMicrocredits,0);
});

test('accept before dispatch uses a non-ringing dismissal without accepting or joining from push',async()=>{
  const {customer,listener,call}=await invitation(),accepted=await h.service.action(listener,call.id,'accept',{expectedVersion:call.version},randomUUID());
  await h.service.push.processPending();assert.equal(sent.length,1);assert.equal(sent[0]!.data.type,'call.terminal');
  assert.equal(sent[0]!.data.callVersion,String(accepted.version));assert.equal((await h.service.call(customer.id,call.id)).state,'connecting');
  assert.equal((await h.service.call(customer.id,call.id)).chargeMicrocredits,0);
});

test('original invitation expiry suppresses both queued invitation and late terminal jobs',async()=>{
  const {customer,call}=await invitation();h.now=Date.parse(call.expiresAt!)+1;await h.service.recover();await h.service.push.processPending();
  assert.equal(sent.length,0);assert.equal((await h.service.call(customer.id,call.id)).state,'ended');
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM spend_holds WHERE call_id=$1 AND released_at IS NULL',[call.id])).rows[0].total,0);
});

test('video calls never enqueue invitation delivery despite an active push registration',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);await register(listener);
  const call=await h.service.createCall(customer,{listenerId:listener.id,quoteId:TEST_VIDEO_RATE.id,mediaType:'video',videoConsent:true},randomUUID());
  await h.service.push.processPending();await cancel(customer,call);await h.service.push.processPending();assert.equal(sent.length,0);
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM push_delivery_jobs WHERE call_id=$1',[call.id])).rows[0].total,0);
});

test('an in-flight provider wait holds no participant locks and late acceptance cannot revive a cancelled call',async()=>{
  const {customer,call}=await invitation(),entered=deferred(),release=deferred();
  sendResult=async()=>{entered.release();await release.promise;return{kind:'accepted',code:'ACCEPTED',messageId:'synthetic-late'};};
  const pending=h.service.push.processPending();
  try{
    await bounded(entered.promise);const ended=await bounded(cancel(customer,call),'Cancellation must not wait behind the provider operation');
    assert.equal(ended.state,'ended');release.release();await pending;
    sendResult=async()=>({kind:'accepted',code:'ACCEPTED',messageId:'synthetic-terminal'});await h.service.push.processPending();
    assert.equal((await h.service.call(customer.id,call.id)).state,'ended');assert.equal(sent.at(-1)!.data.type,'call.terminal');
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM active_participant_claims WHERE call_id=$1',[call.id])).rows[0].total,0);
  }finally{release.release();await Promise.allSettled([pending]);}
});

test('NotRegistered arriving after rotation cannot revoke the newly activated target',async()=>{
  const {listener,registration}=await invitation(),entered=deferred(),release=deferred();
  sendResult=async()=>{entered.release();await release.promise;return{kind:'unregistered',code:'UNREGISTERED'};};
  const pending=h.service.push.processPending();
  try{
    await bounded(entered.promise);const rotated=await bounded(register(listener,registration.version));
    release.release();await pending;const current=(await h.service.push.get(listener)).registration!;
    assert.equal(current.state,'active');assert.equal(current.version,rotated.version);assert.equal(current.bindingId,rotated.bindingId);
    sendResult=async()=>({kind:'accepted',code:'ACCEPTED',messageId:'synthetic-rotated'});await h.service.push.processPending();
    assert.equal(sent.length,1,'Registration rotation cannot bypass the global admission retry floor');
    h.advance(10001);await h.service.push.processPending();
    assert.equal(sent.length,2);assert.equal(sent[1]!.data.registrationVersion,String(rotated.version));
  }finally{release.release();await Promise.allSettled([pending]);}
});

test('two admission budget is shared across registration rotations for the same invitation',async()=>{
  const {listener,registration,call}=await invitation();sendResult=async()=>({kind:'unknown',code:'TIMEOUT',retryAfterMs:10000});
  await h.service.push.processPending();assert.equal(sent.length,1);
  h.advance(10_001);const next=await register(listener,registration.version);await h.service.push.processPending();assert.equal(sent.length,2);
  h.advance(10_001);await register(listener,next.version);await h.service.push.processPending();assert.equal(sent.length,2);
  assert.ok(sent.every(message=>message.deadlineAt===Date.parse(call.expiresAt!)));
});

test('unknown delivery retries only after the delay with the same event and immutable expiry',async()=>{
  const {call}=await invitation();sendResult=async()=>({kind:'unknown',code:'TIMEOUT',retryAfterMs:10000});
  await h.service.push.processPending();assert.equal(sent.length,1);await h.service.push.processPending();assert.equal(sent.length,1);
  h.advance(9999);await h.service.push.processPending();assert.equal(sent.length,1);
  h.advance(2);await h.service.push.processPending();assert.equal(sent.length,2);
  assert.equal(sent[1]!.data.eventId,sent[0]!.data.eventId);assert.equal(sent[1]!.data.callVersion,sent[0]!.data.callVersion);
  assert.equal(sent[1]!.deadlineAt,Date.parse(call.expiresAt!));h.advance(10001);await h.service.push.processPending();assert.equal(sent.length,2);
});

test('quota delay longer than the invitation lifetime cannot produce a retry',async()=>{
  const {call}=await invitation();sendResult=async()=>({kind:'retry',code:'QUOTA',retryAfterMs:60000});
  await h.service.push.processPending();assert.equal(sent.length,1);h.now=Date.parse(call.expiresAt!)+60_000;
  await h.service.recover();await h.service.push.processPending();assert.equal(sent.length,1);
});

for(const change of ['logout','fresh-sign-in','identity-revoke','permission-revoke'] as const)
test(`${change} before preflight suppresses queued delivery`,async()=>{
  const {listener,registration}=await invitation();
  if(change==='logout')await h.auth.logout(listener,c=>h.service.logoutCall(listener,c));
  if(change==='fresh-sign-in')await h.refresh(listener,true);
  if(change==='identity-revoke')await h.db.pool.query("UPDATE auth_identities SET state='revoked',revoked_at=GREATEST(created_at,$2::timestamptz) WHERE user_id=$1 AND state='verified'",[listener.id,new Date(h.now)]);
  if(change==='permission-revoke')await h.service.push.revoke(listener,{registrationId:registration.id,expectedVersion:registration.version},randomUUID());
  await h.service.push.processPending();assert.equal(sent.length,0);
});

test('independent workers claim one send attempt for one durable invitation',async()=>{
  await invitation();const otherDb=new Database(h.config.databaseUrl),other=new NightShiftService(otherDb,h.presence,h.config,h.clock,{pushTransport:transport});
  try{await Promise.all([h.service.push.processPending(),other.push.processPending()]);assert.equal(sent.length,1);}
  finally{await otherDb.close();}
});

test('a reclaimed worker cannot repeat a late send admission before its retry floor',async t=>{
  const {call}=await invitation(),preflightEntered=deferred(),allowPreflight=deferred(),sendEntered=deferred(),allowSend=deferred();
  const original=h.db.tx.bind(h.db);let once=false;
  const mock=t.mock.method(h.db,'tx',async<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>=>original(async c=>{
    const proxy=new Proxy(c,{get(target,key){if(key!=='query')return Reflect.get(target,key);return async(...args:any[])=>{
      const value=await (target.query as (...values:any[])=>Promise<any>).apply(target,args);
      if(!once&&String(args[0]).includes('SELECT * FROM push_send_budgets')){once=true;preflightEntered.release();await allowPreflight.promise;}
      return value;
    };}});return fn(proxy);
  }));
  sendResult=async()=>{
    if(sent.length===1){sendEntered.release();await allowSend.promise;return{kind:'unknown',code:'TIMEOUT',retryAfterMs:10000};}
    return{kind:'accepted',code:'ACCEPTED',messageId:'synthetic-reclaim'};
  };
  const otherDb=new Database(h.config.databaseUrl),other=new NightShiftService(otherDb,h.presence,h.config,h.clock,{pushTransport:transport});
  const pending=h.service.push.processPending(),outcome=Promise.allSettled([pending]);
  try{
    await bounded(preflightEntered.promise);h.advance(14000);allowPreflight.release();await bounded(sendEntered.promise);
    h.advance(1001);await bounded(other.push.processPending(),'Independent reclaim must not wait behind the provider');
    assert.equal(sent.length,1,'A claim lease expiring one second after admission is not permission for an immediate second send');
    const attempts=(await h.db.pool.query('SELECT count(*)::int total FROM push_delivery_attempts WHERE call_id=$1',[call.id])).rows[0];
    assert.equal(attempts.total,1);
  }finally{allowPreflight.release();allowSend.release();await outcome;mock.mock.restore();await otherDb.close();}
});

for(const change of ['logout','cancel','registration-expiry'] as const)
test(`${change} during the real transport credential wait suppresses the FCM request`,async()=>{
  const {customer,listener,call}=await invitation(),entered=deferred(),release=deferred();let requests=0;
  if(change==='registration-expiry')await h.db.pool.query('UPDATE push_registrations SET expires_at=$2 WHERE user_id=$1',[listener.id,new Date(h.now+500)]);
  const realTransport=new FcmHttpTransport({projectId:h.project,packageName:h.config.push!.packageName,clock:h.clock,
    accessToken:async()=>{entered.release();await release.promise;return'synthetic-access-token';},
    fetch:async()=>{requests++;return new Response(JSON.stringify({name:`projects/${h.project}/messages/synthetic`}),{status:200,headers:{'Content-Type':'application/json'}});}});
  const worker=new NightShiftService(h.db,h.presence,h.config,h.clock,{pushTransport:realTransport});
  const pending=worker.push.processPending(),outcome=Promise.allSettled([pending]);
  try{
    await bounded(entered.promise);
    if(change==='logout')await bounded(h.auth.logout(listener,c=>h.service.logoutCall(listener,c)),'Logout must not wait behind credentials');
    if(change==='cancel')await bounded(cancel(customer,call),'Cancellation must not wait behind credentials');
    if(change==='registration-expiry')h.advance(1000);
    release.release();await outcome;
    assert.equal(requests,0,'Recheck current call and invitation authority after OAuth work, before the actual FCM POST');
  }finally{release.release();await outcome;await realTransport.close();}
});

for(const expires of ['session','lease'] as const)
test(`${expires} expiry during a delivery admission query prevents the provider send`,async t=>{
  const {listener,call}=await invitation(),expiry=h.now+500;
  if(expires==='session')await h.db.pool.query('UPDATE auth_sessions SET expires_at=$2 WHERE token_hash=$1',[listener.sessionHash,new Date(expiry)]);
  else await h.db.pool.query('UPDATE push_registrations SET expires_at=$2 WHERE user_id=$1',[listener.id,new Date(expiry)]);
  const entered=deferred(),release=deferred(),original=h.db.tx.bind(h.db);let once=false;
  const mock=t.mock.method(h.db,'tx',async<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>=>original(async c=>{
    const proxy=new Proxy(c,{get(target,key){if(key!=='query')return Reflect.get(target,key);return async(...args:any[])=>{
      const value=await (target.query as (...values:any[])=>Promise<any>).apply(target,args);
      if(!once&&String(args[0]).includes('SELECT * FROM push_send_budgets')){once=true;entered.release();await release.promise;}
      return value;
    };}});return fn(proxy);
  }));
  const pending=h.service.push.processPending(),outcome=Promise.allSettled([pending]);
  try{
    await bounded(entered.promise);h.advance(1000);release.release();await outcome;
    assert.equal(sent.length,0,'Session and opt-in authority must still be current after the database wait');
    assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM push_delivery_attempts WHERE call_id=$1',[call.id])).rows[0].total,0,
      'An expired authority cannot consume a provider admission');
    assert.equal((await h.service.call(listener.id,call.id)).state,'ringing','Delivery suppression does not alter the call lifecycle');
  }finally{release.release();await outcome;mock.mock.restore();}
});

test('push enqueue failure rolls back call, claims, hold, event and job as one reservation',async t=>{
  const customer=await h.participant(),listener=await h.participant(true);await register(listener);await h.presence.clear(listener.id);
  const original=h.db.tx.bind(h.db);
  const mock=t.mock.method(h.db,'tx',async<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>=>original(async c=>{
    const proxy=new Proxy(c,{get(target,key){if(key!=='query')return Reflect.get(target,key);return async(...args:any[])=>{
      const value=await (target.query as (...values:any[])=>Promise<any>).apply(target,args);
      if(String(args[0]).includes('INSERT INTO push_delivery_jobs'))throw Error('Synthetic failure after push enqueue');return value;
    };}});return fn(proxy);
  }));
  try{await assert.rejects(h.service.createCall(customer,{listenerId:listener.id,quoteId:TEST_RATE.id},randomUUID()),/Synthetic failure after push enqueue/);}
  finally{mock.mock.restore();}
  const state=(await h.db.pool.query(`SELECT
    (SELECT count(*)::int FROM call_sessions WHERE customer_id=$1) calls,
    (SELECT count(*)::int FROM active_participant_claims WHERE user_id=$1 OR user_id=$2) claims,
    (SELECT count(*)::int FROM spend_holds WHERE user_id=$1 AND released_at IS NULL) holds,
    (SELECT count(*)::int FROM call_events e JOIN call_sessions c ON c.id=e.call_id WHERE c.customer_id=$1) events`,[customer.id,listener.id])).rows[0];
  assert.deepEqual(state,{calls:0,claims:0,holds:0,events:0});await h.service.push.processPending();assert.equal(sent.length,0);
});

test('one failed provider operation cannot starve an independent invitation',async()=>{
  const first=await invitation(),second=await invitation();
  sendResult=async message=>{if(message.data.callId===first.call.id)throw Error('Synthetic provider failure');return{kind:'accepted',code:'ACCEPTED',messageId:'synthetic-second'};};
  await Promise.allSettled([h.service.push.processPending()]);
  assert.ok(sent.some(message=>message.data.callId===second.call.id),'Independent selected work must still run');
});

test('matching can select background supply without changing its three-attempt ninety-second consent',async()=>{
  const customer=await h.participant(),listeners=await Promise.all([h.participant(true),h.participant(true),h.participant(true)]);
  for(const listener of listeners){await register(listener);await h.presence.clear(listener.id);}
  const request=await h.service.matching.start(customer,matchBody(),randomUUID());
  for(let attempt=1;attempt<=3;attempt++){
    await h.service.matching.processPending();const current=(await h.service.matching.current(customer)).request!;
    assert.equal(current.attemptCount,attempt);assert.equal(current.deadlineAt,request.deadlineAt);assert.equal(current.state,'ringing');
    const call=await h.service.call(customer.id,current.currentCallId!),listener=listeners.find(row=>row.id===call.listenerId)!;
    await h.service.push.processPending();await h.service.action(listener,call.id,'decline',{expectedVersion:call.version},randomUUID());
  }
  await h.service.matching.processPending();assert.equal((await h.service.matching.current(customer)).request!.state,'exhausted');
  const summary=(await h.db.pool.query('SELECT count(*)::int calls,sum(charge_microcredits)::text charge FROM call_sessions WHERE customer_id=$1',[customer.id])).rows[0];
  assert.deepEqual(summary,{calls:3,charge:'0'});
});
