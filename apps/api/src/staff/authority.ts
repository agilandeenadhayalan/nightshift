import { createHash, createHmac, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import { PoolClient } from 'pg';
import { Database } from '../db';
import { fields, object, requireThat } from '../errors';
import { BoundedStaffVerifier, CurrentStaffIdentity, StaffIdentityReference, StaffIdentityVerifier, StaffPolicy,
  VerifiedStaffSignIn, unauthenticated, unavailable, validateStaffPolicy } from './verifier';

export const STAFF_PERMISSIONS=['listener.review.read','listener.review.evidence.read','listener.review.decide'] as const;
export type StaffPermission=typeof STAFF_PERMISSIONS[number];
export interface StaffActor {staffId:string;sessionId:string;sessionHash:string;}
export interface StaffSessionView {staff:{id:string};permissions:StaffPermission[];expiresAt:string;csrfToken:string;}
type Row=Record<string,any>;
const hash=(value:string)=>createHash('sha256').update(value).digest('hex');
const secret=()=>randomBytes(32).toString('hex');
const validSecret=(value:unknown):value is string=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const equal=(a:string,b:string)=>timingSafeEqual(Buffer.from(hash(a)),Buffer.from(hash(b)));

/** No production factory accepts a verifier from an environment variable.
 * The normal API constructs this without configuration, so staff stays off.
 * Tests construct the same service/controller using a signed fixture verifier. */
export class StaffAuthority {
  private readonly verifier?:BoundedStaffVerifier;
  constructor(private readonly db:Database,private readonly policy?:StaffPolicy,verifier?:StaffIdentityVerifier,
    private readonly clock:()=>number=Date.now){
    if(!!policy!==!!verifier)throw unavailable();
    if(policy&&verifier){validateStaffPolicy(policy);this.verifier=new BoundedStaffVerifier(verifier,policy);}
  }
  status(){return this.policy?{configured:true,available:true,reasonCode:null}:{configured:false,available:false,reasonCode:'STAFF_AUTH_UNAVAILABLE' as const};}
  private ready(){if(!this.policy||!this.verifier)throw unavailable();return this.policy;}
  origin(value:unknown,required=true){const p=this.ready();requireThat(!required&&value===undefined||value===p.origin,403,'STAFF_ORIGIN_DENIED','Use the configured staff origin.');}
  private digest(value:string){return createHmac('sha256',this.ready().digestKey).update(value).digest('hex');}
  binding(identity:StaffIdentityReference){return this.digest(JSON.stringify(['staff-identity',identity.issuer,identity.audience,identity.tenant,identity.subject]));}
  private csrf(cookie:string){return this.digest(`staff-csrf:${cookie}`);}
  private checkCsrf(cookie:unknown,csrf:unknown){
    requireThat(validSecret(cookie)&&validSecret(csrf)&&equal(this.csrf(cookie),csrf),403,'STAFF_CSRF_INVALID','Refresh staff access and try again.');
  }
  private methods(identity:VerifiedStaffSignIn){
    const p=this.ready(),now=Math.floor(this.clock()/1000),time=(n:unknown)=>Number.isSafeInteger(n)&&Number(n)>=0;
    requireThat(identity&&identity.issuer===p.issuer&&identity.audience===p.audience&&identity.tenant===p.tenant
      &&typeof identity.subject==='string'&&/^[A-Za-z0-9._:|~-]{1,128}$/.test(identity.subject)
      &&time(identity.authTime)&&time(identity.issuedAt)&&time(identity.expiresAt)
      &&identity.authTime<=identity.issuedAt&&identity.issuedAt<=now&&identity.expiresAt>now&&identity.expiresAt>identity.issuedAt
      &&now-identity.authTime<=p.maxAuthenticationAgeSeconds
      &&Array.isArray(identity.authenticationMethods)&&identity.authenticationMethods.length<=8
      &&identity.authenticationMethods.every(m=>typeof m==='string'&&/^[a-z][a-z0-9_-]{0,39}$/.test(m))
      &&new Set(identity.authenticationMethods).size===identity.authenticationMethods.length
      &&p.requiredMethods.every(m=>identity.authenticationMethods.includes(m)),401,'STAFF_UNAUTHENTICATED','Sign in to staff access again.');
  }
  private current(identity:StaffIdentityReference,authTime:number,now:CurrentStaffIdentity){
    requireThat(now&&now.issuer===identity.issuer&&now.audience===identity.audience&&now.tenant===identity.tenant
      &&now.subject===identity.subject&&now.disabled===false&&Number.isSafeInteger(now.validAfter)&&now.validAfter>=0
      &&authTime>=now.validAfter,401,'STAFF_UNAUTHENTICATED','Sign in to staff access again.');
  }
  private configuredPrincipal(row:Row){
    const p=this.ready();
    return row.issuer===p.issuer&&row.audience===p.audience&&row.tenant===p.tenant
      &&row.subject_digest===this.binding({issuer:row.issuer,audience:row.audience,tenant:row.tenant,subject:row.provider_subject});
  }
  async challenge(origin:unknown,client:string){
    this.origin(origin);const p=this.ready(),now=this.clock(),cookie=secret(),csrfToken=secret();
    await this.db.tx(async c=>{
      await c.query("SELECT pg_advisory_xact_lock(hashtextextended('staff-challenges',0))");
      await c.query('DELETE FROM staff_auth_challenges WHERE cookie_hash IN (SELECT cookie_hash FROM staff_auth_challenges WHERE created_at<$1 ORDER BY created_at LIMIT 100)',[new Date(now-3600000)]);
      const clientDigest=this.digest(`staff-client:${client}`);
      const count=(await c.query('SELECT count(*) total,count(*) FILTER(WHERE client_digest=$2) client FROM staff_auth_challenges WHERE created_at>$1',[new Date(now-3600000),clientDigest])).rows[0];
      requireThat(Number(count.total)<p.challengeLimitPerHour&&Number(count.client)<p.clientChallengeLimitPerHour,429,'STAFF_RATE_LIMITED','Wait before signing in again.');
      await c.query('INSERT INTO staff_auth_challenges(cookie_hash,csrf_hash,client_digest,origin,created_at,expires_at) VALUES($1,$2,$3,$4,$5,$6)',
        [hash(cookie),hash(csrfToken),clientDigest,p.origin,new Date(now),new Date(now+p.challengeSeconds*1000)]);
    });
    return {cookie,csrfToken,expiresAt:new Date(now+p.challengeSeconds*1000).toISOString(),maxAgeSeconds:p.challengeSeconds};
  }
  async exchange(raw:unknown,origin:unknown,challengeCookie:unknown,csrf:unknown){
    this.origin(origin);const p=this.ready(),body=object(raw);fields(body,['proof']);
    requireThat(typeof body.proof==='string'&&body.proof.length>0&&body.proof.length<=16384&&body.proof.trim()===body.proof,
      400,'INVALID_FIELD','Invalid staff proof.');
    requireThat(validSecret(challengeCookie)&&validSecret(csrf),403,'STAFF_CSRF_INVALID','Refresh staff access and try again.');
    // Consume before external work. Wrong proof, timeout and retries cannot
    // reuse the challenge to perform unbounded provider verification.
    const consumed=await this.db.pool.query(`UPDATE staff_auth_challenges SET consumed_at=$4 WHERE cookie_hash=$1 AND csrf_hash=$2
      AND origin=$3 AND consumed_at IS NULL AND expires_at>$4 RETURNING cookie_hash`,[hash(challengeCookie),hash(csrf),p.origin,new Date(this.clock())]);
    requireThat(consumed.rows.length,403,'STAFF_CSRF_INVALID','Refresh staff access and try again.');
    const identity=await this.verifier!.run(v=>v.verifySignIn(body.proof as string));this.methods(identity);
    this.current(identity,identity.authTime,await this.verifier!.run(v=>v.currentIdentity(identity)));
    const cookie=secret(),sessionId=randomUUID(),now=this.clock(),expiresAt=new Date(now+p.sessionSeconds*1000);
    const permissions=await this.db.tx(async c=>{
      const principal=(await c.query('SELECT * FROM staff_principals WHERE subject_digest=$1 FOR NO KEY UPDATE',[this.binding(identity)])).rows[0];
      this.methods(identity);
      requireThat(principal&&!principal.disabled&&principal.provider_subject===identity.subject&&principal.issuer===identity.issuer
        &&principal.audience===identity.audience&&principal.tenant===identity.tenant&&identity.authTime>Number(principal.revoked_before)
        &&(principal.last_auth_time===null||identity.authTime>=Number(principal.last_auth_time))
        &&(principal.last_issued_at===null||identity.issuedAt>Number(principal.last_issued_at)),401,'STAFF_UNAUTHENTICATED','Sign in to staff access again.');
      const permissions=await this.permissions(c,principal.id);requireThat(permissions.length,403,'STAFF_FORBIDDEN','Staff permission is required.');
      await c.query('UPDATE staff_sessions SET revoked_at=GREATEST(created_at,$2) WHERE principal_id=$1 AND revoked_at IS NULL',[principal.id,new Date(now)]);
      await c.query('UPDATE staff_principals SET last_auth_time=$2,last_issued_at=$3 WHERE id=$1',[principal.id,identity.authTime,identity.issuedAt]);
      await c.query(`INSERT INTO staff_sessions(id,principal_id,token_hash,proof_hash,authority_version,authentication_methods,auth_time,policy_version,created_at,expires_at)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,[sessionId,principal.id,hash(cookie),hash(body.proof as string),principal.authority_version,identity.authenticationMethods,identity.authTime,p.version,new Date(now),expiresAt]);
      await this.audit(c,principal.id,sessionId,'session.created','verified_signin');
      return {id:principal.id,permissions};
    });
    return {cookie,maxAgeSeconds:p.sessionSeconds,view:{staff:{id:permissions.id},permissions:permissions.permissions,expiresAt:expiresAt.toISOString(),csrfToken:this.csrf(cookie)} satisfies StaffSessionView};
  }
  private async permissions(c:PoolClient,id:string):Promise<StaffPermission[]>{
    return (await c.query('SELECT permission FROM staff_permission_grants WHERE principal_id=$1 AND revoked_at IS NULL ORDER BY permission',[id])).rows.map(r=>r.permission);
  }
  private async audit(c:PoolClient,staffId:string,sessionId:string,action:string,reason:string,permission?:StaffPermission){
    await c.query('INSERT INTO staff_audit_events(id,principal_id,session_id,action,reason_code,permission,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)',
      [randomUUID(),staffId,sessionId,action,reason,permission??null,new Date(this.clock())]);
  }
  async authenticate(cookie:unknown):Promise<StaffActor>{
    this.ready();if(!validSecret(cookie))throw unauthenticated();
    const row=(await this.db.pool.query(`SELECT s.*,p.issuer,p.audience,p.tenant,p.provider_subject,p.subject_digest FROM staff_sessions s
      JOIN staff_principals p ON p.id=s.principal_id WHERE s.token_hash=$1 AND s.revoked_at IS NULL AND s.expires_at>$2
      AND NOT p.disabled AND s.authority_version=p.authority_version AND s.auth_time>p.revoked_before`,[hash(cookie),new Date(this.clock())])).rows[0];
    if(!row||!this.configuredPrincipal(row))throw unauthenticated();
    const identity={issuer:row.issuer,audience:row.audience,tenant:row.tenant,subject:row.provider_subject};
    this.current(identity,Number(row.auth_time),await this.verifier!.run(v=>v.currentIdentity(identity)));
    const actor={staffId:row.principal_id,sessionId:row.id,sessionHash:hash(cookie)};
    await this.db.tx(c=>this.authorize(c,actor));return actor;
  }
  /** Always call inside the action transaction, before applicant/application
   * locks. A guard that completed before revocation is not sufficient. */
  async authorize(c:PoolClient,actor:StaffActor,permission?:StaffPermission){
    const p=this.ready();
    const principal=(await c.query('SELECT * FROM staff_principals WHERE id=$1 FOR NO KEY UPDATE',[actor.staffId])).rows[0];
    if(!principal||principal.disabled||!this.configuredPrincipal(principal))throw unauthenticated();
    const session=(await c.query(`SELECT * FROM staff_sessions WHERE id=$1 AND principal_id=$2 AND token_hash=$3
      AND revoked_at IS NULL AND expires_at>$4 AND authority_version=$5 AND auth_time>$6 AND policy_version=$7`,
    [actor.sessionId,actor.staffId,actor.sessionHash,new Date(this.clock()),principal.authority_version,principal.revoked_before,p.version])).rows[0];
    if(!session||new Date(session.created_at).getTime()+p.sessionSeconds*1000<=this.clock()
      ||!p.requiredMethods.every(m=>session.authentication_methods.includes(m)))throw unauthenticated();
    const permissions=await this.permissions(c,actor.staffId);
    requireThat(!permission||STAFF_PERMISSIONS.includes(permission)&&permissions.includes(permission),403,'STAFF_FORBIDDEN','Staff permission is required.');
    if(permission)await this.audit(c,actor.staffId,actor.sessionId,'permission.used','permission_checked',permission);
    return {staff:{id:actor.staffId},permissions,expiresAt:new Date(session.expires_at).toISOString()};
  }
  async session(cookie:unknown,origin?:unknown):Promise<StaffSessionView>{
    this.origin(origin,false);const actor=await this.authenticate(cookie);
    return {...await this.db.tx(c=>this.authorize(c,actor)),csrfToken:this.csrf(cookie as string)};
  }
  async logout(cookie:unknown,csrf:unknown,origin:unknown){
    this.origin(origin);this.checkCsrf(cookie,csrf);
    // Local revocation remains possible during an identity-provider outage.
    // It exposes no staff data and still requires the current local session.
    const row=(await this.db.pool.query('SELECT id,principal_id FROM staff_sessions WHERE token_hash=$1',[hash(cookie as string)])).rows[0];
    if(!row)throw unauthenticated();
    const actor={staffId:row.principal_id,sessionId:row.id,sessionHash:hash(cookie as string)};
    await this.db.tx(async c=>{
      await this.authorize(c,actor);
      await c.query('UPDATE staff_principals SET revoked_before=GREATEST(revoked_before,$2),authority_version=authority_version+1 WHERE id=$1',[actor.staffId,Math.floor(this.clock()/1000)]);
      await this.audit(c,actor.staffId,actor.sessionId,'session.revoked','signed_out');
    });return {signedOut:true};
  }
}
