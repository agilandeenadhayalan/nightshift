import {after,before,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {copyFile,mkdtemp,readdir,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import Ajv from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import {io,Socket} from 'socket.io-client';
import {TEST_RATE,TEST_VIDEO_RATE} from '@nightshift/backend-domain';
import {Database} from '../src/db';
import {migrate} from '../src/migrate';
import {createApplication} from '../src/http';
import {NightShiftService} from '../src/service';
import {PushSend,PushTransport} from '../src/push-transport';
import {bounded,deferred,MatchingFixture,MatchingParticipant,matchBody} from './matching-fixture';

const h=new MatchingFixture(),sent:PushSend[]=[];
let beforeSend:(()=>Promise<void>)|undefined;
const transport:PushTransport={available:()=>true,send:async(message,beforeDispatch)=>{
  await beforeSend?.();
  if(beforeDispatch&&!await beforeDispatch())return{kind:'failed',code:'SUPPRESSED'};
  sent.push(structuredClone(message));return{kind:'accepted',code:'ACCEPTED',messageId:'synthetic-media-preferences'};
}};
const prefs=(online:boolean,audioEnabled:boolean,videoEnabled:boolean)=>({online,audioEnabled,videoEnabled});
const callBody=(listener:MatchingParticipant,mediaType:'audio'|'video')=>({listenerId:listener.id,
  quoteId:mediaType==='audio'?TEST_RATE.id:TEST_VIDEO_RATE.id,mediaType,...(mediaType==='video'?{videoConsent:true}:{})});
const activation=(r:{id:string;version:number;bindingId:string})=>({registrationId:r.id,expectedVersion:r.version,bindingId:r.bindingId,
  notificationPermission:'granted',backgroundInvitations:true,capabilityVersion:'android-audio-invitations-v1',consentVersion:'background-invitations-v1'});
async function prepare(listener:MatchingParticipant){return h.service.push.prepare(listener,
  {targetKind:'fcm_token',token:`synthetic-${randomUUID()}`,expectedVersion:null},randomUUID());}
async function register(listener:MatchingParticipant){return h.service.push.activate(listener,activation(await prepare(listener)),randomUUID());}
async function card(customer:MatchingParticipant,listener:MatchingParticipant){
  const found=(await h.service.directory.page(customer)).items.find(row=>row.id===listener.id);assert.ok(found);return found;
}
async function reservations(customer:MatchingParticipant){return(await h.db.pool.query(`SELECT
  (SELECT count(*)::int FROM call_sessions WHERE customer_id=$1) calls,
  (SELECT count(*)::int FROM active_participant_claims WHERE user_id=$1) claims,
  (SELECT count(*)::int FROM spend_holds WHERE user_id=$1 AND released_at IS NULL) holds`,[customer.id])).rows[0];}
type Runtime=Awaited<ReturnType<typeof createApplication>>;
async function withHttp(check:(runtime:Runtime,base:string,request:(route:string,actor?:MatchingParticipant,method?:string,body?:unknown)=>Promise<{status:number;body:any}>)=>Promise<void>){
  const runtime=await createApplication(h.config,h.clock,{firebase:{verifyIdToken:async token=>{
    const identity=h.identities.get(String(token));assert.ok(identity);return identity;
  }}},{pushTransport:transport});
  try{
    await runtime.app.listen(0,'127.0.0.1');const base=await runtime.app.getUrl();
    await check(runtime,base,async(route,actor,method='GET',body)=>{
      const response=await fetch(`${base}/v1/${route}`,{method,headers:{...(actor?{Authorization:`Bearer ${actor.token}`} : {}),
        ...(body===undefined?{}:{'Content-Type':'application/json'})},body:body===undefined?undefined:JSON.stringify(body)});
      return{status:response.status,body:await response.json()};
    });
  }finally{await runtime.close();}
}
function event(socket:Socket,name:string,predicate:(value:any)=>boolean=()=>true):Promise<any>{
  return new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{socket.off(name,handler);reject(Error(`No ${name} within bounded wait`));},5000);
    const handler=(value:any)=>{if(predicate(value)){clearTimeout(timer);socket.off(name,handler);resolve(value);}};
    socket.on(name,handler);
  });
}
before(async()=>{
  await h.open();
  await h.db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[TEST_VIDEO_RATE.id,TEST_VIDEO_RATE]);
  h.config.push={projectId:h.project,packageName:'com.agilandeenadhayalan.nightshift',credentialFile:'synthetic-not-read',
    digestKey:randomBytes(32).toString('hex'),encryptionKey:randomBytes(32).toString('hex')};
  h.config.videoCallsEnabled=true;h.config.agoraAppId='a'.repeat(32);h.config.agoraAppCertificate='b'.repeat(32);
  h.service=new NightShiftService(h.db,h.presence,h.config,h.clock,{pushTransport:transport});
});
after(()=>h.close());
beforeEach(async()=>{
  beforeSend=undefined;h.config.videoCallsEnabled=true;
  if(h.ids.size)await h.db.pool.query('UPDATE users SET suspended=true,desired_online=false WHERE id=ANY($1::uuid[])',[[...h.ids]]);
  h.advance(31*60_000);await h.service.recover();await h.service.matching.processPending(100);await h.service.push.processPending(100);sent.length=0;
});

