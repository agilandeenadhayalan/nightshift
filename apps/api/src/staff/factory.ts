import { Auth } from '../auth';
import { Config } from '../config';
import { Database } from '../db';
import { StaffAuthority } from './authority';
import { StaffAppBinding } from './app-binding';
import { createFirebaseStaffVerifier } from './firebase';
import { StaffPolicy,unavailable,validateStaffPolicy } from './verifier';

export function createStaffAuthority(db:Database,auth:Auth,config:Config,clock:()=>number=Date.now){
  if(!config.staffAuth)return {authority:new StaffAuthority(db),close:async()=>{}};
  if(config.phoneAuth?.provider!=='firebase'||config.staffAuth.sessionSeconds>1800)throw unavailable();
  const policy:StaffPolicy={issuer:`https://securetoken.google.com/${config.phoneAuth.projectId}`,audience:config.phoneAuth.projectId,tenant:'',
    origin:config.staffAuth.origin,digestKey:config.staffAuth.digestKey,version:config.staffAuth.policyVersion,requiredMethods:['sms'],requireAppBinding:true,
    sessionSeconds:config.staffAuth.sessionSeconds,maxAuthenticationAgeSeconds:3600,challengeSeconds:120,
    challengeLimitPerHour:1000,clientChallengeLimitPerHour:30,verificationTimeoutMs:6000,maxConcurrentVerifications:8};
  validateStaffPolicy(policy);
  const provider=createFirebaseStaffVerifier(config.phoneAuth.projectId,config.phoneAuth.digestKey);
  return {authority:new StaffAuthority(db,policy,provider.verifier,clock,new StaffAppBinding(auth,config.phoneAuth,clock)),close:provider.close};
}
