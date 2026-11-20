import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { PoolClient } from 'pg';
import { Config } from '../config';
import { Database } from '../db';
import { fields, object, requireThat, string, uuid } from '../errors';
import { VerifiedFirebaseIdentity } from './firebase';
import { normalizeIndianPhone, OtpFailure } from './otp';

type Settings=NonNullable<Config['phoneAuth']>;
type Row=Record<string,any>;
export const PHONE_IDENTITY_PROVIDERS=['phone:msg91','phone:firebase'];

/** Admission limits protect this app's account flow, not direct Firebase SMS billing. */
export class FirebasePhoneAdmissions {
  constructor(private readonly db:Database,private readonly config:Settings,private readonly clock:()=>number=Date.now){
    requireThat(typeof config.digestKey==='string' && Buffer.byteLength(config.digestKey)>=32 && Buffer.byteLength(config.digestKey)<=256
      && Number.isSafeInteger(config.dailyAdmissionLimit) && config.dailyAdmissionLimit!>=1 && config.dailyAdmissionLimit!<=1000,
      503,'IDENTITY_CONFIGURATION','Native phone sign-in is unavailable.');
  }
  private digest(label:string,value:string){return createHmac('sha256',this.config.digestKey).update(`${this.config.projectId}\0${label}\0${value}`).digest('hex');}
  private async namespace(c:PoolClient){
    const check=this.digest('key-check','nightshift-otp-v1');
    await c.query('INSERT INTO otp_identity_namespaces(issuer,digest_key_check) VALUES($1,$2) ON CONFLICT DO NOTHING',[this.config.projectId,check]);
    const stored=(await c.query('SELECT digest_key_check FROM otp_identity_namespaces WHERE issuer=$1',[this.config.projectId])).rows[0].digest_key_check;
    requireThat(timingSafeEqual(Buffer.from(stored),Buffer.from(check)),503,'IDENTITY_CONFIGURATION','Phone sign-in is unavailable.');
  }
  private async budget(c:PoolClient,scope:string,subject:string,limit:number,window:number){
    const now=this.clock(),start=Math.floor(now/window)*window;
    const result=await c.query(`INSERT INTO otp_rate_limits(issuer,scope,subject_digest,window_start,attempts) VALUES($1,$2,$3,$4,1)
      ON CONFLICT(issuer,scope,subject_digest,window_start) DO UPDATE SET attempts=otp_rate_limits.attempts+1
      WHERE otp_rate_limits.attempts<$5 RETURNING attempts`,[this.config.projectId,scope,subject,new Date(start),limit]);
    if(!result.rows.length)throw new OtpFailure(429,'OTP_RATE_LIMITED','Too many attempts. Try again later.',Math.max(1,Math.ceil((start+window-now)/1000)));
  }
  private view(row:Row){return {attemptId:row.id as string,expiresAt:new Date(row.expires_at).toISOString(),retryAt:new Date(row.retry_at).toISOString()};}
  async admit(raw:unknown,ip:string,key:unknown){
    const address=string(ip,'request address',100);
    await this.db.tx(async c=>{await this.namespace(c);await this.budget(c,'request_ip',this.digest('ip',address),120,300000);});
    const body=object(raw);fields(body,['phone','deviceId','consentVersion']);
    const phone=normalizeIndianPhone(body.phone),device=string(body.deviceId,'deviceId',128),requestKey=string(key,'Idempotency-Key',128);
    requireThat(body.consentVersion===this.config.consentVersion,400,'OTP_INVALID_CONSENT','Accept the current phone sign-in consent.');
    const mobile=this.digest('phone',phone),deviceDigest=this.digest('device',device),keyDigest=this.digest('request',requestKey);
    const fingerprint=this.digest('fingerprint',JSON.stringify([mobile,deviceDigest,this.config.consentVersion]));
    return this.db.tx(async c=>{
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`otp-request:${this.config.projectId}:${deviceDigest}:${keyDigest}`]);
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`identity:${this.config.projectId}:${mobile}`]);
      const known=(await c.query('SELECT id,user_id FROM auth_identities WHERE provider=ANY($1::text[]) AND issuer=$2 AND subject_digest=$3',[PHONE_IDENTITY_PROVIDERS,this.config.projectId,mobile])).rows[0];
      if(known){
        const owner=(await c.query('SELECT suspended FROM users WHERE id=$1 FOR NO KEY UPDATE',[known.user_id])).rows[0];
        const identity=(await c.query('SELECT state FROM auth_identities WHERE id=$1',[known.id])).rows[0];
        requireThat(owner && !owner.suspended && identity?.state==='verified',403,'ACCOUNT_RESTRICTED','This account is unavailable.');
      }
      const previous=(await c.query('SELECT * FROM firebase_phone_admissions WHERE issuer=$1 AND device_digest=$2 AND request_key_digest=$3',[this.config.projectId,deviceDigest,keyDigest])).rows[0];
      if(previous){
        requireThat(previous.request_fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new request key for changed sign-in details.');
        requireThat(new Date(previous.expires_at).getTime()>this.clock() && previous.state!=='superseded',410,'PHONE_ADMISSION_EXPIRED','Request a new sign-in admission.');
        return this.view(previous);
      }
      const latest=(await c.query('SELECT retry_at FROM firebase_phone_admissions WHERE issuer=$1 AND phone_digest=$2 ORDER BY created_at DESC LIMIT 1',[this.config.projectId,mobile])).rows[0];
      if(latest && new Date(latest.retry_at).getTime()>this.clock())throw new OtpFailure(429,'OTP_COOLDOWN','Wait before requesting a new code.',Math.ceil((new Date(latest.retry_at).getTime()-this.clock())/1000));
      await this.budget(c,'send_phone',mobile,3,3600000);
      await this.budget(c,'send_device',deviceDigest,10,3600000);
      await this.budget(c,'send_ip',this.digest('ip',address),20,3600000);
      await this.budget(c,'send_global',this.digest('global','send'),this.config.dailyAdmissionLimit!,86400000);
      await c.query("UPDATE firebase_phone_admissions SET state=CASE WHEN expires_at<=$3 THEN 'expired' ELSE 'superseded' END WHERE issuer=$1 AND phone_digest=$2 AND state='issued'",[this.config.projectId,mobile,new Date(this.clock())]);
      const {rows}=await c.query(`INSERT INTO firebase_phone_admissions(id,issuer,phone_digest,device_digest,request_key_digest,request_fingerprint,consent_version,created_at,expires_at,retry_at)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,[randomUUID(),this.config.projectId,mobile,deviceDigest,keyDigest,fingerprint,this.config.consentVersion,new Date(this.clock()),new Date(this.clock()+300000),new Date(this.clock()+60000)]);
      return this.view(rows[0]);
    });
  }
  async resolve(identity:VerifiedFirebaseIdentity,enrollment?:{attemptId?:unknown;deviceId:string;token:string}){
    requireThat(identity.signInProvider==='phone' && typeof identity.phoneNumber==='string' && /^\+91[6-9]\d{9}$/.test(identity.phoneNumber),401,'INVALID_ID_TOKEN','Sign in with a verified Indian phone identity.');
    const issuer=this.config.projectId,mobile=this.digest('phone',identity.phoneNumber),uid=this.digest('firebase-uid',identity.uid);
    return this.db.tx(async c=>{
      await this.namespace(c);
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`firebase-uid:${issuer}:${uid}`]);
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`identity:${issuer}:${mobile}`]);
      const bound=(await c.query(`SELECT b.user_id,b.phone_identity_id,i.subject_digest FROM firebase_phone_bindings b
        JOIN auth_identities i ON i.id=b.phone_identity_id WHERE b.issuer=$1 AND b.uid_digest=$2`,[issuer,uid])).rows[0];
      requireThat(!bound || bound.subject_digest===mobile,401,'PHONE_IDENTITY_CONFLICT','This identity cannot be used for this account.');
      if(!enrollment && !bound)throw new OtpFailure(401,'INVALID_ID_TOKEN','Sign in again with a verified identity.');
      requireThat(bound || enrollment?.attemptId!==undefined,401,'PHONE_ADMISSION_REQUIRED','Start phone sign-in before continuing.');
      const candidates=await c.query('SELECT id,user_id FROM auth_identities WHERE provider=ANY($1::text[]) AND issuer=$2 AND subject_digest=$3',[PHONE_IDENTITY_PROVIDERS,issuer,mobile]);
      requireThat(candidates.rows.length<=1,401,'PHONE_IDENTITY_CONFLICT','This identity cannot be used for this account.');
      let owner=candidates.rows[0]?.user_id as string|undefined,phoneIdentity=candidates.rows[0]?.id as string|undefined;
      if(owner){
        const account=(await c.query('SELECT suspended FROM users WHERE id=$1 FOR NO KEY UPDATE',[owner])).rows[0];
        const binding=(await c.query('SELECT state FROM auth_identities WHERE id=$1',[phoneIdentity])).rows[0];
        requireThat(account && !account.suspended && binding?.state==='verified',403,'ACCOUNT_RESTRICTED','This account is unavailable.');
        requireThat(!bound || bound.user_id===owner,401,'PHONE_IDENTITY_CONFLICT','This identity cannot be used for this account.');
      }
      // An existing custom-token Firebase UID may already name a legacy app
      // account. Do not silently link that provider account to another phone.
      if(/^[0-9a-f-]{36}$/i.test(identity.uid)){
        const legacy=await c.query('SELECT user_id,subject_digest FROM auth_identities WHERE user_id::text=$1 AND issuer=$2 AND provider=ANY($3::text[])',[identity.uid,issuer,PHONE_IDENTITY_PROVIDERS]);
        requireThat(legacy.rows.every(row=>row.subject_digest===mobile && row.user_id===owner),401,'PHONE_IDENTITY_CONFLICT','This identity cannot be used for this account.');
      }
      let attempt:Row|undefined,proofHash:string|undefined;
      if(enrollment?.attemptId!==undefined){
        const id=uuid(enrollment.attemptId);
        attempt=(await c.query('SELECT * FROM firebase_phone_admissions WHERE id=$1 AND issuer=$2 FOR UPDATE',[id,issuer])).rows[0];
        requireThat(attempt && attempt.phone_digest===mobile && attempt.device_digest===this.digest('device',enrollment.deviceId),401,'PHONE_ADMISSION_MISMATCH','This sign-in admission does not match.');
        requireThat(new Date(attempt.expires_at).getTime()>this.clock() && ['issued','consumed'].includes(attempt.state),410,'PHONE_ADMISSION_EXPIRED','Request a new sign-in admission.');
        requireThat(attempt.consent_version===this.config.consentVersion,400,'OTP_INVALID_CONSENT','Accept the current phone sign-in consent.');
        // Allow five seconds of clock skew before admission; refresh iat is never a new phone proof.
        requireThat(identity.authTime>=Math.floor(new Date(attempt.created_at).getTime()/1000)-5 && this.clock()-identity.authTime*1000<=300000,403,'FRESH_SIGN_IN_REQUIRED','Verify your phone again before continuing.');
        proofHash=createHash('sha256').update(enrollment.token).digest('hex');
        requireThat(attempt.state!=='consumed' || (attempt.token_hash===proofHash && attempt.user_id===owner && bound),409,'PHONE_ADMISSION_CONSUMED','This sign-in admission was already used.');
      }
      if(!bound){
        requireThat(attempt?.state==='issued',401,'PHONE_ADMISSION_REQUIRED','Start phone sign-in before continuing.');
        if(!owner){
          owner=randomUUID();phoneIdentity=randomUUID();
          await c.query("INSERT INTO users(id,display_name,mode,listener_approved,adult_confirmed,desired_online) VALUES($1,'New customer','customer',false,false,false)",[owner]);
          await c.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:firebase',$3,$4)",[phoneIdentity,owner,issuer,mobile]);
          await c.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1",[phoneIdentity]);
        }
        await c.query('INSERT INTO firebase_phone_bindings(issuer,uid_digest,user_id,phone_identity_id) VALUES($1,$2,$3,$4)',[issuer,uid,owner,phoneIdentity]);
      }
      if(attempt?.state==='issued'){
        await c.query("UPDATE firebase_phone_admissions SET state='consumed',token_hash=$2,user_id=$3,consumed_at=$4 WHERE id=$1",[attempt.id,proofHash,owner,new Date(this.clock())]);
        await c.query("INSERT INTO consents(id,user_id,purpose,notice_version,granted) VALUES($1,$2,'phone-signin',$3,true)",[randomUUID(),owner,this.config.consentVersion]);
      }
      return {userId:owner!,bindingId:phoneIdentity!};
    });
  }
}