test('020 to 021 preserves existing user data and defaults both independent preferences on',async()=>{
  const schema=`media_legacy_${randomUUID().replaceAll('-','')}`,directory=await mkdtemp(path.join(tmpdir(),'nightshift-media-'));
  const source=path.resolve(__dirname,'../../../../db/migrations'),url=new URL(h.config.databaseUrl);
  url.searchParams.set('options',`-csearch_path=${schema}`);const db=new Database(url.toString());
  await h.admin.pool.query(`CREATE SCHEMA ${schema}`);
  try{
    const files=(await readdir(source)).filter(name=>/^\d{3}_.*\.sql$/.test(name)&&Number(name.slice(0,3))<=20);
    assert.equal(files.length,20);for(const name of files)await copyFile(path.join(source,name),path.join(directory,name));
    await migrate(db,directory);
    for(const online of [true,false])await db.pool.query(`INSERT INTO users(id,test_handle,display_name,adult_confirmed,listener_approved,mode,desired_online)
      VALUES($1,$2,'Synthetic legacy listener',true,true,'listener',$3)`,[randomUUID(),randomUUID(),online]);
    const before=(await db.pool.query('SELECT to_jsonb(u) value FROM users u ORDER BY id')).rows;
    const migrations=(await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name')).rows;
    await migrate(db);
    assert.deepEqual((await db.pool.query("SELECT to_jsonb(u)-'audio_enabled'-'video_enabled' value FROM users u ORDER BY id")).rows,before);
    assert.deepEqual((await db.pool.query('SELECT audio_enabled,video_enabled FROM users ORDER BY id')).rows,
      [{audio_enabled:true,video_enabled:true},{audio_enabled:true,video_enabled:true}]);
    assert.deepEqual((await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name LIMIT 20')).rows,migrations);
    assert.equal((await db.pool.query('SELECT count(*)::int total FROM schema_migrations')).rows[0].total,21);
  }finally{
    await db.close();await h.admin.pool.query(`DROP SCHEMA ${schema} CASCADE`);
    assert.equal(path.dirname(path.resolve(directory)),path.resolve(tmpdir()));assert.ok(path.basename(directory).startsWith('nightshift-media-'));
    await rm(directory,{recursive:true,force:true});
  }
});

test('independent preferences persist across service recreation, master toggles and mode switches',async()=>{
  const listener=await h.participant(true);
  assert.deepEqual((await h.service.user(listener.id)).availability,prefs(true,true,true));
  assert.deepEqual((await h.service.availability(listener,{online:true,audioEnabled:false})).availability,prefs(true,false,true));
  const restarted=new NightShiftService(h.db,h.presence,h.config,h.clock,{pushTransport:transport});
  assert.deepEqual((await restarted.availability(listener,{online:false})).availability,prefs(false,false,true));
  assert.deepEqual((await restarted.availability(listener,{online:true})).availability,prefs(true,false,true));
  assert.deepEqual((await restarted.availability(listener,{online:true,videoEnabled:false})).availability,prefs(true,false,false));
  await restarted.mode(listener,{mode:'customer'});await restarted.mode(listener,{mode:'listener'});
  assert.deepEqual((await restarted.user(listener.id)).availability,prefs(false,false,false));
  assert.deepEqual((await restarted.availability(listener,{online:true,audioEnabled:true})).availability,prefs(true,true,false));
});

test('HTTP accepts optional preferences, validates the public DTO and rejects malformed patches atomically',async()=>{
  const listener=await h.participant(true),contract=require('@nightshift/contracts/openapi.json');
  const definitions=JSON.parse(JSON.stringify(contract.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);const validate=ajv.compile({$defs:definitions,$ref:'#/$defs/User'});
  await withHttp(async(_runtime,_base,request)=>{
    const changed=await request('me/availability',listener,'PUT',prefs(true,false,true));
    assert.equal(changed.status,200);assert.deepEqual(changed.body.availability,prefs(true,false,true));
    assert.equal(validate(changed.body),true,JSON.stringify(validate.errors));
    const legacy=await request('me/availability',listener,'PUT',{online:false});
    assert.equal(legacy.status,200);assert.deepEqual(legacy.body.availability,prefs(false,false,true));
    for(const body of [{audioEnabled:true},{online:null},{online:'true'},{online:true,audioEnabled:null},
      {online:true,audioEnabled:1},{online:true,videoEnabled:'false'},{online:true,audioAvailable:true},{online:true,userId:listener.id}]){
      const denied=await request('me/availability',listener,'PUT',body);assert.equal(denied.status,400);
      assert.deepEqual((await h.service.user(listener.id)).availability,prefs(false,false,true));
    }
    assert.equal((await request('me/availability',undefined,'PUT',{online:true})).status,401);
    const current=await request('me',listener);assert.equal(current.status,200);assert.deepEqual(current.body.availability,prefs(false,false,true));
  });
});

test('preference changes require approved current Listener authority, including replayed old actors',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);
  await assert.rejects(h.service.availability(customer,prefs(true,false,false)),{code:'LISTENER_NOT_APPROVED'});
  await h.db.pool.query('UPDATE users SET listener_approved=false WHERE id=$1',[listener.id]);
  await assert.rejects(h.service.availability(listener,prefs(true,false,false)),{code:'LISTENER_NOT_APPROVED'});
  await h.db.pool.query('UPDATE users SET listener_approved=true WHERE id=$1',[listener.id]);
  const fresh=await h.refresh(listener,true);
  await assert.rejects(h.service.availability(listener,prefs(true,false,false)),{code:'UNAUTHENTICATED'});
  assert.deepEqual((await h.service.user(listener.id)).availability,prefs(true,true,true));
  await h.service.availability(fresh,prefs(true,false,true));await h.auth.logout(fresh,c=>h.service.logoutCall(fresh,c));
  await assert.rejects(h.service.availability(fresh,prefs(true,true,false)),{code:'UNAUTHENTICATED'});
});

test('effective directory availability is the OR of eligible media while master offline disables both',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);
  for(const [audio,video] of [[false,false],[true,false],[false,true],[true,true]] as const){
    await h.service.availability(listener,prefs(true,audio,video));const current=await card(customer,listener);
    assert.equal(current.audioAvailable,audio);assert.equal(current.videoAvailable,video);assert.equal(current.available,audio||video);
    const only=(await h.service.directory.page(customer,{availableOnly:true})).items;
    assert.equal(only.some(item=>item.id===listener.id),audio||video);
  }
  await h.service.availability(listener,{online:false});const offline=await card(customer,listener);
  assert.equal(offline.audioAvailable,false);assert.equal(offline.videoAvailable,false);assert.equal(offline.available,false);
  assert.deepEqual((await h.service.user(listener.id)).availability,prefs(false,true,true));
});

