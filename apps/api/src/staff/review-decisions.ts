import {randomUUID,createHash} from 'node:crypto';
import {PoolClient} from 'pg';
import {Actor} from '../auth';
import {Database} from '../db';
import {fields,object,requireThat,uuid} from '../errors';
import {StaffActor,StaffAuthority} from './authority';
import {StaffReviewQueries} from './review-queries';
import {ApprovedReviewPolicy,canonical,EVIDENCE_KINDS,EvidenceKind,ReviewOutcome,REVIEW_OUTCOMES,reviewHash,validateReviewPolicy} from './review-policy';

type Row=Record<string,any>;
type Check={id:string;result:'pass'|'fail'|'not_checked';evidenceKinds:EvidenceKind[]};
type Input={expectedMaterialVersion:string;policyVersion:string;policyDigest:string;outcome:ReviewOutcome;checks:Check[];reasonCode:string};
const hash=(value:string)=>createHash('sha256').update(value).digest('hex');
const iso=(value:unknown)=>new Date(value as string).toISOString();
const hex=(value:unknown)=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const slug=(value:unknown)=>typeof value==='string'&&/^[a-z][a-z0-9_]{0,63}$/.test(value);

/** No normal bootstrap policy exists until a reviewed owner policy is supplied.
 * A fixture is injected explicitly by an isolated test harness, never by env. */
