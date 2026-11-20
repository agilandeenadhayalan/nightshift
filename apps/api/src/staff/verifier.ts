import { ApiError, requireThat } from '../errors';

/** Implementations must verify signatures and provider revocation, and return
 * provider-attested methods, never client-supplied roles or assurance flags. */
export interface VerifiedStaffSignIn {
  issuer:string;audience:string;tenant:string;subject:string;
  authTime:number;issuedAt:number;expiresAt:number;authenticationMethods:string[];
}
export interface StaffIdentityReference {issuer:string;audience:string;tenant:string;subject:string;}
export interface CurrentStaffIdentity extends StaffIdentityReference {disabled:boolean;validAfter:number;}
export interface StaffIdentityVerifier {
  verifySignIn(proof:string):Promise<VerifiedStaffSignIn>;
  currentIdentity(identity:StaffIdentityReference):Promise<CurrentStaffIdentity>;
}
export interface StaffPolicy {
  issuer:string;audience:string;tenant:string;origin:string;version:string;digestKey:string;
  requiredMethods:readonly string[];maxAuthenticationAgeSeconds:number;sessionSeconds:number;
  challengeSeconds:number;challengeLimitPerHour:number;clientChallengeLimitPerHour:number;
  verificationTimeoutMs:number;maxConcurrentVerifications:number;
}
export const unavailable=()=>new ApiError(503,'STAFF_AUTH_UNAVAILABLE','Staff access is not available.');
export const unauthenticated=()=>new ApiError(401,'STAFF_UNAUTHENTICATED','Sign in to staff access again.');
const integer=(n:unknown,min:number,max:number)=>Number.isSafeInteger(n)&&Number(n)>=min&&Number(n)<=max;
export function validateStaffPolicy(p:StaffPolicy){
  let origin:URL;try{origin=new URL(p.origin);}catch{throw unavailable();}
  requireThat(origin.protocol==='https:'&&origin.origin===p.origin&&!origin.username&&!origin.password
    &&p.issuer.length>0&&p.issuer.length<=300&&p.audience.length>0&&p.audience.length<=200
    &&p.tenant.length<=128&&/^[A-Za-z0-9._-]{1,80}$/.test(p.version)&&p.digestKey.length>=32&&p.digestKey.length<=256
    &&p.requiredMethods.length>0&&p.requiredMethods.length<=8&&new Set(p.requiredMethods).size===p.requiredMethods.length
    &&p.requiredMethods.every(m=>/^[a-z][a-z0-9_-]{0,39}$/.test(m))
    &&integer(p.maxAuthenticationAgeSeconds,1,3600)&&integer(p.sessionSeconds,1,86400)
    &&integer(p.challengeSeconds,1,600)&&integer(p.challengeLimitPerHour,1,1000)
    &&integer(p.clientChallengeLimitPerHour,1,p.challengeLimitPerHour)
    &&integer(p.verificationTimeoutMs,1,6000)&&integer(p.maxConcurrentVerifications,1,32),
    503,'STAFF_AUTH_UNAVAILABLE','Staff access is not available.');
}
/** A timeout bounds the caller, not an uncancellable provider call. Keep its
 * capacity slot occupied until the actual promise settles. Never queue work. */
export class BoundedStaffVerifier {
  private inFlight=0;
  constructor(private readonly verifier:StaffIdentityVerifier,private readonly policy:StaffPolicy){}
  async run<T>(fn:(verifier:StaffIdentityVerifier)=>Promise<T>):Promise<T>{
    if(this.inFlight>=this.policy.maxConcurrentVerifications)throw unavailable();
    this.inFlight++;const pending=Promise.resolve().then(()=>fn(this.verifier));
    void pending.then(()=>{this.inFlight--;},()=>{this.inFlight--;});
    let timer:ReturnType<typeof setTimeout>|undefined;
    try{return await Promise.race([pending,new Promise<never>((_,reject)=>{timer=setTimeout(()=>reject(unavailable()),this.policy.verificationTimeoutMs);})]);}
    catch(error){if(error instanceof ApiError&&error.code==='STAFF_UNAUTHENTICATED')throw unauthenticated();throw unavailable();}
    finally{if(timer)clearTimeout(timer);}
  }
}