test('server video gate overrides a stored preference and rejected explicit enable changes nothing',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);h.config.videoCallsEnabled=false;
  const initial=await card(customer,listener);assert.equal(initial.audioAvailable,true);assert.equal(initial.videoAvailable,false);assert.equal(initial.videoRate,null);
  assert.deepEqual((await h.service.availability(listener,{online:true,audioEnabled:false})).availability,prefs(true,false,true));
  assert.equal((await card(customer,listener)).available,false);
  await assert.rejects(h.service.availability(listener,{online:false,audioEnabled:true,videoEnabled:true}),{status:503,code:'VIDEO_UNAVAILABLE'});
  assert.deepEqual((await h.service.user(listener.id)).availability,prefs(true,false,true));
  await assert.rejects(h.service.createCall(customer,callBody(listener,'video'),randomUUID()),{code:'VIDEO_UNAVAILABLE'});
  assert.deepEqual(await reservations(customer),{calls:0,claims:0,holds:0});
  assert.deepEqual((await h.service.availability(listener,{online:true,videoEnabled:false})).availability,prefs(true,false,false));
});

for(const disabled of ['audio','video'] as const)test(`direct ${disabled} admission rejects an opted-out channel without reserving credits`,async()=>{
  const customer=await h.participant(),listener=await h.participant(true);
  await h.service.availability(listener,prefs(true,disabled!=='audio',disabled!=='video'));
  await assert.rejects(h.service.createCall(customer,callBody(listener,disabled),randomUUID()),{status:409,code:'LISTENER_MEDIA_UNAVAILABLE'});
  assert.deepEqual(await reservations(customer),{calls:0,claims:0,holds:0});
  const allowed=disabled==='audio'?'video':'audio',call=await h.service.createCall(customer,callBody(listener,allowed),randomUUID());
  assert.equal(call.state,'ringing');assert.equal(call.mediaType,allowed);assert.equal(call.chargeMicrocredits,0);
});

