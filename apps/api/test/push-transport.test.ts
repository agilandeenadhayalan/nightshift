import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import path from 'node:path';
import {FcmHttpTransport,PushSend} from '../src/push-transport';
const now=Date.parse('2026-11-21T00:00:00Z');
const message=():PushSend=>({token:'synthetic-registration-token',deadlineAt:now+30000,data:{schemaVersion:'1',type:'call.invitation',callId:'11111111-1111-4111-8111-111111111111',eventId:'22222222-2222-4222-8222-222222222222',callVersion:'1',expiresAt:new Date(now+30000).toISOString(),registrationId:'33333333-3333-4333-8333-333333333333',registrationVersion:'1',bindingId:'44444444-4444-4444-8444-444444444444'}});
const options={projectId:'isolated-push-project',packageName:'com.agilandeenadhayalan.nightshift',clock:()=>now,accessToken:async()=>'synthetic-oauth'};
test('FCM transport sends a fixed-origin data-only bounded Android invitation and records acceptance',async()=>{
  let observed:unknown;
  const transport=new FcmHttpTransport({...options,fetch:async(url,init)=>{observed={url:String(url),init,body:JSON.parse(String(init?.body))};return Response.json({name:'projects/isolated-push-project/messages/synthetic'});}});
  const result=await transport.send(message());assert.deepEqual(result,{kind:'accepted',code:'ACCEPTED',messageId:'projects/isolated-push-project/messages/synthetic'});
  const sent=observed as any;assert.equal(sent.url,'https://fcm.googleapis.com/v1/projects/isolated-push-project/messages:send');assert.equal(sent.init.redirect,'error');
  assert.deepEqual(sent.body.message.android,{priority:'high',ttl:'30s',restricted_package_name:'com.agilandeenadhayalan.nightshift',direct_boot_ok:false});
  assert.equal(sent.body.message.token,'synthetic-registration-token');assert.equal(sent.body.message.notification,undefined);assert.equal(sent.body.message.data.schemaVersion,'1');
});
for(const [status,error,want]of [[404,{status:'NOT_FOUND',details:[{'@type':'type.googleapis.com/google.firebase.fcm.v1.FcmError',errorCode:'UNREGISTERED'}]},'unregistered'],[404,{status:'NOT_FOUND'},'failed'],[400,{status:'INVALID_ARGUMENT'},'failed'],[403,{status:'PERMISSION_DENIED'},'failed'],[503,{status:'UNAVAILABLE'},'retry'],[500,{status:'INTERNAL'},'retry']]as const)
test(`FCM response ${status}/${JSON.stringify(error)} uses safe classification without reflecting provider text`,async()=>{
  const transport=new FcmHttpTransport({...options,fetch:async()=>Response.json({error:{...error,message:'synthetic-registration-token secret'}},{status})});
  const result=await transport.send(message());assert.equal(result.kind,want);assert.ok(!JSON.stringify(result).includes('synthetic-registration-token'));assert.ok(!JSON.stringify(result).includes('secret'));
});
test('quota Retry-After is honored and no implicit send retry occurs',async()=>{
  let requests=0;const transport=new FcmHttpTransport({...options,fetch:async()=>{requests++;return Response.json({error:{status:'RESOURCE_EXHAUSTED'}},{status:429,headers:{'Retry-After':'120'}});}});
  const result=await transport.send(message());assert.equal(result.kind,'retry');assert.equal(result.retryAfterMs,120000);assert.equal(requests,1);
});
test('expired and subsecond invitations never acquire credentials or dispatch',async()=>{
  let requests=0;const transport=new FcmHttpTransport({...options,accessToken:async()=>{requests++;return 'secret';},fetch:async()=>{requests++;return Response.json({});}});
  for(const delta of [-1,0,999])assert.equal((await transport.send({...message(),deadlineAt:now+delta})).code,'EXPIRED');assert.equal(requests,0);
});
test('timeout reports unknown and retains the actual in-flight slot until the provider operation settles',async()=>{
  let release!:(response:Response)=>void;const held=new Promise<Response>(resolve=>{release=resolve;});let calls=0;
  const transport=new FcmHttpTransport({...options,timeoutMs:20,maxConcurrent:1,fetch:async()=>{calls++;return calls===1?held:Response.json({name:'projects/isolated-push-project/messages/fresh'});}});
  const first=await transport.send(message());assert.equal(first.kind,'unknown');assert.equal((await transport.send(message())).code,'BUSY');assert.equal(calls,1);
  release(Response.json({name:'projects/isolated-push-project/messages/late'}));await new Promise(resolve=>setImmediate(resolve));
  assert.equal((await transport.send(message())).kind,'accepted');assert.equal(calls,2);
});
test('redirects and oversized or malformed successful bodies remain unknown rather than accepted',async()=>{
  for(const response of [new Response('',{status:302,headers:{Location:'https://attacker.invalid'}}),new Response('x'.repeat(65537),{headers:{'Content-Type':'application/json'}}),Response.json({name:'projects/other-project/messages/wrong'}),Response.json({})]){
    const transport=new FcmHttpTransport({...options,fetch:async()=>response});const result=await transport.send(message());assert.equal(result.kind,'unknown');
  }
});
test('runtime payload validation prevents extra private fields or malformed version and expiry from leaving the server',async()=>{
  let observed=0;const transport=new FcmHttpTransport({...options,accessToken:async()=>{observed++;return 'synthetic-oauth';},fetch:async()=>{observed++;return Response.json({name:'projects/isolated-push-project/messages/invalid'});}});
  for(const change of [{phone:'+910000000000'},{schemaVersion:'2'},{type:'call.accept'},{type:['call.invitation']},{callId:'../private'},{eventId:17},{callVersion:'01'},{registrationVersion:'-1'},{expiresAt:'not-a-date'},{expiresAt:new Date(now+60000).toISOString()}]){
    assert.equal((await transport.send({...message(),data:{...message().data,...change} as any})).code,'INVALID_PAYLOAD');
  }
  assert.equal(observed,0);
});
test('credential failure before dispatch is unavailable rather than unknown delivery',async()=>{
  let dispatched=false;const transport=new FcmHttpTransport({...options,accessToken:async()=>{throw Error('private credential detail');},fetch:async()=>{dispatched=true;return Response.json({});}});
  assert.deepEqual(await transport.send(message()),{kind:'failed',code:'CREDENTIAL_UNAVAILABLE'});assert.equal(dispatched,false);
});