export class StaffReviewDecisions {
  private readonly approved?:ApprovedReviewPolicy;private readonly digest?:string;
  constructor(private readonly db:Database,private readonly authority:StaffAuthority,private readonly reviews:StaffReviewQueries,
    policy?:ApprovedReviewPolicy,private readonly clock:()=>number=Date.now){
    if(policy){this.approved=validateReviewPolicy(policy);this.digest=reviewHash(this.approved);}
  }
  policy(){
    const p=this.approved;if(!p)return {enabled:false as const,reasonCode:'REVIEW_POLICY_UNAVAILABLE' as const};
    const reasons=Object.fromEntries(REVIEW_OUTCOMES.map(k=>[k,p.reasons[k].map(({code,label})=>({code,label}))]));
    return {enabled:true as const,reasonCode:null,version:p.version,digest:this.digest!,checks:structuredClone(p.checks),reasons:structuredClone(reasons)};
  }
  private key(raw:unknown){requireThat(typeof raw==='string'&&raw.length>=1&&raw.length<=128&&!/[\x00-\x1f\x7f]/.test(raw),400,'INVALID_REVIEW_DECISION','Use an idempotency key.');return hash(raw);}
  async describe(actor:StaffActor){await this.db.tx(c=>this.authority.authorize(c,actor,'listener.review.read'));return this.policy();}
  private input(raw:unknown):Input{
    const b=object(raw);fields(b,['expectedMaterialVersion','policyVersion','policyDigest','outcome','checks','reasonCode']);
    const valid=(v:unknown)=>requireThat(v,400,'INVALID_REVIEW_DECISION','Use the current policy and explicit review findings.');
    valid(hex(b.expectedMaterialVersion)&&hex(b.policyDigest)&&typeof b.policyVersion==='string'&&[...b.policyVersion].length>=1&&[...b.policyVersion].length<=80
      &&REVIEW_OUTCOMES.includes(b.outcome as ReviewOutcome)&&slug(b.reasonCode)&&Array.isArray(b.checks)&&b.checks.length>=1&&b.checks.length<=20);
    const checks:Check[]=[],ids=new Set<string>();
    for(const value of b.checks as unknown[]){const c=object(value);fields(c,['id','result','evidenceKinds']);
      valid(slug(c.id)&&!ids.has(c.id as string)&&['pass','fail','not_checked'].includes(c.result as string)
        &&Array.isArray(c.evidenceKinds)&&c.evidenceKinds.length<=3&&new Set(c.evidenceKinds).size===c.evidenceKinds.length
        &&c.evidenceKinds.every(k=>EVIDENCE_KINDS.includes(k as EvidenceKind))
        &&(c.result==='not_checked'?c.evidenceKinds.length===0:c.evidenceKinds.length>0));
      ids.add(c.id as string);checks.push({id:c.id as string,result:c.result as Check['result'],evidenceKinds:[...c.evidenceKinds as EvidenceKind[]].sort()});
    }
    return {...b,checks:checks.sort((a,b)=>a.id.localeCompare(b.id))} as Input;
  }
  private async conflict(c:PoolClient,principal:string,user:string){
    return !!(await c.query(`SELECT 1 FROM staff_principals p WHERE p.id=$1 AND (p.linked_user_id=$2 OR
      EXISTS(SELECT 1 FROM staff_review_conflicts f WHERE f.principal_id=p.id AND f.user_id=$2))`,[principal,user])).rows.length;
  }
  private async authorize(c:PoolClient,actor:StaffActor,owner:string|undefined){
    const view=await this.authority.authorize(c,actor,'listener.review.decide',owner?[owner]:[]);
    requireThat(view.permissions.includes('listener.review.read')&&view.permissions.includes('listener.review.evidence.read'),403,'STAFF_FORBIDDEN','Review and evidence permissions are required.');
    if(owner){await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[owner]);
      requireThat(!await this.conflict(c,actor.staffId,owner),403,'REVIEW_CONFLICT','A different authorized reviewer must review this application.');}
  }
  private async state(c:PoolClient,decision:Row){
    const rows=(await c.query(`SELECT e.consumer,e.state FROM listener_review_effects e JOIN listener_review_outbox o ON o.id=e.event_id WHERE o.decision_id=$1`,[decision.id])).rows;
    const entitlement=rows.find(r=>r.consumer==='entitlement'),notification=rows.find(r=>r.consumer==='notification');
    const user=(await c.query('SELECT listener_approved,suspended,adult_confirmed FROM users WHERE id=$1',[decision.user_id])).rows[0];
    const grant=(await c.query('SELECT 1 FROM listener_review_entitlements WHERE decision_id=$1 AND user_id=$2',[decision.id,decision.user_id])).rows.length;
    const notice=(await c.query('SELECT id,created_at FROM listener_review_notifications WHERE decision_id=$1 AND user_id=$2',[decision.id,decision.user_id])).rows[0];
    return {entitlement:decision.outcome!=='approved'?'not_applicable' as const:entitlement?.state==='pending'?'pending' as const:
      entitlement?.state==='applied'&&grant&&user?.listener_approved&&!user.suspended&&user.adult_confirmed?'active' as const:'withheld' as const,
      notification:notification?.state==='pending'?'pending' as const:notification?.state==='applied'&&notice?'available' as const:'suppressed' as const,notice};
  }
  private async view(c:PoolClient,decision:Row){const effects=await this.state(c,decision);return {decisionId:decision.id as string,applicationId:decision.application_id as string,
    outcome:decision.outcome as ReviewOutcome,policyVersion:decision.policy_version as string,materialVersion:decision.material_version as string,
    reasonCode:decision.reason_code as string,recordedAt:iso(decision.created_at),effects:{entitlement:effects.entitlement,notification:effects.notification}};}
  async receipt(actor:StaffActor,id:string,key:unknown){
    uuid(id);const request=this.key(key),owner=(await this.db.pool.query('SELECT user_id FROM listener_applications WHERE id=$1',[id])).rows[0]?.user_id;
    await this.authority.revalidate(actor);
    return this.db.tx(async c=>{await this.authorize(c,actor,owner);
      const row=(await c.query('SELECT * FROM listener_review_decisions WHERE principal_id=$1 AND application_id=$2 AND request_hash=$3',[actor.staffId,id,request])).rows[0];
      requireThat(row,404,'REVIEW_DECISION_NOT_FOUND','No decision receipt exists for this request.');return this.view(c,row);});
  }
  async decide(actor:StaffActor,id:string,raw:unknown,key:unknown){
    uuid(id);const input=this.input(raw),request=this.key(key),fingerprint=reviewHash({id,...input});
    const owner=(await this.db.pool.query('SELECT user_id FROM listener_applications WHERE id=$1',[id])).rows[0]?.user_id;
    await this.authority.revalidate(actor);
    return this.db.tx(async c=>{
      await this.authorize(c,actor,owner);
      const prior=(await c.query('SELECT * FROM listener_review_decisions WHERE principal_id=$1 AND request_hash=$2',[actor.staffId,request])).rows[0];
      if(prior){requireThat(prior.request_fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different decision.');return this.view(c,prior);}
      const p=this.approved;requireThat(p,503,'REVIEW_POLICY_UNAVAILABLE','Real review decisions require an approved policy.');
      requireThat(input.policyVersion===p.version&&input.policyDigest===this.digest,409,'REVIEW_POLICY_CHANGED','Reload the approved review policy.');
      const app=(await c.query('SELECT state FROM listener_applications WHERE id=$1 FOR UPDATE',[id])).rows[0];
      requireThat(app,404,'REVIEW_NOT_AVAILABLE','This application is unavailable.');
      requireThat(app.state==='submitted',409,'REVIEW_ALREADY_DECIDED','This submission is no longer awaiting a decision.');
      const material=await this.reviews.lockedMaterial(c,id);
      requireThat(material.version===input.expectedMaterialVersion,409,'REVIEW_MATERIAL_CHANGED','Reload the submitted material before deciding.');
      const reason=p.reasons[input.outcome].find(r=>r.code===input.reasonCode);
      requireThat(reason&&input.checks.length===p.checks.length&&input.checks.every(c=>p.checks.some(check=>check.id===c.id)),400,'INVALID_REVIEW_DECISION','Record every required policy check and an approved reason.');
      const saved=[];
      for(const result of input.checks){const check=p.checks.find(c=>c.id===result.id)!;
        requireThat(result.evidenceKinds.every(k=>check.evidenceKinds.includes(k))&&(input.outcome!=='approved'||!check.requiredForApproval||result.result==='pass'),400,'INVALID_REVIEW_DECISION','Approval requires every mandatory check to pass.');
        const evidence=[];
        for(const kind of result.evidenceKinds){
          requireThat(kind!=='voice_sample'||material.sampleAvailable,409,'REVIEW_MATERIAL_CHANGED','A current consented sample is required.');
          const action=kind==='voice_sample'?'sample.read':'detail.read';
          const access=(await c.query(`SELECT id FROM staff_review_access_events WHERE principal_id=$1 AND application_id=$2 AND material_version=$3 AND action=$4 ORDER BY created_at DESC,id DESC LIMIT 1`,[actor.staffId,id,material.version,action])).rows[0];
          requireThat(access,400,'INVALID_REVIEW_DECISION','Read the current evidence before recording a finding.');evidence.push({kind,accessEventId:access.id});
        }
        saved.push({id:result.id,result:result.result,evidence});
      }
      requireThat(input.outcome!=='needs_information'||input.checks.some(c=>c.result==='not_checked'||c.result==='fail'),400,'INVALID_REVIEW_DECISION','Identify a missing or failed check.');
      requireThat(input.outcome!=='rejected'||input.checks.some(c=>c.result==='fail'),400,'INVALID_REVIEW_DECISION','A rejection requires a recorded failed check.');
      await c.query(`INSERT INTO listener_review_policy_versions(version,digest,definition,approval_reference) VALUES($1,$2,$3,$4) ON CONFLICT(version) DO NOTHING`,[p.version,this.digest,p,p.approvalReference]);
      const stored=(await c.query('SELECT digest FROM listener_review_policy_versions WHERE version=$1',[p.version])).rows[0];
      requireThat(stored.digest===this.digest,409,'REVIEW_POLICY_CHANGED','The approved policy version must not change in place.');
      const decisionId=randomUUID(),eventId=randomUUID(),at=new Date(this.clock());
      const decision=(await c.query(`INSERT INTO listener_review_decisions(id,application_id,user_id,principal_id,session_id,policy_version,policy_digest,material_version,outcome,checks,reason_code,request_hash,request_fingerprint,created_at)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING *`,[decisionId,id,owner,actor.staffId,actor.sessionId,p.version,this.digest,material.version,input.outcome,JSON.stringify(saved),input.reasonCode,request,fingerprint,at])).rows[0];
      await c.query("UPDATE listener_applications SET state=$2,decided_at=CASE WHEN $2 IN ('approved','rejected') THEN $3::timestamptz ELSE NULL END,current_review_decision_id=$4 WHERE id=$1",[id,input.outcome,at,decisionId]);
      await c.query('INSERT INTO listener_review_outbox(id,decision_id,created_at) VALUES($1,$2,$3)',[eventId,decisionId,at]);
      await c.query("INSERT INTO listener_review_effects(event_id,consumer) VALUES($1,'notification')",[eventId]);
      if(input.outcome==='approved')await c.query("INSERT INTO listener_review_effects(event_id,consumer) VALUES($1,'entitlement')",[eventId]);
      return this.view(c,decision);
    });
  }
  async processPending(limit=20){
    requireThat(Number.isSafeInteger(limit)&&limit>=1&&limit<=100,400,'INVALID_FIELD','Invalid review work limit.');
    if(!this.approved)return {processed:0};
    // Nonlocking candidates; no outbox row is held while acquiring an owner.
    // Rotation changes new decisions, not valid decisions already committed
    // under an immutable approved version. Default-off still pauses all work.
    const candidates=(await this.db.pool.query(`SELECT d.*,o.id event_id FROM listener_review_outbox o JOIN listener_review_decisions d ON d.id=o.decision_id
      JOIN listener_review_policy_versions p ON p.version=d.policy_version AND p.digest=d.policy_digest
      WHERE EXISTS(SELECT 1 FROM listener_review_effects e WHERE e.event_id=o.id AND e.state='pending')
      ORDER BY o.created_at,o.id LIMIT $1`,[limit])).rows;
    let processed=0;
    for(const decision of candidates){processed+=await this.db.tx(async c=>{
      await c.query('SELECT id FROM staff_principals WHERE id=$1 FOR NO KEY UPDATE',[decision.principal_id]);
      const user=(await c.query('SELECT * FROM users WHERE id=$1 FOR NO KEY UPDATE',[decision.user_id])).rows[0];
      const app=(await c.query('SELECT state FROM listener_applications WHERE id=$1 FOR UPDATE',[decision.application_id])).rows[0];
      const effects=(await c.query("SELECT * FROM listener_review_effects WHERE event_id=$1 AND state='pending' ORDER BY consumer FOR UPDATE SKIP LOCKED",[decision.event_id])).rows;
      const restricted=!user||user.suspended||!user.adult_confirmed;
      const conflict=await this.conflict(c,decision.principal_id,decision.user_id),at=new Date(this.clock());
      for(const effect of effects){let state='applied',reason='completed';
        if(effect.consumer==='entitlement'){
          if(restricted||conflict||app?.state!=='approved'){state='withheld';reason=conflict?'review_conflict':'account_restricted';}
          else{await c.query('INSERT INTO listener_review_entitlements(decision_id,event_id,user_id,created_at) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING',[decision.id,decision.event_id,decision.user_id,at]);
            await c.query('UPDATE users SET listener_approved=true WHERE id=$1',[decision.user_id]);}
        }else if(restricted){state='suppressed';reason='account_restricted';}
        else await c.query('INSERT INTO listener_review_notifications(id,event_id,decision_id,user_id,created_at) VALUES($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING',[randomUUID(),decision.event_id,decision.id,decision.user_id,at]);
        await c.query('UPDATE listener_review_effects SET state=$3,reason_code=$4,completed_at=$5 WHERE event_id=$1 AND consumer=$2',[decision.event_id,effect.consumer,state,reason,at]);
      }
      return effects.length;
    });}
    return {processed};
  }
  async ownerStatus(actor:Actor){
    return this.db.tx(async c=>{
      const owner=(await c.query('SELECT * FROM users WHERE id=$1 FOR NO KEY UPDATE',[actor.id])).rows[0];
      const session=(await c.query('SELECT 1 FROM auth_sessions WHERE user_id=$1 AND token_hash=$2 AND revoked_at IS NULL AND expires_at>$3',[actor.id,actor.sessionHash,new Date(this.clock())])).rows[0];
      requireThat(owner&&!owner.suspended&&session,401,'UNAUTHENTICATED','Sign in again.');
      const app=(await c.query('SELECT id,state,current_review_decision_id FROM listener_applications WHERE user_id=$1 ORDER BY created_at DESC,id DESC LIMIT 1',[actor.id])).rows[0];
      const empty={applicationId:app?.id??null,state:app?.state??null,review:null};
      if(!app||!REVIEW_OUTCOMES.includes(app.state))return empty;
      const d=(await c.query(`SELECT d.*,p.definition FROM listener_review_decisions d JOIN listener_review_policy_versions p ON p.version=d.policy_version
        WHERE d.id=$4 AND d.application_id=$1 AND d.user_id=$2 AND d.outcome=$3`,[app.id,actor.id,app.state,app.current_review_decision_id])).rows[0];
      if(!d)return empty;
      const policy=d.definition as ApprovedReviewPolicy,reason=policy.reasons[d.outcome as ReviewOutcome].find(r=>r.code===d.reason_code)!;
      const effects=await this.state(c,d),missing=new Set((d.checks as Row[]).filter(r=>r.result!=='pass').map(r=>r.id));
      return {...empty,review:{applicationId:app.id as string,decisionId:d.id as string,outcome:d.outcome as ReviewOutcome,reasonCode:d.reason_code as string,
        message:reason.message,missingChecks:d.outcome==='needs_information'?policy.checks.filter(check=>missing.has(check.id)).map(({id,label})=>({id,label})):[],
        recordedAt:iso(d.created_at),entitlement:effects.entitlement,notification:effects.notice?{id:effects.notice.id as string,createdAt:iso(effects.notice.created_at)}:null}};
    });
  }
}