for(const media of ['audio','video'] as const)test(`turning preferences off does not terminate a ringing or accepted ${media} call`,async()=>{
  const customer=await h.participant(),listener=await h.participant(true),call=await h.service.createCall(customer,callBody(listener,media),randomUUID());
  await h.service.availability(listener,prefs(true,false,false));
  assert.equal((await h.service.call(customer.id,call.id)).state,'ringing');
  const accepted=await h.service.action(listener,call.id,'accept',{expectedVersion:call.version,...(media==='video'?{videoConsent:true}:{})},randomUUID());
  assert.equal(accepted.state,'connecting');
  const ready={ready:true,...(media==='video'?{videoReady:true}:{})};
  await h.service.media(customer,call.id,ready);const connected=await h.service.media(listener,call.id,ready);assert.equal(connected.state,'connected');
  assert.equal((await h.service.rtcToken(listener,call.id)).mediaType,media);
  assert.deepEqual((await h.service.user(listener.id)).availability,prefs(true,false,false));
  const ended=await h.service.action(customer,call.id,'end',{expectedVersion:connected.version},randomUUID());assert.equal(ended.state,'ended');
});

test('audio matching ignores a video-only Listener and rings the audio-enabled candidate',async()=>{
  const customer=await h.participant(),video=await h.participant(true),audio=await h.participant(true);
  await h.service.availability(video,prefs(true,false,true));await h.service.availability(audio,prefs(true,true,false));
  await h.service.matching.start(customer,matchBody(),randomUUID());await h.service.matching.processPending();
  const request=(await h.service.matching.current(customer)).request!;assert.equal(request.state,'ringing');assert.ok(request.currentCallId);
  const call=await h.service.call(customer.id,request.currentCallId);assert.equal(call.listenerId,audio.id);assert.equal(call.mediaType,'audio');
  assert.equal((await h.db.pool.query('SELECT count(*)::int total FROM matching_attempts WHERE listener_id=$1',[video.id])).rows[0].total,0);
});

test('video-only supply exhausts audio matching without a call, hold or charge',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);await h.service.availability(listener,prefs(true,false,true));
  const balance=await h.service.wallet(customer.id);await h.service.matching.start(customer,matchBody(),randomUUID());await h.service.matching.processPending();
  const result=(await h.service.matching.current(customer)).request!;assert.equal(result.state,'exhausted');assert.equal(result.terminalReason,'no_supply');
  assert.deepEqual(await reservations(customer),{calls:0,claims:0,holds:0});assert.deepEqual(await h.service.wallet(customer.id),balance);
});

test('audio opt-out rejects notification activation but preserves the prepared binding',async()=>{
  const listener=await h.participant(true),registration=await prepare(listener);await h.service.availability(listener,prefs(true,false,true));
  await assert.rejects(h.service.push.activate(listener,activation(registration),randomUUID()),{code:'LISTENER_NOT_APPROVED'});
  assert.equal((await h.service.push.get(listener)).registration!.state,'prepared');
  await h.service.availability(listener,{online:true,audioEnabled:true});
  assert.equal((await h.service.push.activate(listener,activation(registration),randomUUID())).state,'active');
});

test('a retained background invitation binding cannot supply either media after Audio is off',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);await register(listener);await h.presence.clear(listener.id);
  const initial=await card(customer,listener);assert.equal(initial.reachability,'background_eligible');assert.equal(initial.audioAvailable,true);assert.equal(initial.videoAvailable,false);
  await h.service.availability(listener,prefs(true,false,true));await h.presence.clear(listener.id);
  const changed=await card(customer,listener);assert.equal(changed.available,false);assert.equal(changed.audioAvailable,false);assert.equal(changed.videoAvailable,false);
  assert.equal((await h.service.push.get(listener)).registration!.state,'active','The binding is retained for terminal dismissal, not media availability');
  await assert.rejects(h.service.createCall(customer,callBody(listener,'audio'),randomUUID()),{code:'LISTENER_OFFLINE'});
  await assert.rejects(h.service.createCall(customer,callBody(listener,'video'),randomUUID()),{code:'LISTENER_OFFLINE'});
  assert.deepEqual(await reservations(customer),{calls:0,claims:0,holds:0});
});