test('sender accepts the shared valid payloads and rejects shared malformed/expired payloads',async()=>{
  const fixture=JSON.parse(readFileSync(path.resolve(__dirname,'../../../../packages/contracts/fixtures/call-invitations.json'),'utf8'));
  for(const item of fixture.cases){
    const data={...fixture.payload,...item.override};let dispatched=false;
    const transport=new FcmHttpTransport({...options,clock:()=>Date.parse(fixture.serverTime),fetch:async()=>{dispatched=true;return Response.json({name:'projects/isolated-push-project/messages/shared'});}});
    const result=await transport.send({token:'synthetic-shared-token',data,deadlineAt:Date.parse(data.expiresAt)});
    // Binding/target ownership is checked in DB preflight and on the receiver;
    // structurally valid alternate bindings are not invalid wire payloads.
    const valid=['valid invitation','valid terminal','wrong binding','wrong registration generation'].includes(item.name);
    assert.equal(dispatched,valid,item.name);assert.equal(result.kind==='accepted',valid,item.name);
  }
});

test('the final authorization callback runs after credential acquisition and prevents a revoked send',async()=>{
  let credentials=false,checks=0,requests=0;
  const transport=new FcmHttpTransport({...options,accessToken:async()=>{credentials=true;return 'synthetic-oauth';},fetch:async()=>{requests++;return Response.json({name:'projects/isolated-push-project/messages/wrong'});}});
  const result=await (transport.send as any)(message(),async()=>{assert.equal(credentials,true);checks++;return false;});
  assert.equal(checks,1);assert.equal(requests,0);assert.equal(result.code,'SUPERSEDED');
});

test('a timed-out final authorization callback cannot dispatch when its late result is valid',async()=>{
  let release!:(value:boolean)=>void,entered!:()=>void;const held=new Promise<boolean>(resolve=>{release=resolve;}),waiting=new Promise<void>(resolve=>{entered=resolve;});let requests=0;
  const transport=new FcmHttpTransport({...options,timeoutMs:20,maxConcurrent:1,fetch:async()=>{requests++;return Response.json({name:'projects/isolated-push-project/messages/wrong'});}});
  const pending=(transport.send as any)(message(),async()=>{entered();return held;});
  await Promise.race([waiting,new Promise<void>(resolve=>setTimeout(resolve,40))]);const result=await pending;
  assert.notEqual(result.kind,'accepted');assert.equal((await transport.send(message())).code,'BUSY');
  release(true);await new Promise(resolve=>setImmediate(resolve));assert.equal(requests,0);
});

test('the checked wire payload cannot be replaced while credentials are pending',async()=>{
  let release!:(token:string)=>void;const held=new Promise<string>(resolve=>{release=resolve;});let received:any;
  const transport=new FcmHttpTransport({...options,accessToken:()=>held,fetch:async(_url,init)=>{received=JSON.parse(String(init?.body));return Response.json({name:'projects/isolated-push-project/messages/immutable'});}});
  const original=message(),pending=transport.send(original);
  (original.data as any).phone='private-injected-phone';original.token='different-target';
  release('synthetic-oauth');await pending;
  assert.equal(received.message.data.phone,undefined);assert.equal(received.message.token,'synthetic-registration-token');
});
