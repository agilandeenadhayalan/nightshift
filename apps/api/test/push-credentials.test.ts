import {test} from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {dirname,join,resolve,basename} from 'node:path';
import {tmpdir} from 'node:os';
import {createPushAccessToken,PUSH_OAUTH_SCOPE} from '../src/push-credentials';

const project='isolated-push-project';
const email=`nightshift-push-sender@${project}.iam.gserviceaccount.com`;
const oauth='https://oauth2.googleapis.com/token';
const iam=`https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${email}:generateAccessToken`;
const key=generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({format:'pem',type:'pkcs8'}).toString();
const direct=()=>({type:'service_account',project_id:project,client_email:email,private_key:key,token_uri:oauth});
const delegated=()=>({type:'impersonated_service_account',service_account_impersonation_url:iam,delegates:[],
  source_credentials:{type:'authorized_user',client_id:'synthetic-client.apps.googleusercontent.com',client_secret:'synthetic-client-secret',refresh_token:'synthetic-refresh-token'}});
const oauthResponse=()=>Response.json({access_token:'synthetic-source-access',expires_in:3600,token_type:'Bearer'});
const senderResponse=()=>Response.json({accessToken:'synthetic-sender-access',expireTime:new Date(Date.now()+3600000).toISOString()});
async function fixture(body:unknown,run:(file:string)=>Promise<void>){
  const parent=resolve(tmpdir()),directory=await mkdtemp(join(parent,'nightshift-push-credential-test-'));
  try{const file=join(directory,'credential.json');await writeFile(file,JSON.stringify(body),{mode:0o600});await run(file);}
  finally{if(dirname(resolve(directory))!==parent||!basename(directory).startsWith('nightshift-push-credential-test-'))throw Error('Unexpected test directory');await rm(directory,{recursive:true,force:true});}
}
async function rejection(value:Promise<unknown>){await assert.rejects(value,(error:any)=>error?.message==='PUSH_CREDENTIAL_UNAVAILABLE');}

test('dedicated service-account JWT requests only messaging scope at the fixed OAuth origin and caches privately',async()=>fixture(direct(),async file=>{
  let requests=0;
  const provider=await createPushAccessToken(file,project,{fetch:async(url,init)=>{
    requests++;assert.equal(String(url),oauth);assert.equal(init?.redirect,'error');
    const body=new URLSearchParams(String(init?.body)),assertion=body.get('assertion')!;
    const claims=JSON.parse(Buffer.from(assertion.split('.')[1]!,'base64url').toString());
    assert.equal(claims.iss,email);assert.equal(claims.scope,PUSH_OAUTH_SCOPE);assert.equal(claims.aud,oauth);
    return oauthResponse();
  }});
  assert.equal(await provider.accessToken(),'synthetic-source-access');
  assert.equal(await provider.accessToken(),'synthetic-source-access');assert.equal(requests,1);await provider.close();
}));

test('impersonation uses the dedicated principal, fixed IAM endpoint and one messaging scope',async()=>fixture(delegated(),async file=>{
  const observed:string[]=[];
  const provider=await createPushAccessToken(file,project,{fetch:async(url,init)=>{
    observed.push(String(url));assert.equal(init?.redirect,'error');
    if(String(url)===oauth)return oauthResponse();
    assert.equal(String(url),iam);assert.equal(new Headers(init?.headers).get('authorization'),'Bearer synthetic-source-access');
    assert.deepEqual(JSON.parse(String(init?.body)),{scope:[PUSH_OAUTH_SCOPE],lifetime:'3600s',delegates:[]});return senderResponse();
  }});
  assert.equal(await provider.accessToken(),'synthetic-sender-access');
  assert.equal(await provider.accessToken(),'synthetic-sender-access');assert.deepEqual(observed,[oauth,iam]);await provider.close();
}));

test('concurrent callers share one real refresh operation',async()=>fixture(delegated(),async file=>{
  let requests=0;let release!:()=>void;const gate=new Promise<void>(done=>{release=done;});
  const provider=await createPushAccessToken(file,project,{fetch:async(url)=>{requests++;if(String(url)===oauth){await gate;return oauthResponse();}return senderResponse();}});
  const pending=Array.from({length:20},()=>provider.accessToken());await new Promise(done=>setTimeout(done,20));release();
  assert.ok((await Promise.all(pending)).every(token=>token==='synthetic-sender-access'));assert.equal(requests,2);await provider.close();
}));

test('timeout keeps refresh capacity occupied until an abort-ignoring fetch actually settles',async()=>fixture(delegated(),async file=>{
  let release!:(response:Response)=>void;const held=new Promise<Response>(done=>{release=done;});let requests=0;
  const provider=await createPushAccessToken(file,project,{timeoutMs:25,fetch:async()=>{requests++;return held;}});
  await rejection(provider.accessToken());await rejection(provider.accessToken());assert.equal(requests,1);
  release(oauthResponse());await new Promise(done=>setImmediate(done));
  // Aborted source auth must not proceed to IAM after its delayed response.
  assert.equal(requests,1);await provider.close();
}));