test('Audio off suppresses a queued invitation while a current terminal dismissal remains deliverable',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);await register(listener);
  const call=await h.service.createCall(customer,callBody(listener,'audio'),randomUUID());
  await h.service.availability(listener,prefs(true,false,true));await h.service.push.processPending();assert.equal(sent.length,0);
  await h.service.action(customer,call.id,'cancel',{expectedVersion:call.version},randomUUID());await h.service.push.processPending();
  assert.equal(sent.length,1);assert.equal(sent[0]!.data.type,'call.terminal');assert.equal(sent[0]!.data.callId,call.id);
});

test('Audio off during a provider pre-dispatch wait suppresses the old invitation at the final guard',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);await register(listener);
  const call=await h.service.createCall(customer,callBody(listener,'audio'),randomUUID()),entered=deferred(),release=deferred();
  beforeSend=async()=>{entered.release();await release.promise;};
  const pending=h.service.push.processPending(),outcome=Promise.allSettled([pending]);
  try{
    await bounded(entered.promise);await bounded(h.service.availability(listener,prefs(true,false,true)),'Preference update must not wait behind provider I/O');
    release.release();await pending;assert.equal(sent.length,0);
    beforeSend=undefined;await h.service.action(customer,call.id,'cancel',{expectedVersion:call.version},randomUUID());await h.service.push.processPending();
    assert.equal(sent.length,1);assert.equal(sent[0]!.data.type,'call.terminal');
  }finally{release.release();await outcome;beforeSend=undefined;}
});

test('visible directory updates recheck preferences changed during the Redis wait',async t=>{
  const customer=await h.participant(),listener=await h.participant(true),view=await h.service.directory.page(customer);
  const subscription={viewEpoch:view.viewEpoch,language:'ta',visibleIds:[listener.id]};await h.service.directory.subscribe(customer,subscription);
  const entered=deferred(),release=deferred(),original=h.presence.online.bind(h.presence);let once=false;
  const mock=t.mock.method(h.presence,'online',async(...args:Parameters<typeof original>)=>{
    const value=await original(...args);if(!once&&args[0].includes(listener.id)){once=true;entered.release();await release.promise;}return value;
  });
  const pending=h.service.directory.updates(customer,subscription),outcome=Promise.allSettled([pending]);
  try{
    await bounded(entered.promise);await bounded(h.service.availability(listener,prefs(true,false,true)));release.release();
    const current=(await pending).items.find(row=>row.id===listener.id);assert.ok(current);assert.equal(current.audioAvailable,false);
    mock.mock.restore();const next=(await h.service.directory.updates(customer,subscription)).items[0]!;
    assert.equal(next.audioAvailable,false);assert.equal(next.videoAvailable,true);assert.equal(next.available,true);
  }finally{release.release();await outcome;mock.mock.restore();}
});

test('an authenticated visible-slice socket receives independent channel changes after HTTP persistence',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);
  await withHttp(async(runtime,base,request)=>{
    const view=await runtime.service.directory.page(customer),socket=io(base,{transports:['websocket'],auth:{token:customer.token},reconnection:false,autoConnect:false});
    try{
      const connected=event(socket,'connect');socket.connect();await connected;
      const initial=event(socket,'directory.updated',value=>value.viewEpoch===view.viewEpoch&&value.items[0]?.audioAvailable===true);
      const ack=await socket.timeout(5000).emitWithAck('directory.subscribe',{viewEpoch:view.viewEpoch,language:'ta',visibleIds:[listener.id]});assert.equal(ack.ok,true);await initial;
      const changed=event(socket,'directory.updated',value=>value.viewEpoch===view.viewEpoch&&value.items[0]?.audioAvailable===false&&value.items[0]?.videoAvailable===true);
      const response=await request('me/availability',listener,'PUT',{online:true,audioEnabled:false});assert.equal(response.status,200);
      const update=await changed;assert.deepEqual(update.items.map((item:any)=>item.id),[listener.id]);assert.equal(update.items[0].available,true);
      assert.deepEqual(response.body.availability,prefs(true,false,true));
    }finally{socket.close();}
  });
});
