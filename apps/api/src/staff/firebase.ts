import { createHmac,randomUUID } from 'node:crypto';
import { applicationDefault,deleteApp,initializeApp } from 'firebase-admin/app';
import { Auth as FirebaseAuth,getAuth } from 'firebase-admin/auth';
import { FirebaseIdentityProvider } from '../identity/firebase';
import { StaffIdentityReference,StaffIdentityVerifier,unauthenticated,unavailable } from './verifier';

/** Real Admin SDK adapter. No custom claims, caller roles, or email matching. */
export class FirebaseStaffVerifier implements StaffIdentityVerifier {
  private readonly identity:FirebaseIdentityProvider;
  constructor(private readonly client:Pick<FirebaseAuth,'verifyIdToken'|'getUser'|'createCustomToken'>,
    private readonly projectId:string,private readonly phoneDigestKey:string,clock:()=>number=Date.now){this.identity=new FirebaseIdentityProvider(client,projectId,clock);}
  async verifySignIn(proof:string){
    let identity;try{identity=await this.identity.verifyIdToken(proof);}catch{throw unauthenticated();}
    if(identity.signInProvider!=='phone'||!/^\+91[6-9]\d{9}$/.test(identity.phoneNumber??''))throw unauthenticated();
    return {issuer:identity.issuer,audience:identity.audience,tenant:'',subject:identity.uid,authTime:identity.authTime,
      issuedAt:identity.issuedAt,expiresAt:identity.expiresAt,authenticationMethods:['sms']};
  }
  async currentIdentity(identity:StaffIdentityReference){
    if(process.env.FIREBASE_AUTH_EMULATOR_HOST!==undefined||identity.issuer!==`https://securetoken.google.com/${this.projectId}`
      ||identity.audience!==this.projectId||identity.tenant!=='')throw unauthenticated();
    let user;try{user=await this.client.getUser(identity.subject);}catch(error){
      const code=(error as {code?:string})?.code;
      if(code==='auth/user-not-found'||code==='auth/user-disabled')throw unauthenticated();throw unavailable();
    }
    const validAfter=user.tokensValidAfterTime?Math.floor(Date.parse(user.tokensValidAfterTime)/1000):0;
    if(user.uid!==identity.subject||user.tenantId!==undefined||!/^\+91[6-9]\d{9}$/.test(user.phoneNumber??'')||!Number.isSafeInteger(validAfter))throw unauthenticated();
    return {...identity,disabled:user.disabled,validAfter,
      phoneDigest:createHmac('sha256',this.phoneDigestKey).update(`${this.projectId}\0phone\0${user.phoneNumber}`).digest('hex')};
  }
}
export function createFirebaseStaffVerifier(projectId:string,phoneDigestKey:string){
  if(process.env.FIREBASE_AUTH_EMULATOR_HOST!==undefined)throw unavailable();
  const app=initializeApp({projectId,credential:applicationDefault()},`nightshift-staff-${randomUUID()}`);
  return {verifier:new FirebaseStaffVerifier(getAuth(app),projectId,phoneDigestKey),close:()=>deleteApp(app)};
}
