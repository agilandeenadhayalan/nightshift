import {PoolClient} from 'pg';
import {createCipheriv,createDecipheriv,createHash,createHmac,randomBytes,randomUUID} from 'node:crypto';
import {Actor} from './auth';
import {Config} from './config';
import {Database} from './db';
import {Presence} from './presence';
import {ApiError,fields,object,requireThat,uuid} from './errors';
import {PushOutcome,PushPayload,PushSend,PushTransport} from './push-transport';
export interface PushRegistration {id:string;version:number;bindingId:string;targetKind:'fcm_token';state:'prepared'|'active'|'revoked'|'expired';backgroundInvitations:boolean;leaseExpiresAt:string|null;serverTime:string;testOnly:true;}
type Row=Record<string,any>;type Query=Pick<PoolClient,'query'>;
const ms=(value:unknown)=>new Date(value as string).getTime();
const hash=(value:string)=>createHash('sha256').update(value).digest('hex');
export class PushService {
  constructor(readonly db:Database,readonly presence:Presence,readonly config:Config,readonly clock:()=>number=Date.now,readonly transport?:PushTransport){}
  private missing():never{throw new ApiError(503,'PUSH_UNAVAILABLE','Background invitations are unavailable.');}
  enabled(){return !!this.config.push&&!!this.transport;}
  available(){return this.enabled()&&this.transport!.available();}
  private configured(){if(!this.enabled())this.missing();return this.config.push!;}
  private view(r:Row):PushRegistration{return{id:r.id,version:r.version,bindingId:r.binding_id,targetKind:'fcm_token',state:r.state,
    backgroundInvitations:r.state==='active',leaseExpiresAt:r.expires_at?new Date(r.expires_at).toISOString():null,serverTime:new Date(this.clock()).toISOString(),testOnly:true};}
  private body(raw:unknown){const b=object(raw);requireThat(Buffer.byteLength(JSON.stringify(b))<=8192,400,'INVALID_PUSH_REGISTRATION','The registration is too large.');return b;}
  private version(value:unknown,nullable=false){requireThat(nullable&&value===null||Number.isSafeInteger(value)&&Number(value)>=1&&Number(value)<=2147483647,400,'INVALID_PUSH_REGISTRATION','Use the current registration version.');return value===null?null:Number(value);}
  private key(value:unknown){requireThat(typeof value==='string'&&value.length>=1&&value.length<=128&&!/[\x00-\x1f\x7f]/.test(value),400,'INVALID_PUSH_REGISTRATION','Use an idempotency key.');return hash(value);}
  private async live(c:PoolClient,actor:Actor){
    const u=(await c.query('SELECT * FROM users WHERE id=$1 FOR NO KEY UPDATE',[actor.id])).rows[0];
    requireThat(u&&!u.suspended,401,'UNAUTHENTICATED','Sign in again.');requireThat(u.adult_confirmed,403,'ONBOARDING_REQUIRED','Complete adult onboarding.');
    requireThat(actor.identityAuthTime!==undefined&&actor.identityBindingId,403,'PHONE_SESSION_REQUIRED','Use a verified phone session.');
    const source=(await c.query(`SELECT s.expires_at,s.device_record_id FROM auth_sessions s JOIN devices d ON d.id=s.device_record_id AND d.user_id=s.user_id
      JOIN auth_identities i ON i.id=$4 AND i.user_id=s.user_id AND i.state='verified' AND i.issuer=$5
      WHERE s.user_id=$1 AND s.token_hash=$2 AND s.auth_kind='firebase' AND s.revoked_at IS NULL AND s.expires_at>$3
      AND d.active AND d.revoked_at IS NULL AND d.last_token_hash=s.token_hash`,[actor.id,actor.sessionHash,new Date(this.clock()),actor.identityBindingId,this.config.push!.projectId])).rows[0];
    requireThat(source&&Number(u.identity_last_auth_time)===actor.identityAuthTime&&(u.identity_revoked_before===null||Number(u.identity_revoked_before)<actor.identityAuthTime),401,'UNAUTHENTICATED','Sign in again.');
    return{...u,...source};
  }
  private async row(c:Query,owner:string){
    let r=(await c.query('SELECT * FROM push_registrations WHERE user_id=$1',[owner])).rows[0];
    if(r&&['prepared','active'].includes(r.state)&&ms(r.expires_at)<=this.clock())r=(await c.query("UPDATE push_registrations SET state='expired',ciphertext=NULL,updated_at=$2 WHERE user_id=$1 RETURNING *",[owner,new Date(this.clock())])).rows[0];
    return r as Row|undefined;
  }
  private async cached(c:Query,actor:Actor,operation:string,key:string,fingerprint:string,r:Row|undefined){
    const old=(await c.query('SELECT fingerprint,registration_version FROM push_commands WHERE user_id=$1 AND operation=$2 AND key_hash=$3',[actor.id,operation,key])).rows[0];
    if(!old)return;
    requireThat(old.fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different operation.');
    requireThat(r&&r.version===old.registration_version,409,'PUSH_REGISTRATION_CHANGED','Refresh the current notification binding.');return this.view(r);
  }
  private async record(c:Query,actor:Actor,operation:string,key:string,fingerprint:string,version:number){
    await c.query('DELETE FROM push_commands WHERE user_id=$1 AND created_at<$2',[actor.id,new Date(this.clock()-3600000)]);
    requireThat(Number((await c.query('SELECT count(*) total FROM push_commands WHERE user_id=$1',[actor.id])).rows[0].total)<200,429,'RATE_LIMITED','Wait before updating notification settings.');
    await c.query('INSERT INTO push_commands(user_id,operation,key_hash,fingerprint,registration_version,created_at) VALUES($1,$2,$3,$4,$5,$6)',[actor.id,operation,key,fingerprint,version,new Date(this.clock())]);
  }
  private aad(r:Row){return Buffer.from(JSON.stringify([r.id,r.user_id,r.device_record_id,r.identity_id,String(r.auth_time),r.project_id,r.version,r.binding_id]));}
  private encrypt(token:string,r:Row){const nonce=randomBytes(12),cipher=createCipheriv('aes-256-gcm',Buffer.from(this.config.push!.encryptionKey,'hex'),nonce);cipher.setAAD(this.aad(r));return Buffer.concat([nonce,cipher.update(token,'utf8'),cipher.final(),cipher.getAuthTag()]);}
  private decrypt(r:Row){const value=r.ciphertext as Buffer,decipher=createDecipheriv('aes-256-gcm',Buffer.from(this.config.push!.encryptionKey,'hex'),value.subarray(0,12));decipher.setAAD(this.aad(r));decipher.setAuthTag(value.subarray(-16));return Buffer.concat([decipher.update(value.subarray(12,-16)),decipher.final()]).toString('utf8');}
  async prepare(actor:Actor,raw:unknown,rawKey:unknown):Promise<PushRegistration>{
    const config=this.configured(),b=this.body(raw);fields(b,['targetKind','token','expectedVersion']);const expected=this.version(b.expectedVersion,true),key=this.key(rawKey);
    requireThat(b.targetKind==='fcm_token'&&typeof b.token==='string'&&/^[!-~]{1,4096}$/.test(b.token),400,'INVALID_PUSH_REGISTRATION','Use a valid opaque notification target.');
    const fingerprint=hash(JSON.stringify({targetKind:b.targetKind,token:b.token,expectedVersion:expected})),digest=createHmac('sha256',config.digestKey).update(`${config.projectId}:fcm_token:${b.token}`).digest('hex');
    return this.db.tx(async c=>{
      let source=await this.live(c,actor);const old=await this.row(c,actor.id),cached=await this.cached(c,actor,'prepare',key,fingerprint,old);if(cached)return cached;
      requireThat((old?.version??null)===expected,409,'PUSH_REGISTRATION_CHANGED','Refresh the current notification binding.');
      requireThat(await this.presence.rateLimit(`push:${actor.id}`,20,60),429,'RATE_LIMITED','Wait before updating notification settings.');source=await this.live(c,actor);
      await c.query('INSERT INTO push_target_claims(target_digest,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[digest,actor.id]);
      const claim=(await c.query('SELECT user_id FROM push_target_claims WHERE target_digest=$1',[digest])).rows[0];
      requireThat(claim?.user_id===actor.id,409,'PUSH_TARGET_CONFLICT','This notification target cannot be assigned.');
      const r:Row={id:old?.id??randomUUID(),user_id:actor.id,device_record_id:source.device_record_id,identity_id:actor.identityBindingId,
        auth_time:actor.identityAuthTime,project_id:config.projectId,version:(old?.version??0)+1,binding_id:randomUUID()};
      const now=new Date(this.clock()),expiry=new Date(Math.min(this.clock()+300000,ms(source.expires_at)));
      const result=(await c.query(`INSERT INTO push_registrations(id,user_id,device_record_id,identity_id,auth_time,project_id,version,binding_id,state,target_digest,ciphertext,expires_at,created_at,updated_at)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,'prepared',$9,$10,$11,$12,$12) ON CONFLICT(user_id) DO UPDATE SET device_record_id=EXCLUDED.device_record_id,identity_id=EXCLUDED.identity_id,
        auth_time=EXCLUDED.auth_time,project_id=EXCLUDED.project_id,version=EXCLUDED.version,binding_id=EXCLUDED.binding_id,state='prepared',target_digest=EXCLUDED.target_digest,ciphertext=EXCLUDED.ciphertext,expires_at=EXCLUDED.expires_at,updated_at=EXCLUDED.updated_at RETURNING *`,
        [r.id,r.user_id,r.device_record_id,r.identity_id,r.auth_time,r.project_id,r.version,r.binding_id,digest,this.encrypt(b.token as string,r),expiry,now])).rows[0];
      await this.record(c,actor,'prepare',key,fingerprint,r.version);return this.view(result);
    });
  }
  async activate(actor:Actor,raw:unknown,rawKey:unknown):Promise<PushRegistration>{
    this.configured();const b=this.body(raw);fields(b,['registrationId','expectedVersion','bindingId','notificationPermission','backgroundInvitations','capabilityVersion','consentVersion']);
    const id=uuid(b.registrationId),binding=uuid(b.bindingId),version=this.version(b.expectedVersion),key=this.key(rawKey),fingerprint=hash(JSON.stringify(b));
    requireThat(b.notificationPermission==='granted'&&b.backgroundInvitations===true&&b.capabilityVersion==='android-audio-invitations-v1'&&b.consentVersion==='background-invitations-v1',400,'INVALID_PUSH_REGISTRATION','Enable the current invitation capability and consent.');
    return this.db.tx(async c=>{
      const source=await this.live(c,actor),r=await this.row(c,actor.id),cached=await this.cached(c,actor,'activate',key,fingerprint,r);if(cached)return cached;
      requireThat(r?.id===id&&r.version===version&&r.binding_id===binding,409,'PUSH_REGISTRATION_CHANGED','Refresh the current notification binding.');
      requireThat(['prepared','active'].includes(r.state)&&r.device_record_id===source.device_record_id&&Number(r.auth_time)===actor.identityAuthTime
        &&r.identity_id===actor.identityBindingId&&r.project_id===this.config.push!.projectId,409,'PUSH_REGISTRATION_CHANGED','Prepare a current notification binding.');
      requireThat(source.listener_approved&&source.mode==='listener'&&source.desired_online,403,'LISTENER_NOT_APPROVED','Use approved available Listener mode.');if(!this.available())this.missing();
      const result=(await c.query("UPDATE push_registrations SET state='active',expires_at=$2,updated_at=$3 WHERE id=$1 RETURNING *",[r.id,new Date(Math.min(this.clock()+1800000,ms(source.expires_at))),new Date(this.clock())])).rows[0];
      if(r.state!=='active')await c.query("INSERT INTO consents(id,user_id,purpose,notice_version,granted,created_at) VALUES($1,$2,'background-invitations','background-invitations-v1',true,$3)",[randomUUID(),actor.id,new Date(this.clock())]);
      await this.record(c,actor,'activate',key,fingerprint,r.version);
      // Registration rotation may have displaced an unexpired invitation.
      const calls=(await c.query("SELECT * FROM call_sessions WHERE listener_id=$1 AND media_type='audio' AND expires_at>$2 ORDER BY created_at DESC LIMIT 3",[actor.id,new Date(this.clock())])).rows;
      for(const call of calls){const event=(await c.query('SELECT id FROM call_events WHERE call_id=$1 AND version=$2',[call.id,call.version])).rows[0];if(event)await this.enqueue(c,event.id,call);}
      return this.view(result);
    });
  }
  async get(actor:Actor):Promise<{registration:PushRegistration|null}>{this.configured();return this.db.tx(async c=>{await this.live(c,actor);const r=await this.row(c,actor.id);return{registration:r?this.view(r):null};});}
  async revoke(actor:Actor,raw:unknown,rawKey:unknown):Promise<PushRegistration>{
    this.configured();const b=this.body(raw);fields(b,['registrationId','expectedVersion']);const id=uuid(b.registrationId),version=this.version(b.expectedVersion),key=this.key(rawKey),fingerprint=hash(JSON.stringify(b));
    return this.db.tx(async c=>{await this.live(c,actor);const r=await this.row(c,actor.id),cached=await this.cached(c,actor,'revoke',key,fingerprint,r);if(cached)return cached;
      requireThat(r?.id===id&&r.version===version,409,'PUSH_REGISTRATION_CHANGED','Refresh the current notification binding.');
      const result=(await c.query("UPDATE push_registrations SET state='revoked',ciphertext=NULL,expires_at=NULL,updated_at=$2 WHERE id=$1 RETURNING *",[id,new Date(this.clock())])).rows[0];
      if(r.state==='active')await c.query("INSERT INTO consents(id,user_id,purpose,notice_version,granted,created_at) VALUES($1,$2,'background-invitations','background-invitations-v1',false,$3)",[randomUUID(),actor.id,new Date(this.clock())]);
      await this.record(c,actor,'revoke',key,fingerprint,r.version);return this.view(result);});
  }
  /** Registration is an eligibility lease, never an online presence proof. */
  async reachable(c:Query,ids:string[]):Promise<Map<string,'foreground'|'background_eligible'>>{
    if(!ids.length)return new Map();
    const background=this.enabled();
    const read=()=>c.query(`SELECT u.id,u.presence_version,${background?`EXISTS(SELECT 1 FROM push_registrations p JOIN auth_identities i ON i.id=p.identity_id AND i.user_id=p.user_id AND i.state='verified' AND i.issuer=p.project_id
      JOIN devices d ON d.id=p.device_record_id AND d.user_id=p.user_id AND d.active AND d.revoked_at IS NULL
      JOIN auth_sessions s ON s.user_id=p.user_id AND s.device_record_id=d.id AND s.auth_kind='firebase' AND s.token_hash=d.last_token_hash AND s.revoked_at IS NULL AND s.expires_at>$2
      WHERE p.user_id=u.id AND p.project_id=$3 AND p.state='active' AND p.expires_at>$2 AND p.auth_time=u.identity_last_auth_time
        AND (u.identity_revoked_before IS NULL OR p.auth_time>u.identity_revoked_before))`:'false'} background
      FROM users u WHERE u.id=ANY($1::uuid[]) AND u.desired_online AND u.listener_approved AND u.adult_confirmed AND NOT u.suspended AND u.mode='listener'
      AND EXISTS(SELECT 1 FROM auth_sessions s LEFT JOIN devices d ON d.id=s.device_record_id WHERE s.user_id=u.id AND s.revoked_at IS NULL AND s.expires_at>$2
        AND (s.auth_kind='development' OR(d.active AND d.revoked_at IS NULL AND d.last_token_hash=s.token_hash)))`,background?[ids,new Date(this.clock()),this.config.push!.projectId]:[ids,new Date(this.clock())]);
    const first=(await read()).rows,versions=new Map(first.map(r=>[r.id,String(r.presence_version)]));const online=new Set(await this.presence.online(first.map(r=>r.id),versions));
    const result=new Map<string,'foreground'|'background_eligible'>();for(const r of(await read()).rows){if(online.has(r.id)&&versions.get(r.id)===String(r.presence_version))result.set(r.id,'foreground');else if(this.available()&&r.background)result.set(r.id,'background_eligible');}return result;
  }
  async enqueue(c:Query,eventId:string,call:Row):Promise<void>{
    if(!this.enabled()||call.media_type!=='audio'||ms(call.expires_at)<=this.clock())return;
    // Also invoked by call recovery. No additional row/user locks here.
    await c.query(`INSERT INTO push_delivery_jobs(id,event_id,call_id,recipient_id,registration_id,registration_version,binding_id,kind,event_version,expires_at,next_attempt_at,created_at)
      SELECT $1,$2,$3,p.user_id,p.id,p.version,p.binding_id,$4,$5,$6,$7,$7 FROM push_registrations p
      WHERE p.user_id=$8 AND p.state='active' AND p.expires_at>$7 ON CONFLICT(event_id,registration_id,registration_version) DO NOTHING`,
      [randomUUID(),eventId,call.id,call.state==='ringing'?'call.invitation':'call.terminal',call.version,call.expires_at,new Date(this.clock()),call.listener_id]);
  }
  private async currentSource(c:Query,r:Row){
    if(r.project_id!==this.config.push!.projectId)return undefined;
    return(await c.query(`SELECT s.expires_at FROM users u JOIN devices d ON d.id=$2 AND d.user_id=u.id AND d.active AND d.revoked_at IS NULL
      JOIN auth_identities i ON i.id=$3 AND i.user_id=u.id AND i.state='verified' AND i.issuer=$5
      JOIN auth_sessions s ON s.user_id=u.id AND s.device_record_id=d.id AND s.auth_kind='firebase' AND s.token_hash=d.last_token_hash AND s.revoked_at IS NULL AND s.expires_at>$6
      WHERE u.id=$1 AND u.adult_confirmed AND NOT u.suspended AND u.listener_approved AND u.mode='listener' AND u.desired_online
      AND u.identity_last_auth_time=$4 AND (u.identity_revoked_before IS NULL OR u.identity_revoked_before<$4)`,
      [r.user_id,r.device_record_id,r.identity_id,r.auth_time,r.project_id,new Date(this.clock())])).rows[0] as Row|undefined;
  }
  /** Final reservation check; caller holds the participant user locks. */
  async backgroundEligible(c:Query,owner:string):Promise<boolean>{
    if(!this.available())return false;
    const r=(await c.query('SELECT * FROM push_registrations WHERE user_id=$1',[owner])).rows[0];
    if(!r||r.state!=='active'||!r.ciphertext)return false;
    const source=await this.currentSource(c,r);
    return !!source&&this.available()&&ms(r.expires_at)>this.clock()&&ms(source.expires_at)>this.clock();
  }
  private async disposeJob(c:Query,id:string,state:string,code:string,next?:number){
    await c.query('UPDATE push_delivery_jobs SET state=$2,result_code=$3,lease_owner=NULL,lease_until=NULL,next_attempt_at=coalesce($4::timestamptz,next_attempt_at) WHERE id=$1',[id,state,code,next===undefined?null:new Date(next)]);
  }
  private async preflight(job:Row):Promise<{message:PushSend;attemptId:string;targetDigest:string}|undefined>{
    const initial=(await this.db.pool.query('SELECT customer_id,listener_id FROM call_sessions WHERE id=$1',[job.call_id])).rows[0];if(!initial)return;
    return this.db.tx(async c=>{
      await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[[initial.customer_id,initial.listener_id]]);
      const call=(await c.query('SELECT * FROM call_sessions WHERE id=$1 FOR UPDATE',[job.call_id])).rows[0];
      const r=(await c.query('SELECT * FROM push_registrations WHERE user_id=$1',[job.recipient_id])).rows[0];
      const current=(await c.query('SELECT * FROM push_delivery_jobs WHERE id=$1 FOR UPDATE',[job.id])).rows[0];
      if(!current||current.state!=='leased'||current.lease_owner!==job.lease_owner||ms(current.lease_until)<=this.clock())return;
      const validType=job.kind==='call.invitation'?call.state==='ringing':call.state!=='ringing'&&job.event_version>1;
      const event=(await c.query('SELECT 1 FROM call_events WHERE id=$1 AND call_id=$2 AND version=$3',[job.event_id,job.call_id,job.event_version])).rowCount;
      const valid=event&&call.media_type==='audio'&&call.listener_id===job.recipient_id&&call.version===job.event_version&&validType
        &&ms(call.expires_at)===ms(job.expires_at)&&ms(job.expires_at)-this.clock()>=1000&&r?.id===job.registration_id&&r.version===job.registration_version
        &&r.binding_id===job.binding_id&&r.state==='active'&&r.ciphertext&&ms(r.expires_at)>this.clock()&&await this.currentSource(c,r);
      if(!valid){await this.disposeJob(c,job.id,'suppressed','SUPERSEDED_OR_EXPIRED');return;}
      if(!this.available()){await this.disposeJob(c,job.id,'retry','UNAVAILABLE',this.clock()+10000);return;}
      await c.query('INSERT INTO push_send_budgets(call_id,kind) VALUES($1,$2) ON CONFLICT DO NOTHING',[job.call_id,job.kind]);
      const budget=(await c.query('SELECT * FROM push_send_budgets WHERE call_id=$1 AND kind=$2 FOR UPDATE',[job.call_id,job.kind])).rows[0];
      if(budget.admitted>=2){await this.disposeJob(c,job.id,'suppressed','ATTEMPTS_EXHAUSTED');return;}
      if(budget.not_before&&ms(budget.not_before)>this.clock()){await this.disposeJob(c,job.id,'retry','BACKOFF',ms(budget.not_before));return;}
      const token=this.decrypt(r),ordinal=Number(budget.admitted)+1,attemptId=randomUUID(),admittedAt=this.clock(),leaseUntil=admittedAt+15000;
      await c.query('SAVEPOINT push_admission');
      await c.query('UPDATE push_send_budgets SET admitted=$3,not_before=$4 WHERE call_id=$1 AND kind=$2',[job.call_id,job.kind,ordinal,new Date(admittedAt+10000)]);
      await c.query('UPDATE push_delivery_jobs SET attempts=attempts+1,last_attempt_at=$2,lease_until=$3 WHERE id=$1 AND state=\'leased\' AND lease_owner=$4',[job.id,new Date(admittedAt),new Date(leaseUntil),job.lease_owner]);
      await c.query('INSERT INTO push_delivery_attempts(id,job_id,call_id,kind,ordinal,registration_version,started_at) VALUES($1,$2,$3,$4,$5,$6,$7)',[attemptId,job.id,job.call_id,job.kind,ordinal,job.registration_version,new Date(this.clock())]);
      // Query/lock waits can consume a lease. Recheck after every admission write;
      // roll back the send admission rather than spending a provider attempt.
      const source=await this.currentSource(c,r);
      if(!source||ms(source.expires_at)<=this.clock()||ms(r.expires_at)<=this.clock()||ms(job.expires_at)-this.clock()<1000||!this.available()){
        await c.query('ROLLBACK TO SAVEPOINT push_admission');await this.disposeJob(c,job.id,'suppressed','SUPERSEDED_OR_EXPIRED');return;
      }
      if(leaseUntil-this.clock()<10000){await c.query('ROLLBACK TO SAVEPOINT push_admission');await this.disposeJob(c,job.id,'retry','LEASE_DELAY',this.clock()+1000);return;}
      const data:PushPayload={schemaVersion:'1',type:job.kind,callId:job.call_id,eventId:job.event_id,callVersion:String(job.event_version),expiresAt:new Date(job.expires_at).toISOString(),registrationId:r.id,registrationVersion:String(r.version),bindingId:r.binding_id};
      return{message:{token,data,deadlineAt:ms(job.expires_at)},attemptId,targetDigest:r.target_digest};
    });
  }
  /** OAuth may have waited after admission. Recheck exact local authority,
   * then release every DB lock before the fixed-origin provider request. */
  private async beforeDispatch(job:Row,attemptId:string,targetDigest:string):Promise<boolean>{
    const initial=(await this.db.pool.query('SELECT customer_id,listener_id FROM call_sessions WHERE id=$1',[job.call_id])).rows[0];if(!initial)return false;
    return this.db.tx(async c=>{
      await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[[initial.customer_id,initial.listener_id]]);
      const call=(await c.query('SELECT * FROM call_sessions WHERE id=$1 FOR UPDATE',[job.call_id])).rows[0];
      const r=(await c.query('SELECT * FROM push_registrations WHERE user_id=$1',[job.recipient_id])).rows[0];
      const current=(await c.query('SELECT * FROM push_delivery_jobs WHERE id=$1 FOR UPDATE',[job.id])).rows[0];
      const attempt=(await c.query('SELECT 1 FROM push_delivery_attempts WHERE id=$1 AND job_id=$2 AND call_id=$3 AND registration_version=$4 AND finished_at IS NULL',[attemptId,job.id,job.call_id,job.registration_version])).rowCount;
      const event=(await c.query('SELECT 1 FROM call_events WHERE id=$1 AND call_id=$2 AND version=$3',[job.event_id,job.call_id,job.event_version])).rowCount;
      if(!attempt||!event||!current||current.state!=='leased'||current.lease_owner!==job.lease_owner||!call||call.media_type!=='audio'
        ||call.listener_id!==job.recipient_id||call.version!==job.event_version||ms(call.expires_at)!==ms(job.expires_at)
        ||(job.kind==='call.invitation'?call.state!=='ringing':call.state==='ringing'||job.event_version<=1)
        ||!r||r.id!==job.registration_id||r.version!==job.registration_version||r.binding_id!==job.binding_id||r.target_digest!==targetDigest||r.state!=='active'||!r.ciphertext)return false;
      const source=await this.currentSource(c,r);
      return !!source&&this.available()&&ms(source.expires_at)>this.clock()&&ms(r.expires_at)>this.clock()
        &&ms(current.lease_until)>this.clock()&&ms(job.expires_at)-this.clock()>=1000;
    });
  }
  private async complete(job:Row,attemptId:string,targetDigest:string,outcome:PushOutcome){
    await this.db.tx(async c=>{
      await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[job.recipient_id]);
      const current=(await c.query('SELECT * FROM push_delivery_jobs WHERE id=$1 FOR UPDATE',[job.id])).rows[0];
      const code=/^[A-Z_]{1,64}$/.test(outcome.code)?outcome.code:'UNKNOWN';
      await c.query('UPDATE push_delivery_attempts SET finished_at=$2,outcome=$3 WHERE id=$1 AND finished_at IS NULL',[attemptId,new Date(this.clock()),code]);
      if(!current||current.state!=='leased'||current.lease_owner!==job.lease_owner)return;
      if(outcome.kind==='unregistered')await c.query("UPDATE push_registrations SET state='revoked',ciphertext=NULL,expires_at=NULL,updated_at=$4 WHERE id=$1 AND version=$2 AND target_digest=$3 AND state IN ('prepared','active')",[job.registration_id,job.registration_version,targetDigest,new Date(this.clock())]);
      if(outcome.kind==='accepted'){
        await this.disposeJob(c,job.id,'accepted','ACCEPTED');
        await c.query('UPDATE push_delivery_jobs SET provider_message_id=$2 WHERE id=$1',[job.id,typeof outcome.messageId==='string'?outcome.messageId.slice(0,400):null]);return;
      }
      if(['SUPERSEDED','EXPIRED'].includes(code)){await this.disposeJob(c,job.id,'suppressed',code);return;}
      if(outcome.kind==='unknown'||outcome.kind==='retry'||['BUSY','UNAVAILABLE','CREDENTIAL_UNAVAILABLE'].includes(code)){
        const delay=Number.isFinite(outcome.retryAfterMs)?Math.min(86400000,Math.max(10000,outcome.retryAfterMs!)):10000,next=this.clock()+delay;
        await c.query('UPDATE push_send_budgets SET not_before=GREATEST(coalesce(not_before,$3),$3) WHERE call_id=$1 AND kind=$2',[job.call_id,job.kind,new Date(next)]);
        if(next+1000>ms(job.expires_at)){await this.disposeJob(c,job.id,'suppressed','EXPIRED');return;}
        await this.disposeJob(c,job.id,outcome.kind==='unknown'?'unknown':'retry',code,next);return;
      }
      await this.disposeJob(c,job.id,'failed',code);
    });
  }
  async processPending(limit=20):Promise<{processed:number}>{
    requireThat(Number.isSafeInteger(limit)&&limit>=1&&limit<=100,400,'INVALID_PUSH_REGISTRATION','Use a bounded delivery limit.');
    const expired=(await this.db.pool.query("SELECT user_id FROM push_registrations WHERE state IN ('prepared','active') AND expires_at<=$1 ORDER BY expires_at LIMIT 100",[new Date(this.clock())])).rows;
    for(const r of expired)await this.db.tx(async c=>{await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[r.user_id]);await this.row(c,r.user_id);});
    // Erasure needs neither provider credentials nor permission to send.
    if(!this.enabled())return{processed:0};
    const jobs=await this.db.tx(async c=>{
      const rows=(await c.query(`SELECT * FROM push_delivery_jobs WHERE (state IN ('pending','retry','unknown') AND next_attempt_at<=$1)
        OR(state='leased' AND lease_until<=$1) ORDER BY next_attempt_at,created_at LIMIT $2 FOR UPDATE SKIP LOCKED`,[new Date(this.clock()),limit])).rows;
      for(const job of rows){job.lease_owner=randomUUID();await c.query("UPDATE push_delivery_jobs SET state='leased',lease_owner=$2,lease_until=$3 WHERE id=$1",[job.id,job.lease_owner,new Date(this.clock()+15000)]);}return rows;
    });
    let next=0,processed=0;
    await Promise.all(Array.from({length:Math.min(4,jobs.length)},async()=>{
      while(next<jobs.length){const job=jobs[next++]!;
        try{const prepared=await this.preflight(job);if(prepared){
          let outcome:PushOutcome;try{outcome=await this.transport!.send(prepared.message,()=>this.beforeDispatch(job,prepared.attemptId,prepared.targetDigest));}catch{outcome={kind:'unknown',code:'UNKNOWN',retryAfterMs:10000};}
          await this.complete(job,prepared.attemptId,prepared.targetDigest,outcome);
        }processed++;}
        catch{await this.db.tx(async c=>{const r=(await c.query('SELECT id FROM push_delivery_jobs WHERE id=$1 AND state=\'leased\' AND lease_owner=$2 FOR UPDATE',[job.id,job.lease_owner])).rows[0];if(r)await this.disposeJob(c,job.id,'retry','TRANSIENT_FAILURE',this.clock()+10000);}).catch(()=>{});}
      }
    }));return{processed};
  }
}
