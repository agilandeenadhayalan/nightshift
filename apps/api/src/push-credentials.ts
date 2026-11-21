import {open} from 'node:fs/promises';
import {isAbsolute} from 'node:path';
import {createPrivateKey} from 'node:crypto';
import {JWT,UserRefreshClient} from 'google-auth-library';

export interface PushAccessToken {accessToken():Promise<string>;close():Promise<void>;}
export interface PushCredentialOptions {fetch?:typeof fetch;clock?:()=>number;timeoutMs?:number;}
export const PUSH_OAUTH_SCOPE='https://www.googleapis.com/auth/firebase.messaging';
const OAUTH='https://oauth2.googleapis.com/token';
const MAX_BYTES=65536;
const failure=()=>Error('PUSH_CREDENTIAL_UNAVAILABLE');
type RecordValue=Record<string,unknown>;
function object(value:unknown):RecordValue{
  if(!value||typeof value!=='object'||Array.isArray(value))throw failure();
  return value as RecordValue;
}
function fields(value:RecordValue,allowed:string[]){
  if(Object.keys(value).some(key=>!allowed.includes(key)))throw failure();
}
function text(value:unknown,max=8192):string{
  if(typeof value!=='string'||!value.length||value.length>max||!/^[!-~]+$/.test(value))throw failure();
  return value;
}
function universe(value:RecordValue){
  if(value.universe_domain!==undefined&&value.universe_domain!=='googleapis.com')throw failure();
}
async function readCredential(file:string):Promise<RecordValue>{
  if(!isAbsolute(file))throw failure();
  const handle=await open(file,'r');
  try{
    const stat=await handle.stat();if(!stat.isFile()||stat.size>MAX_BYTES)throw failure();
    const buffer=Buffer.alloc(MAX_BYTES+1);let count=0;
    while(count<buffer.length){const {bytesRead}=await handle.read(buffer,count,buffer.length-count,null);if(!bytesRead)break;count+=bytesRead;}
    if(count>MAX_BYTES)throw failure();
    return object(JSON.parse(buffer.subarray(0,count).toString('utf8')));
  }finally{await handle.close();}
}

/** Dedicated sender only; never fall back to the identity verifier or ambient ADC. */
export async function createPushAccessToken(file:string,project:string,options:PushCredentialOptions={}):Promise<PushAccessToken>{
  try{return await prepare(file,project,options);}catch{throw failure();}
}

