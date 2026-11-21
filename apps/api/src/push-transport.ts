export interface PushPayload {schemaVersion:'1';type:'call.invitation'|'call.terminal';callId:string;eventId:string;callVersion:string;expiresAt:string;registrationId:string;registrationVersion:string;bindingId:string;}
export interface PushSend {token:string;data:PushPayload;deadlineAt:number;}
export interface PushOutcome {kind:'accepted'|'unregistered'|'retry'|'failed'|'unknown';code:string;messageId?:string;retryAfterMs?:number;}
export interface PushTransport {available():boolean;send(message:PushSend,beforeDispatch?:()=>Promise<boolean>):Promise<PushOutcome>;close?():Promise<void>;}
export interface FcmHttpOptions {projectId:string;packageName:string;accessToken:()=>Promise<string>;fetch?:typeof fetch;clock?:()=>number;timeoutMs?:number;maxConcurrent?:number;}
function validPayload(message:PushSend){
  const data=message.data as unknown as Record<string,unknown>,keys=['schemaVersion','type','callId','eventId','callVersion','expiresAt','registrationId','registrationVersion','bindingId'];
  const id=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  return data&&typeof data==='object'&&!Array.isArray(data)&&Object.keys(data).length===keys.length&&Object.keys(data).every(k=>keys.includes(k))
    &&data.schemaVersion==='1'&&typeof data.type==='string'&&['call.invitation','call.terminal'].includes(data.type)
    &&['callId','eventId','registrationId','bindingId'].every(k=>typeof data[k]==='string'&&id.test(data[k]))
    &&['callVersion','registrationVersion'].every(k=>typeof data[k]==='string'&&/^[1-9]\d{0,9}$/.test(data[k])&&Number(data[k])<=2147483647)
    &&typeof data.expiresAt==='string'&&Number.isFinite(message.deadlineAt)&&Date.parse(data.expiresAt)===message.deadlineAt
    &&new Date(message.deadlineAt).toISOString()===data.expiresAt&&Buffer.byteLength(JSON.stringify(data))<=2048;
}
export class FcmHttpTransport implements PushTransport {
  private readonly clock:()=>number;private readonly fetch:typeof fetch;private inFlight=0;private stopped=false;private unavailableUntil=0;
  private readonly controllers=new Set<AbortController>();
  constructor(private readonly options:FcmHttpOptions){
    if(!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(options.projectId)||options.packageName!=='com.agilandeenadhayalan.nightshift'
      ||!Number.isInteger(options.timeoutMs??10000)||(options.timeoutMs??10000)<1||(options.timeoutMs??10000)>10000
      ||!Number.isInteger(options.maxConcurrent??4)||(options.maxConcurrent??4)<1||(options.maxConcurrent??4)>4)throw Error('Invalid push transport configuration');
    this.clock=options.clock??Date.now;this.fetch=options.fetch??globalThis.fetch;
  }
  available(){return !this.stopped&&this.clock()>=this.unavailableUntil;}
  async close(){this.stopped=true;for(const controller of this.controllers)controller.abort();}
  async send(message:PushSend,beforeDispatch?:()=>Promise<boolean>):Promise<PushOutcome>{
    if(message.deadlineAt-this.clock()<1000)return{kind:'failed',code:'EXPIRED'};
    if(!this.available())return{kind:'failed',code:'UNAVAILABLE'};
    if(this.inFlight>=(this.options.maxConcurrent??4))return{kind:'failed',code:'BUSY'};
    if(typeof message.token!=='string'||!/^[!-~]{1,4096}$/.test(message.token)||!validPayload(message))return{kind:'failed',code:'INVALID_PAYLOAD'};
    // Keep the checked target/payload immutable across credential and DB waits.
    message={token:message.token,deadlineAt:message.deadlineAt,data:{...message.data}};
    const controller=new AbortController();this.controllers.add(controller);this.inFlight++;
    const progress={dispatched:false};
    let timer:ReturnType<typeof setTimeout>|undefined;
    const operation=this.dispatch(message,controller,progress,beforeDispatch).catch(()=>({kind:progress.dispatched?'unknown':'failed',code:progress.dispatched?'UNKNOWN':'CREDENTIAL_UNAVAILABLE'} as PushOutcome))
      .finally(()=>{this.inFlight--;this.controllers.delete(controller);});
    try{return await Promise.race([operation,new Promise<PushOutcome>(resolve=>{
      timer=setTimeout(()=>{controller.abort();resolve(progress.dispatched?{kind:'unknown',code:'TIMEOUT'}:{kind:'failed',code:'CREDENTIAL_UNAVAILABLE'});},Math.min(this.options.timeoutMs??10000,message.deadlineAt-this.clock()));
    })]);}finally{if(timer)clearTimeout(timer);}
  }
  private async dispatch(message:PushSend,controller:AbortController,progress:{dispatched:boolean},beforeDispatch?:()=>Promise<boolean>):Promise<PushOutcome>{
    const token=await this.options.accessToken();
    if(controller.signal.aborted||message.deadlineAt-this.clock()<1000||!this.available())return{kind:'failed',code:'EXPIRED'};
    if(typeof token!=='string'||!/^[!-~]{1,8192}$/.test(token))return{kind:'failed',code:'CREDENTIAL_UNAVAILABLE'};
    if(beforeDispatch&&!await beforeDispatch())return{kind:'failed',code:'SUPERSEDED'};
    const remaining=message.deadlineAt-this.clock();
    if(controller.signal.aborted||remaining<1000||!this.available())return{kind:'failed',code:'EXPIRED'};
    progress.dispatched=true;
    const response=await this.fetch(`https://fcm.googleapis.com/v1/projects/${this.options.projectId}/messages:send`,{
      method:'POST',redirect:'error',signal:controller.signal,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
      body:JSON.stringify({message:{token:message.token,data:message.data,android:{priority:message.data.type==='call.invitation'?'high':'normal',
        ttl:`${Math.min(30,Math.floor(remaining/1000))}s`,restricted_package_name:this.options.packageName,direct_boot_ok:false}}})});
    if(response.status>=300&&response.status<400){await response.body?.cancel();return{kind:'unknown',code:'INVALID_RESPONSE'};}
    if(!/^application\/json(?:;|$)/i.test(response.headers.get('content-type')??'')||Number(response.headers.get('content-length')??0)>65536){await response.body?.cancel();return{kind:'unknown',code:'INVALID_RESPONSE'};}
    const reader=response.body?.getReader();if(!reader)return{kind:'unknown',code:'INVALID_RESPONSE'};
    const parts:Uint8Array[]=[];let length=0;
    try{for(;;){const part=await reader.read();if(part.done)break;length+=part.value.length;if(length>65536){await reader.cancel();return{kind:'unknown',code:'INVALID_RESPONSE'};}parts.push(part.value);}}
    finally{reader.releaseLock();}
    let body:any;try{body=JSON.parse(Buffer.concat(parts).toString('utf8'));}catch{return{kind:'unknown',code:'INVALID_RESPONSE'};}
    if(response.ok){const prefix=`projects/${this.options.projectId}/messages/`;return typeof body?.name==='string'&&body.name.startsWith(prefix)&&/^[A-Za-z0-9._:%-]{1,300}$/.test(body.name.slice(prefix.length))
      ?{kind:'accepted',code:'ACCEPTED',messageId:body.name}:{kind:'unknown',code:'INVALID_RESPONSE'};}
    const details=Array.isArray(body?.error?.details)?body.error.details:[];
    const fcm=details.find((detail:any)=>detail?.['@type']==='type.googleapis.com/google.firebase.fcm.v1.FcmError')?.errorCode;
    if(response.status===404&&fcm==='UNREGISTERED')return{kind:'unregistered',code:'UNREGISTERED'};
    if(response.status===401||response.status===403){this.unavailableUntil=this.clock()+60000;return{kind:'failed',code:'CONFIGURATION'};}
    if([429,500,503].includes(response.status)){
      const hint=response.headers.get('retry-after')??'';const parsed=/^\d+$/.test(hint)?Number(hint)*1000:Date.parse(hint)-this.clock();
      const retryAfterMs=Math.max(response.status===429?60000:10000,Number.isFinite(parsed)?Math.min(86400000,Math.max(0,parsed)):0);
      if(response.status===429)this.unavailableUntil=this.clock()+retryAfterMs;
      return{kind:'retry',code:response.status===429?'QUOTA':'PROVIDER_UNAVAILABLE',retryAfterMs};
    }
    return{kind:'failed',code:'REJECTED'};
  }
}
