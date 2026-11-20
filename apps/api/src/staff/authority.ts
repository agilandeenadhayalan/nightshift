import { createHash, createHmac, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import { PoolClient } from 'pg';
import { Database } from '../db';
import { fields, object, requireThat } from '../errors';
import { BoundedStaffVerifier, CurrentStaffIdentity, StaffIdentityReference, StaffIdentityVerifier, StaffPolicy,
  VerifiedStaffSignIn, unauthenticated, unavailable, validateStaffPolicy } from './verifier';
import { StaffAppBinding,StaffAppLineage,StaffNativeIdentity } from './app-binding';

export const STAFF_PERMISSIONS=['listener.review.read','listener.review.evidence.read','listener.review.decide','staff.access.manage'] as const;
export type StaffPermission=typeof STAFF_PERMISSIONS[number];
export interface StaffActor {staffId:string;sessionId:string;sessionHash:string;}
export interface StaffSessionView {staff:{id:string};permissions:StaffPermission[];expiresAt:string;csrfToken:string;}
type Row=Record<string,any>;
const hash=(value:string)=>createHash('sha256').update(value).digest('hex');
const secret=()=>randomBytes(32).toString('hex');
const validSecret=(value:unknown):value is string=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const equal=(a:string,b:string)=>timingSafeEqual(Buffer.from(hash(a)),Buffer.from(hash(b)));

/** Default-off authority; the real factory requires explicit Firebase/native
 * app binding configuration. Signed fixtures exist only in isolated tests. */
export class StaffAuthority {
  private readonly verifier?:BoundedStaffVerifier;
  constructor(private readonly db:Database,private readonly policy?:StaffPolicy,verifier?:StaffIdentityVerifier,
    private readonly clock:()=>number=Date.now,private readonly appBinding?:StaffAppBinding){
    if(!!policy!==!!verifier)throw unavailable();
    if(policy&&verifier){validateStaffPolicy(policy);this.verifier=new BoundedStaffVerifier(verifier,policy);}
    if(policy?.requireAppBinding&&!appBinding)throw unavailable();
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
      &&typeof identity.subject==='string'&&identity.subject.length>0&&identity.subject.length<=128&&!/[\x00-\x1f\x7f]/.test(identity.subject)
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
  private fresh(identity:VerifiedStaffSignIn){
    requireThat(Math.floor(this.clock()/1000)-identity.authTime<=this.ready().maxAuthenticationAgeSeconds,
      403,'STAFF_FRESH_SIGN_IN_REQUIRED','Verify your phone again before opening staff access.');
  }
  async challenge(origin:unknown,client:string,bearer?:unknown){
    this.origin(origin);const p=this.ready(),now=this.clock(),cookie=secret(),csrfToken=secret();
    const native=this.appBinding?await this.appBinding.resolve(bearer):undefined;
    if(native)this.fresh(native.identity);
    await this.db.tx(async c=>{
      // Account deletion clears this owner's challenge bindings while holding
      // the user row. Take that same lock before touching any challenge rows.
      const lineage=native?await this.appBinding!.assert(c,native.lineage,[],native.sessionHash):null;
      await c.query("SELECT pg_advisory_xact_lock(hashtextextended('staff-challenges',0))");
      await c.query('DELETE FROM staff_auth_challenges WHERE cookie_hash IN (SELECT cookie_hash FROM staff_auth_challenges WHERE created_at<$1 ORDER BY created_at LIMIT 100)',[new Date(now-3600000)]);
      const clientDigest=this.digest(`staff-client:${client}`);
      const count=(await c.query('SELECT count(*) total,count(*) FILTER(WHERE client_digest=$2) client FROM staff_auth_challenges WHERE created_at>$1',[new Date(now-3600000),clientDigest])).rows[0];
      requireThat(Number(count.total)<p.challengeLimitPerHour&&Number(count.client)<p.clientChallengeLimitPerHour,429,'STAFF_RATE_LIMITED','Wait before signing in again.');
      await c.query('INSERT INTO staff_auth_challenges(cookie_hash,csrf_hash,client_digest,origin,created_at,expires_at,app_binding) VALUES($1,$2,$3,$4,$5,$6,$7)',
        [hash(cookie),hash(csrfToken),clientDigest,p.origin,new Date(now),new Date(now+p.challengeSeconds*1000),lineage]);
    });
    return {cookie,csrfToken,expiresAt:new Date(now+p.challengeSeconds*1000).toISOString(),maxAgeSeconds:p.challengeSeconds};
  }
  async exchange(raw:unknown,origin:unknown,challengeCookie:unknown,csrf:unknown,bearer?:unknown){
    this.origin(origin);const p=this.ready(),body=object(raw);fields(body,['proof']);
    requireThat(typeof body.proof==='string'&&body.proof.length>0&&body.proof.length<=16384&&body.proof.trim()===body.proof,
      400,'INVALID_FIELD','Invalid staff proof.');
    requireThat(validSecret(challengeCookie)&&validSecret(csrf),403,'STAFF_CSRF_INVALID','Refresh staff access and try again.');
    // Consume before external work. Wrong proof, timeout and retries cannot
    // reuse the challenge to perform unbounded provider verification.
    const consumed=await this.db.pool.query(`UPDATE staff_auth_challenges SET consumed_at=$4 WHERE cookie_hash=$1 AND csrf_hash=$2
      AND origin=$3 AND consumed_at IS NULL AND expires_at>$4 RETURNING app_binding`,[hash(challengeCookie),hash(csrf),p.origin,new Date(this.clock())]);
    requireThat(consumed.rows.length,403,'STAFF_CSRF_INVALID','Refresh staff access and try again.');
    if(this.appBinding)requireThat(body.proof===bearer,401,'STAFF_UNAUTHENTICATED','Use the current app sign-in.');
    const native=this.appBinding?await this.appBinding.resolve(bearer):undefined;
    const identity=native?.identity??await this.verifier!.run(v=>v.verifySignIn(body.proof as string));
    if(native)this.fresh(identity);
    this.methods(identity);
    const current=await this.verifier!.run(v=>v.currentIdentity(identity));
    this.current(identity,identity.authTime,current);
    if(native)requireThat(current.phoneDigest===native.lineage.phoneDigest,401,'STAFF_UNAUTHENTICATED','The verified phone identity changed.');
    const cookie=secret(),sessionId=randomUUID(),now=this.clock(),expiresAt=new Date(now+p.sessionSeconds*1000);
    const permissions=await this.db.tx(async c=>{
      const principal=(await c.query('SELECT * FROM staff_principals WHERE subject_digest=$1 FOR NO KEY UPDATE',[this.binding(identity)])).rows[0];
      this.methods(identity);
      if(native)requireThat(principal&&!principal.disabled&&principal.linked_user_id===native.lineage.userId,
        403,'STAFF_ACCESS_NOT_APPROVED','This account has not been approved for staff access.');
      requireThat(principal&&!principal.disabled&&principal.provider_subject===identity.subject&&principal.issuer===identity.issuer
        &&principal.audience===identity.audience&&principal.tenant===identity.tenant&&identity.authTime>Number(principal.revoked_before)
        &&(principal.last_auth_time===null||identity.authTime>=Number(principal.last_auth_time))
        &&(principal.last_issued_at===null||identity.issuedAt>Number(principal.last_issued_at)),401,'STAFF_UNAUTHENTICATED','Sign in to staff access again.');
      const permissions=await this.permissions(c,principal.id);requireThat(permissions.length,403,'STAFF_FORBIDDEN','Staff permission is required.');
      let lineage:StaffAppLineage|null=null;
      if(native){
        lineage=await this.appBinding!.assert(c,native.lineage,[],native.sessionHash);
        requireThat(JSON.stringify(consumed.rows[0].app_binding)===JSON.stringify(lineage)
          ||this.sameLineage(consumed.rows[0].app_binding,lineage),403,'STAFF_CSRF_INVALID','Refresh staff access and try again.');
      }
      await c.query('UPDATE staff_sessions SET revoked_at=GREATEST(created_at,$2) WHERE principal_id=$1 AND revoked_at IS NULL',[principal.id,new Date(now)]);
      await c.query('UPDATE staff_principals SET last_auth_time=$2,last_issued_at=$3 WHERE id=$1',[principal.id,identity.authTime,identity.issuedAt]);
      await c.query(`INSERT INTO staff_sessions(id,principal_id,token_hash,proof_hash,authority_version,authentication_methods,auth_time,policy_version,created_at,expires_at,app_binding)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,[sessionId,principal.id,hash(cookie),hash(body.proof as string),principal.authority_version,identity.authenticationMethods,identity.authTime,p.version,new Date(now),expiresAt,lineage]);
      await this.audit(c,principal.id,sessionId,'session.created','verified_signin');
      return {id:principal.id,permissions};
    });
    return {cookie,maxAgeSeconds:p.sessionSeconds,view:{staff:{id:permissions.id},permissions:permissions.permissions,expiresAt:expiresAt.toISOString(),csrfToken:this.csrf(cookie)} satisfies StaffSessionView};
  }
  private sameLineage(a:StaffAppLineage|undefined,b:StaffAppLineage){
    return !!a&&(['userId','deviceId','identityId','authTime','subject','uidDigest','phoneDigest'] as const).every(k=>a[k]===b[k]);
  }
  private requestView(row:Row){return {requestId:row.id as string,accountReference:row.user_id as string,
    status:row.provisioned_at?'provisioned' as const:'pending' as const,expiresAt:new Date(row.expires_at).toISOString()};}
  async cleanupAccessRequests(limit=100){
    requireThat(Number.isSafeInteger(limit)&&limit>=1&&limit<=100,400,'INVALID_FIELD','Invalid cleanup limit.');
    // Erase transient private identity at challenge expiry; keep hashed
    // client/hour accounting until that complete rate window has elapsed.
    await this.db.pool.query(`UPDATE staff_auth_challenges SET app_binding=NULL WHERE cookie_hash IN
      (SELECT cookie_hash FROM staff_auth_challenges WHERE app_binding IS NOT NULL AND expires_at<=$1
        ORDER BY expires_at,cookie_hash LIMIT $2 FOR UPDATE SKIP LOCKED)`,[new Date(this.clock()),limit]);
    await this.db.pool.query(`DELETE FROM staff_auth_challenges WHERE cookie_hash IN
      (SELECT cookie_hash FROM staff_auth_challenges WHERE created_at<=$1 ORDER BY created_at,cookie_hash LIMIT $2 FOR UPDATE SKIP LOCKED)`,[new Date(this.clock()-3600000),limit]);
    const result=await this.db.pool.query(`DELETE FROM staff_access_requests WHERE id IN
      (SELECT id FROM staff_access_requests WHERE expires_at<=$1 ORDER BY expires_at,id LIMIT $2 FOR UPDATE SKIP LOCKED)`,[new Date(this.clock()),limit]);
    return result.rowCount??0;
  }
  async accessRequest(bearer:unknown,create:boolean){
    this.ready();if(!this.appBinding)throw unavailable();
    const native=await this.appBinding.resolve(bearer);this.fresh(native.identity);this.methods(native.identity);
    return this.db.tx(async c=>{
      const lineage=await this.appBinding!.assert(c,native.lineage,[],native.sessionHash);
      const previous=(await c.query('SELECT * FROM staff_access_requests WHERE user_id=$1 AND expires_at>$2 ORDER BY created_at DESC LIMIT 1',
        [lineage.userId,new Date(this.clock())])).rows[0];
      if(previous&&this.sameLineage(previous.app_binding,lineage))return this.requestView(previous);
      requireThat(create,404,'STAFF_ACCESS_REQUEST_NOT_FOUND','Create a staff access request from this account.');
      // One pending request per account, bounded cleanup; old references cannot
      // later authorize a changed device/authentication lineage.
      await c.query('DELETE FROM staff_access_requests WHERE user_id=$1 AND provisioned_at IS NULL',[lineage.userId]);
      const row=(await c.query(`INSERT INTO staff_access_requests(id,user_id,issuer,audience,tenant,provider_subject,subject_digest,app_binding,created_at,expires_at)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,[randomUUID(),lineage.userId,native.identity.issuer,native.identity.audience,
        native.identity.tenant,native.identity.subject,this.binding(native.identity),lineage,new Date(this.clock()),new Date(this.clock()+3600000)])).rows[0];
      return this.requestView(row);
    });
  }
  /** Offline, explicit operator command only. There is deliberately no HTTP
   * enrollment/grant endpoint. Dry run performs identical validation, no writes. */
  async provision(requestId:string,expectedUserId:string,permissions:readonly StaffPermission[],apply=false){
    this.ready();if(!this.appBinding)throw unavailable();
    const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
    requireThat(uuid.test(requestId)&&uuid.test(expectedUserId)&&permissions.length>0&&permissions.length<=STAFF_PERMISSIONS.length
      &&new Set(permissions).size===permissions.length&&permissions.every(p=>STAFF_PERMISSIONS.includes(p)),400,'INVALID_FIELD','Specify the exact request, account reference and permissions.');
    const snapshot=(await this.db.pool.query('SELECT * FROM staff_access_requests WHERE id=$1',[requestId])).rows[0];
    requireThat(snapshot&&snapshot.user_id===expectedUserId,404,'STAFF_ACCESS_REQUEST_NOT_FOUND','The account reference does not match this request.');
    const identity={issuer:snapshot.issuer,audience:snapshot.audience,tenant:snapshot.tenant,subject:snapshot.provider_subject};
    requireThat(this.binding(identity)===snapshot.subject_digest&&identity.issuer===this.ready().issuer&&identity.audience===this.ready().audience&&identity.tenant===this.ready().tenant,
      403,'STAFF_ACCESS_NOT_APPROVED','The verified identity does not match this configuration.');
    const current=await this.verifier!.run(v=>v.currentIdentity(identity));
    this.current(identity,snapshot.app_binding.authTime,current);
    requireThat(current.phoneDigest===snapshot.app_binding.phoneDigest,403,'STAFF_ACCESS_NOT_APPROVED','The verified phone binding changed.');
    return this.db.tx(async c=>{
      await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`staff-provision:${snapshot.subject_digest}`]);
      let principal=(await c.query('SELECT * FROM staff_principals WHERE subject_digest=$1 FOR NO KEY UPDATE',[snapshot.subject_digest])).rows[0];
      const lineage=await this.appBinding!.assert(c,snapshot.app_binding);
      const request=(await c.query('SELECT * FROM staff_access_requests WHERE id=$1 AND expires_at>$2 FOR UPDATE',[requestId,new Date(this.clock())])).rows[0];
      requireThat(request&&request.user_id===expectedUserId&&this.sameLineage(request.app_binding,lineage),404,'STAFF_ACCESS_REQUEST_NOT_FOUND','This request is no longer current.');
      requireThat(!principal||!principal.disabled&&this.configuredPrincipal(principal)&&principal.linked_user_id===expectedUserId,
        409,'STAFF_BINDING_CONFLICT','An existing staff binding must be reviewed separately.');
      const existing=principal?await this.permissions(c,principal.id):[];
      const adding=permissions.filter(p=>!existing.includes(p));
      const result={requestId,accountReference:expectedUserId,permissions:[...permissions],adding:[...adding],applied:apply};
      if(!apply)return result;
      if(!principal){
        principal=(await c.query(`INSERT INTO staff_principals(id,issuer,audience,tenant,provider_subject,subject_digest,linked_user_id)
          VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`,[randomUUID(),identity.issuer,identity.audience,identity.tenant,identity.subject,snapshot.subject_digest,expectedUserId])).rows[0];
      }
      for(const permission of adding)await c.query("INSERT INTO staff_permission_grants(id,principal_id,permission,reason_code) VALUES($1,$2,$3,'explicit_owner_request')",[randomUUID(),principal.id,permission]);
      if(!request.provisioned_at){
        await c.query('UPDATE staff_access_requests SET provisioned_at=$2,principal_id=$3 WHERE id=$1',[requestId,new Date(this.clock()),principal.id]);
        await c.query("INSERT INTO staff_audit_events(id,principal_id,action,reason_code) VALUES($1,$2,'access.provisioned','explicit_owner_request')",[randomUUID(),principal.id]);
      }
      return result;
    });
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
    const current=await this.verifier!.run(v=>v.currentIdentity(identity));
    this.current(identity,Number(row.auth_time),current);
    if(this.appBinding&&(!row.app_binding||current.phoneDigest!==row.app_binding.phoneDigest))throw unauthenticated();
    const actor={staffId:row.principal_id,sessionId:row.id,sessionHash:hash(cookie)};
    await this.db.tx(c=>this.authorize(c,actor));return actor;
  }
  /** Always call inside the action transaction, before applicant/application
   * locks. A guard that completed before revocation is not sufficient. */
  async authorize(c:PoolClient,actor:StaffActor,permission?:StaffPermission,additionalUserIds:readonly string[]=[]){
    const p=this.ready();
    const principal=(await c.query('SELECT * FROM staff_principals WHERE id=$1 FOR NO KEY UPDATE',[actor.staffId])).rows[0];
    if(!principal||principal.disabled||!this.configuredPrincipal(principal))throw unauthenticated();
    const session=(await c.query(`SELECT * FROM staff_sessions WHERE id=$1 AND principal_id=$2 AND token_hash=$3
      AND revoked_at IS NULL AND expires_at>$4 AND authority_version=$5 AND auth_time>$6 AND policy_version=$7`,
    [actor.sessionId,actor.staffId,actor.sessionHash,new Date(this.clock()),principal.authority_version,principal.revoked_before,p.version])).rows[0];
    if(!session||new Date(session.created_at).getTime()+p.sessionSeconds*1000<=this.clock()
      ||!p.requiredMethods.every(m=>session.authentication_methods.includes(m)))throw unauthenticated();
    if(this.appBinding){
      if(!session.app_binding||session.app_binding.userId!==principal.linked_user_id||session.app_binding.subject!==principal.provider_subject)throw unauthenticated();
      await this.appBinding.assert(c,session.app_binding,additionalUserIds);
    }
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