async function prepare(file:string,project:string,options:PushCredentialOptions):Promise<PushAccessToken>{
  if(!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project)
    ||!Number.isInteger(options.timeoutMs??10000)||(options.timeoutMs??10000)<1||(options.timeoutMs??10000)>10000)throw failure();
  const credential=await readCredential(file),clock=options.clock??Date.now,fetcher=options.fetch??globalThis.fetch;
  const email=`nightshift-push-sender@${project}.iam.gserviceaccount.com`;
  const iam=`https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${email}:generateAccessToken`;
  universe(credential);
  let closed=false,active:AbortController|undefined,pending:Promise<string>|undefined;
  let cached:{token:string;expires:number}|undefined;

  // Public auth-library transporter injection, with an exact endpoint boundary.
  // Buffer the whole small response under the refresh deadline: headers alone
  // cannot release a capacity slot while a stalled body is still being read.
  const boundedFetch:typeof fetch=async(input,init)=>{
    const controller=active,url=String(input);
    if(closed||!controller||controller.signal.aborted||![OAUTH,iam].includes(url)||init?.method!=='POST')throw failure();
    const response=await fetcher(url,{method:'POST',headers:init.headers,body:init.body,
      redirect:'error',signal:controller.signal,credentials:'omit'});
    if(controller.signal.aborted||closed){await response.body?.cancel().catch(()=>{});throw failure();}
    if(!response.ok||!/^application\/json(?:;|$)/i.test(response.headers.get('content-type')??'')
      ||Number(response.headers.get('content-length')??0)>MAX_BYTES){await response.body?.cancel().catch(()=>{});throw failure();}
    const reader=response.body?.getReader();if(!reader)throw failure();
    const chunks:Uint8Array[]=[];let bytes=0;
    try{
      for(;;){
        const part=await reader.read();if(controller.signal.aborted||closed)throw failure();if(part.done)break;
        bytes+=part.value.length;if(bytes>MAX_BYTES)throw failure();chunks.push(part.value);
      }
    }catch{await reader.cancel().catch(()=>{});throw failure();}finally{reader.releaseLock();}
    const body=Buffer.concat(chunks);object(JSON.parse(body.toString('utf8')));
    return new Response(body,{status:response.status,headers:{'content-type':'application/json'}});
  };
  const transport={fetchImplementation:boundedFetch,retry:false,timeout:10000,maxRedirects:0,maxContentLength:MAX_BYTES};
  let client:JWT|UserRefreshClient;
  const impersonated=credential.type==='impersonated_service_account';
  if(credential.type==='service_account'){
    fields(credential,['type','project_id','private_key_id','private_key','client_email','client_id','auth_uri','token_uri',
      'auth_provider_x509_cert_url','client_x509_cert_url','universe_domain']);
    if(credential.project_id!==project||credential.client_email!==email
      ||(credential.token_uri!==undefined&&credential.token_uri!==OAUTH)
      ||(credential.auth_uri!==undefined&&credential.auth_uri!=='https://accounts.google.com/o/oauth2/auth')
      ||(credential.auth_provider_x509_cert_url!==undefined&&credential.auth_provider_x509_cert_url!=='https://www.googleapis.com/oauth2/v1/certs')
      ||(credential.client_x509_cert_url!==undefined&&credential.client_x509_cert_url!==`https://www.googleapis.com/robot/v1/metadata/x509/${encodeURIComponent(email)}`))throw failure();
    if(typeof credential.private_key!=='string'||credential.private_key.length>16384)throw failure();
    const key=createPrivateKey(credential.private_key),bits=key.asymmetricKeyDetails?.modulusLength??0;
    if(key.asymmetricKeyType!=='rsa'||bits<2048||bits>4096)throw failure();
    client=new JWT({email,key:credential.private_key,scopes:[PUSH_OAUTH_SCOPE],eagerRefreshThresholdMillis:60000,
      forceRefreshOnFailure:false,transporterOptions:transport});
  }else if(impersonated){
    fields(credential,['type','service_account_impersonation_url','source_credentials','delegates','quota_project_id','universe_domain']);
    if(credential.service_account_impersonation_url!==iam
      ||(credential.delegates!==undefined&&(!Array.isArray(credential.delegates)||credential.delegates.length!==0))
      ||(credential.quota_project_id!==undefined&&credential.quota_project_id!==project))throw failure();
    const source=object(credential.source_credentials);universe(source);
    fields(source,['type','client_id','client_secret','refresh_token','quota_project_id','universe_domain']);
    if(source.type!=='authorized_user'||(source.quota_project_id!==undefined&&source.quota_project_id!==project))throw failure();
    client=new UserRefreshClient({clientId:text(source.client_id,512),clientSecret:text(source.client_secret,512),
      refreshToken:text(source.refresh_token),eagerRefreshThresholdMillis:60000,forceRefreshOnFailure:false,transporterOptions:transport});
  }else throw failure();
  // The library's request-level RETRY_CONFIG overrides constructor defaults.
  // Its public interceptor enforces zero retries at the actual dispatch point.
  client.transporter.interceptors.request.add({resolved:async request=>{
    request.retry=false;request.retryConfig={retry:0,noResponseRetries:0};request.maxRedirects=0;
    request.timeout=10000;request.fetchImplementation=boundedFetch;return request;
  }});
  function validExpiry(expires:number){
    if(!Number.isFinite(expires)||expires<=clock()+60000||expires>clock()+3660000)throw failure();return expires;
  }
  async function refresh(controller:AbortController):Promise<string>{
    const source=await client.getAccessToken();
    if(closed||controller.signal.aborted)throw failure();
    let token=text(source.token),expires=validExpiry(Number(client.credentials.expiry_date));
    if(impersonated){
      // Avoid OAuth2Client.request's automatic 401 replay for this one bounded
      // IAM operation. No endpoint, delegate, scope or principal comes from callers.
      const response=await boundedFetch(iam,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
        body:JSON.stringify({scope:[PUSH_OAUTH_SCOPE],lifetime:'3600s',delegates:[]})});
      const body=object(await response.json());token=text(body.accessToken);expires=validExpiry(Date.parse(String(body.expireTime)));
    }
    if(closed||controller.signal.aborted)throw failure();
    cached={token,expires};return token;
  }
  return {
    async accessToken(){
      if(closed)throw failure();
      if(cached&&cached.expires>clock()+60000)return cached.token;
      if(pending)return pending;
      const controller=new AbortController();active=controller;
      let rejectAbort!:()=>void;
      const aborted=new Promise<never>((_,reject)=>{rejectAbort=()=>reject(failure());controller.signal.addEventListener('abort',rejectAbort,{once:true});});
      const timer=setTimeout(()=>controller.abort(),options.timeoutMs??10000);
      // A timeout settles public callers, but the underlying-operation slot is
      // retained until fetch/body/SDK work actually settles (even if abort is ignored).
      const work=refresh(controller).catch(()=>{throw failure();}).finally(()=>{
        clearTimeout(timer);controller.signal.removeEventListener('abort',rejectAbort);
        if(active===controller){active=undefined;pending=undefined;}
      });
      pending=Promise.race([work,aborted]);return pending;
    },
    async close(){closed=true;cached=undefined;active?.abort();},
  };
}
