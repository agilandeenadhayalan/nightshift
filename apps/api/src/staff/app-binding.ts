import { createHmac } from 'node:crypto';
import { PoolClient } from 'pg';
import { Auth } from '../auth';
import { Config } from '../config';
import { requireThat } from '../errors';
import { VerifiedStaffSignIn,unauthenticated } from './verifier';

export interface StaffAppLineage {
  userId:string;deviceId:string;identityId:string;authTime:number;subject:string;uidDigest:string;phoneDigest:string;
}
export interface StaffNativeIdentity {lineage:StaffAppLineage;identity:VerifiedStaffSignIn;sessionHash:string;}
/** The implementation verifies through the existing registered app-session
 * boundary, then rechecks durable lineage in the staff action transaction. */
export class StaffAppBinding {
  constructor(private readonly auth:Auth,private readonly config:NonNullable<Config['phoneAuth']>,private readonly clock:()=>number=Date.now){}
  async resolve(token:unknown):Promise<StaffNativeIdentity>{
    requireThat(typeof token==='string'&&token.length>0&&token.length<=16384,401,'UNAUTHENTICATED','Sign in again.');
    const {actor,identity}=await this.auth.authenticatedPhone(token);
    requireThat(this.config.provider==='firebase'&&identity.audience===this.config.projectId
      &&identity.issuer===`https://securetoken.google.com/${this.config.projectId}`&&/^\+91[6-9]\d{9}$/.test(identity.phoneNumber!),
      401,'UNAUTHENTICATED','Use a verified phone sign-in.');
    return {sessionHash:actor.sessionHash,lineage:{userId:actor.id,deviceId:'',identityId:identity.bindingId,
      authTime:identity.authTime,subject:identity.uid,
      phoneDigest:createHmac('sha256',this.config.digestKey).update(`${this.config.projectId}\0phone\0${identity.phoneNumber}`).digest('hex'),
      uidDigest:createHmac('sha256',this.config.digestKey).update(`${this.config.projectId}\0firebase-uid\0${identity.uid}`).digest('hex')},
      identity:{issuer:identity.issuer,audience:identity.audience,tenant:'',subject:identity.uid,authTime:identity.authTime,
        issuedAt:identity.issuedAt,expiresAt:identity.expiresAt,authenticationMethods:['sms']}};
  }
  /** Caller holds staff principal first (if one exists); acquire ALL users in
   * sorted order here before any application rows. No app->staff callbacks. */
  async assert(c:PoolClient,lineage:StaffAppLineage,additionalUsers:readonly string[]=[],sessionHash?:string):Promise<StaffAppLineage>{
    if(!lineage||typeof lineage.userId!=='string'||typeof lineage.subject!=='string'||!Number.isSafeInteger(lineage.authTime))throw unauthenticated();
    const owners=[...new Set([lineage.userId,...additionalUsers])].sort();
    await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[owners]);
    const result=await c.query(`SELECT d.id FROM users u
      JOIN devices d ON d.user_id=u.id AND d.active AND d.revoked_at IS NULL
      JOIN auth_sessions s ON s.user_id=u.id AND s.device_record_id=d.id AND s.token_hash=d.last_token_hash
      JOIN auth_identities i ON i.user_id=u.id AND i.id=$2 AND i.state='verified' AND i.subject_digest=$9
      JOIN firebase_phone_bindings f ON f.user_id=u.id AND f.phone_identity_id=i.id AND f.issuer=$3 AND f.uid_digest=$4
      WHERE u.id=$1 AND NOT u.suspended AND u.adult_confirmed AND u.identity_last_auth_time=$5
        AND (u.identity_revoked_before IS NULL OR u.identity_revoked_before<$5)
        AND s.auth_kind='firebase' AND s.revoked_at IS NULL AND s.expires_at>$6
        AND ($7::text IS NULL OR s.token_hash=$7) AND ($8::uuid IS NULL OR d.id=$8)`,
      [lineage.userId,lineage.identityId,this.config.projectId,lineage.uidDigest,lineage.authTime,new Date(this.clock()),sessionHash??null,lineage.deviceId||null,lineage.phoneDigest]);
    if(result.rows.length!==1)throw unauthenticated();
    return {...lineage,deviceId:result.rows[0].id};
  }
}