test('slow response-body timeout also retains its true operation slot',async()=>fixture(direct(),async file=>{
  let stream!:ReadableStreamDefaultController<Uint8Array>;let requests=0;
  const provider=await createPushAccessToken(file,project,{timeoutMs:25,fetch:async()=>{requests++;return new Response(new ReadableStream({start(c){stream=c;}}),{headers:{'content-type':'application/json'}});}});
  await rejection(provider.accessToken());await rejection(provider.accessToken());assert.equal(requests,1);
  stream.close();await new Promise(done=>setImmediate(done));await provider.close();
}));

test('provider errors do not retry OAuth or expose credentials or response text',async()=>fixture(delegated(),async file=>{
  let requests=0;const provider=await createPushAccessToken(file,project,{fetch:async()=>{requests++;return Response.json({error:'secret synthetic-refresh-token'},{status:503});}});
  await rejection(provider.accessToken());assert.equal(requests,1);await provider.close();
}));

test('a rejected response whose body cancellation stalls retains refresh capacity',async()=>fixture(direct(),async file=>{
  let release!:()=>void;const cancellation=new Promise<void>(done=>{release=done;});let requests=0;
  const provider=await createPushAccessToken(file,project,{timeoutMs:25,fetch:async()=>{requests++;
    return new Response(new ReadableStream({cancel(){return cancellation;}}),{status:503,headers:{'content-type':'application/json'}});
  }});
  await rejection(provider.accessToken());await rejection(provider.accessToken());assert.equal(requests,1);
  release();await new Promise(done=>setImmediate(done));await provider.close();
}));

test('IAM authorization failure does not trigger a hidden source refresh or repeat request',async()=>fixture(delegated(),async file=>{
  const urls:string[]=[];const provider=await createPushAccessToken(file,project,{fetch:async url=>{urls.push(String(url));return String(url)===oauth?oauthResponse():Response.json({error:{message:'private'}},{status:401});}});
  await rejection(provider.accessToken());assert.deepEqual(urls,[oauth,iam]);await provider.close();
}));

test('redirect, oversized body, invalid JSON and malformed token expiry fail closed',async()=>{
  for(const kind of ['redirect','large','json','expiry','token'])await fixture(direct(),async file=>{
    let requests=0;const provider=await createPushAccessToken(file,project,{fetch:async()=>{requests++;
      if(kind==='redirect')return new Response('',{status:302,headers:{Location:'https://attacker.invalid'}});
      if(kind==='large')return new Response('x'.repeat(65537),{headers:{'content-type':'application/json'}});
      if(kind==='json')return new Response('not json',{headers:{'content-type':'application/json'}});
      return Response.json({access_token:kind==='token'?'bad\nheader':'synthetic-access',expires_in:kind==='expiry'?-1:3600});
    }});await rejection(provider.accessToken());assert.equal(requests,1);await provider.close();
  });
});

test('close cancels public waiters, rejects future use and cannot allow delayed IAM dispatch',async()=>fixture(delegated(),async file=>{
  let release!:(response:Response)=>void;const held=new Promise<Response>(done=>{release=done;});let requests=0;
  const provider=await createPushAccessToken(file,project,{fetch:async()=>{requests++;return held;}});
  const pending=provider.accessToken();await new Promise(done=>setTimeout(done,10));const checked=rejection(pending);await provider.close();await checked;
  await rejection(provider.accessToken());release(oauthResponse());await new Promise(done=>setImmediate(done));assert.equal(requests,1);
}));

test('file configuration rejects ambient/user credentials, wrong identity/project, alternate URLs and delegates before any network',async()=>{
  const variants:any[]=[{type:'authorized_user'}, {...direct(),project_id:'wrong-project'}, {...direct(),client_email:`nightshift-auth-verifier@${project}.iam.gserviceaccount.com`},
    {...direct(),token_uri:'https://attacker.invalid/token'}, {...direct(),universe_domain:'attacker.invalid'},
    {...delegated(),delegates:['other']}, {...delegated(),service_account_impersonation_url:iam+'?extra=1'},
    {...delegated(),source_credentials:{...delegated().source_credentials,token_uri:'https://attacker.invalid'}},
    {...direct(),credential_source:{url:'http://169.254.169.254'}}];
  for(const body of variants)await fixture(body,async file=>{
    let requests=0;await rejection(createPushAccessToken(file,project,{fetch:async()=>{requests++;return oauthResponse();}}));assert.equal(requests,0);
  });
  await rejection(createPushAccessToken('relative.json',project));
});

test('oversized local credential data is rejected before parsing or networking',async()=>fixture({padding:'x'.repeat(65537)},async file=>{
  await rejection(createPushAccessToken(file,project));
}));
