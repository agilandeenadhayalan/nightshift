import {createHash,createHmac,randomBytes,randomUUID} from 'node:crypto';
import {PoolClient} from 'pg';
import {TEST_RATE} from '@nightshift/backend-domain';
import {Actor} from './auth';
import {Database} from './db';
import {Presence} from './presence';
import {ApiError,fields,object,requireThat,uuid} from './errors';

type Row=Record<string,any>;
export const MATCHING_LIMITS={attempts:3,waitMs:90000,ringMs:30000,minRingMs:1000,candidates:50,probes:3,declineCooldownMs:600000} as const;
export interface MatchingCandidate {id:string;eligibleSince:number;lastOfferedAt:number|null;recentAccepted:number;recentOffered:number;}
/** Waiting comes first; unknown acceptance history has a neutral Bayesian prior.
 * Randomness only resolves otherwise equal priorities and is never authorization. */
export function rankMatchingCandidates<T extends MatchingCandidate>(candidates:readonly T[],seed:Buffer):T[]{
  const tie=(id:string)=>createHmac('sha256',seed).update(id).digest('hex');
  const score=(r:T)=>(r.recentAccepted+1)/(r.recentOffered+2);
  return [...candidates].sort((a,b)=>(a.lastOfferedAt??a.eligibleSince)-(b.lastOfferedAt??b.eligibleSince)
    ||score(b)-score(a)||tie(a.id).localeCompare(tie(b.id))||a.id.localeCompare(b.id));
}
export interface MatchingCallPort {
  authorize(c:PoolClient,actor:Actor):Promise<Row>;
  reserve(c:PoolClient,actor:Actor,listenerId:string,quoteId:string,expiresAt:number,requestId:string,language:string):Promise<Row>;
  advance(c:PoolClient,call:Row,now:number):Promise<void>;
  finish(c:PoolClient,call:Row,reason:string,now:number):Promise<void>;
}
export type MatchingState='searching'|'ringing'|'matched'|'cancelled'|'exhausted'|'expired'|'failed';
export type MatchingReason='no_supply'|'all_declined'|'attempts_exhausted'|'wait_budget_elapsed'|'customer_cancelled'|'source_session_ended'|'account_restricted'|'safety_blocked'|'insufficient_balance'|'quote_unavailable';
const active=(r:Row)=>r.state==='searching'||r.state==='ringing';
const ms=(v:unknown)=>new Date(v as string).getTime();
const hash=(v:string)=>createHash('sha256').update(v).digest('hex');
const reasons=['language_match','currently_available','fair_rotation'] as const;
const retryable=new Set(['LISTENER_OFFLINE','LISTENER_BUSY','PAIR_BLOCKED','LANGUAGE_MISMATCH']);
class RetrySelection extends Error{}

/** Durable ninety-second consent, separate from the existing call lifecycle.
 * No provider tokens, timers or Redis values establish request ownership. */
export class MatchingCoordinator {
  constructor(private readonly db:Database,private readonly presence:Presence,private readonly calls:MatchingCallPort,
    private readonly clock:()=>number=Date.now,private readonly seed:()=>Buffer=()=>randomBytes(32)){}
  private key(raw:unknown){requireThat(typeof raw==='string'&&raw.length>=1&&raw.length<=128&&!/[\x00-\x1f\x7f]/.test(raw),400,'INVALID_MATCH_REQUEST','Use an idempotency key.');return hash(raw);}
  private view(r:Row){
    const current=r.state==='ringing'||r.state==='matched';
    return {id:r.id as string,version:Number(r.version),state:r.state as MatchingState,language:r.language as 'ta'|'en',mediaType:'audio' as const,
      quoteId:r.quote_id as string,attemptCount:Number(r.attempt_count),maxAttempts:3 as const,waitBudgetSeconds:90 as const,invitationSeconds:30 as const,
      createdAt:new Date(r.created_at).toISOString(),deadlineAt:new Date(r.deadline_at).toISOString(),endedAt:r.ended_at?new Date(r.ended_at).toISOString():null,
      currentCallId:current?r.current_call_id as string:null,terminalReason:r.terminal_reason as MatchingReason|null,
      selectionReasons:current?[...reasons]:[],serverTime:new Date(this.clock()).toISOString(),testOnly:true as const};
  }
  private async source(c:PoolClient,r:Row):Promise<Actor|undefined>{
    const rows=(await c.query(`SELECT s.token_hash FROM users u JOIN auth_sessions s ON s.user_id=u.id
      LEFT JOIN devices d ON d.id=s.device_record_id AND d.user_id=u.id
      WHERE u.id=$1 AND NOT u.suspended AND u.adult_confirmed AND s.revoked_at IS NULL AND s.expires_at>$2
      AND (( $3='development' AND s.auth_kind='development' AND s.token_hash=$4)
        OR ($3='firebase' AND s.auth_kind='firebase' AND d.id=$5 AND d.active AND d.revoked_at IS NULL
          AND d.last_token_hash=s.token_hash AND u.identity_last_auth_time=$6
          AND (u.identity_revoked_before IS NULL OR u.identity_revoked_before<$6)
          AND EXISTS(SELECT 1 FROM auth_identities i WHERE i.id=$7 AND i.user_id=u.id AND i.state='verified')))`,
      [r.customer_id,new Date(this.clock()),r.source_kind,r.source_session_hash,r.source_device_id,r.source_auth_time,r.source_identity_id])).rows;
    return rows.length===1?{id:r.customer_id,sessionHash:rows[0].token_hash,...(r.source_auth_time===null?{}:{identityAuthTime:Number(r.source_auth_time)})}:undefined;
  }
  async start(actor:Actor,raw:unknown,key:unknown){
    const b=object(raw);fields(b,['language','mediaType','quoteId','consent','consentVersion']);
    requireThat(b.consent===true&&b.consentVersion==='matching-search-v1',400,'CONSENT_REQUIRED','Agree to this bounded search before starting.');
    requireThat(b.language==='ta'||b.language==='en',400,'INVALID_LANGUAGE','Select Tamil or English');
    requireThat(b.mediaType==='audio'&&typeof b.quoteId==='string'&&b.quoteId.length>=1&&b.quoteId.length<=128,400,'INVALID_MATCH_REQUEST','Choose the current audio quote.');
    const requestKey=this.key(key),fingerprint=hash(JSON.stringify({language:b.language,mediaType:b.mediaType,quoteId:b.quoteId,consent:true,consentVersion:b.consentVersion}));
    return this.db.tx(async c=>{
      const owner=await this.calls.authorize(c,actor);
      const old=(await c.query('SELECT * FROM matching_requests WHERE customer_id=$1 AND request_key_hash=$2',[actor.id,requestKey])).rows[0];
      if(old){requireThat(old.request_fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different search.');return this.view(old);}
      requireThat(owner.mode==='customer',403,'CUSTOMER_MODE_REQUIRED','Switch to Customer mode.');
      requireThat(owner.languages.includes(b.language),400,'INVALID_LANGUAGE','Choose one of your speaking languages.');
      requireThat(b.quoteId===TEST_RATE.id,409,'QUOTE_EXPIRED','Refresh the audio quote.');
      await assertNoActiveMatching(c,actor.id);
      requireThat(!(await c.query('SELECT 1 FROM active_participant_claims WHERE user_id=$1',[actor.id])).rowCount,409,'CALL_ACTIVE','End the current call first.');
      const balance=(await c.query(`SELECT (SELECT coalesce(sum(amount),0) FROM journal_lines WHERE account_id=$1)
        -(SELECT coalesce(sum(amount),0) FROM spend_holds WHERE user_id=$2 AND released_at IS NULL) amount`,[`customer:${actor.id}`,actor.id])).rows[0];
      requireThat(Number(balance.amount)>=60*TEST_RATE.microcreditsPerSecond,409,'INSUFFICIENT_BALANCE','At least one minute of test credits is required.');
      requireThat(await this.presence.rateLimit(`matching:${actor.id}`,5,60),429,'RATE_LIMITED','Wait before starting another search.');
      // Redis admission can outlive the local session despite the owner lock.
      await this.calls.authorize(c,actor);
      const session=(await c.query('SELECT * FROM auth_sessions WHERE token_hash=$1 AND user_id=$2',[actor.sessionHash,actor.id])).rows[0];
      const phone=session.auth_kind==='firebase';
      requireThat(!phone||(actor.identityAuthTime!==undefined&&actor.identityBindingId&&Number(owner.identity_last_auth_time)===actor.identityAuthTime),401,'UNAUTHENTICATED','Sign in again.');
      const now=this.clock(),seed=this.seed();requireThat(Buffer.isBuffer(seed)&&seed.length===32,503,'SERVICE_UNAVAILABLE','Search is unavailable.');
      const row=(await c.query(`INSERT INTO matching_requests(id,customer_id,state,language,quote_id,consent_version,source_kind,
        source_session_hash,source_device_id,source_auth_time,source_identity_id,request_key_hash,request_fingerprint,selection_seed,created_at,deadline_at,updated_at)
        VALUES($1,$2,'searching',$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$14) RETURNING *`,
        [randomUUID(),actor.id,b.language,b.quoteId,b.consentVersion,session.auth_kind,phone?null:actor.sessionHash,
          phone?session.device_record_id:null,phone?actor.identityAuthTime:null,phone?actor.identityBindingId:null,requestKey,fingerprint,seed,new Date(now),new Date(now+MATCHING_LIMITS.waitMs)])).rows[0];
      return this.view(row);
    });
  }
  async current(actor:Actor){
    const row=await this.db.tx(async c=>{await this.calls.authorize(c,actor);return(await c.query('SELECT id FROM matching_requests WHERE customer_id=$1 ORDER BY sequence DESC LIMIT 1',[actor.id])).rows[0];});
    return {request:row?await this.get(actor,row.id):null};
  }
  async get(actor:Actor,id:string){uuid(id);return this.transition(id,{actor,select:false});}
  async cancel(actor:Actor,id:string,raw:unknown,key:unknown){
    uuid(id);const b=object(raw);fields(b,['expectedVersion']);
    requireThat(Number.isSafeInteger(b.expectedVersion)&&Number(b.expectedVersion)>=1,400,'VERSION_REQUIRED','Refresh the search version.');
    return this.transition(id,{actor,select:false,cancel:{version:Number(b.expectedVersion),key:this.key(key),fingerprint:hash(JSON.stringify({expectedVersion:b.expectedVersion}))}});
  }
  private async update(c:PoolClient,r:Row,state:MatchingState,reason:MatchingReason|null=null){
    const now=new Date(this.clock());
    const row=(await c.query(`UPDATE matching_requests SET state=$2,version=version+1,terminal_reason=$3,
      ended_at=$4,updated_at=$5,attempt_count=$6,current_call_id=$7,scan_after_time=$8,scan_after_id=$9 WHERE id=$1 RETURNING *`,
      [r.id,state,reason,state==='searching'||state==='ringing'?null:now,now,r.attempt_count,r.current_call_id,r.scan_after_time,r.scan_after_id])).rows[0];
    Object.assign(r,row);return r;
  }
  private async candidates(r:Row,excluded:string[]):Promise<{id?:string;afterTime:string|null;afterId:string|null;complete:boolean}>{
    let afterTime=r.scan_after_time?new Date(r.scan_after_time).toISOString():null,afterId=r.scan_after_id??null;
    // Preserve PostgreSQL microseconds at the stored continuation boundary.
    if(afterTime)afterTime=(await this.db.pool.query(`SELECT to_char(scan_after_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') value FROM matching_requests WHERE id=$1`,[r.id])).rows[0].value;
    for(let page=0;page<3;page++){
    const rows=(await this.db.pool.query(`SELECT u.id,u.presence_version,u.created_at,
      coalesce((SELECT min(e.created_at) FROM listener_review_entitlements e WHERE e.user_id=u.id),u.created_at) eligible_since,f.last_offered_at,
      to_char(coalesce(f.last_offered_at,(SELECT min(e.created_at) FROM listener_review_entitlements e WHERE e.user_id=u.id),u.created_at) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') rank_time,
      coalesce(history.accepted,0) recent_accepted,coalesce(history.offered,0) recent_offered
      FROM users u LEFT JOIN matching_listener_fairness f ON f.listener_id=u.id
      LEFT JOIN LATERAL (SELECT count(*) offered,count(*) FILTER(WHERE q.accepted_at IS NOT NULL) accepted FROM
        (SELECT s.accepted_at FROM matching_attempts a JOIN call_sessions s ON s.id=a.call_id WHERE a.listener_id=u.id ORDER BY a.created_at DESC LIMIT 20) q) history ON true
      WHERE u.id<>$1 AND u.listener_approved AND u.adult_confirmed AND NOT u.suspended AND u.mode='listener' AND u.desired_online
      AND $2=ANY(u.languages) AND NOT(u.id=ANY($3::uuid[]))
      AND NOT EXISTS(SELECT 1 FROM blocks b WHERE (b.actor_id=$1 AND b.target_id=u.id) OR (b.target_id=$1 AND b.actor_id=u.id))
      AND NOT EXISTS(SELECT 1 FROM active_participant_claims a WHERE a.user_id=u.id)
      AND NOT EXISTS(SELECT 1 FROM matching_attempts a WHERE a.request_id=$4 AND a.listener_id=u.id)
      AND NOT EXISTS(SELECT 1 FROM call_sessions s WHERE s.customer_id=$1 AND s.listener_id=u.id AND s.reason='declined' AND s.ended_at>$5)
      AND EXISTS(SELECT 1 FROM auth_sessions s LEFT JOIN devices d ON d.id=s.device_record_id WHERE s.user_id=u.id AND s.revoked_at IS NULL
        AND s.expires_at>$6 AND (s.auth_kind='development' OR (d.active AND d.revoked_at IS NULL AND d.last_token_hash=s.token_hash)))
      AND ($7::timestamptz IS NULL OR (coalesce(f.last_offered_at,(SELECT min(e.created_at) FROM listener_review_entitlements e WHERE e.user_id=u.id),u.created_at),u.id)>($7::timestamptz,$8::uuid))
      ORDER BY coalesce(f.last_offered_at,(SELECT min(e.created_at) FROM listener_review_entitlements e WHERE e.user_id=u.id),u.created_at),u.id LIMIT 50`,
      [r.customer_id,r.language,excluded,r.id,new Date(this.clock()-MATCHING_LIMITS.declineCooldownMs),new Date(this.clock()),afterTime,afterId])).rows;
    const online=new Set(await this.presence.online(rows.map(r=>r.id),new Map(rows.map(r=>[r.id,String(r.presence_version)]))));
    const ranked=rankMatchingCandidates(rows.filter(r=>online.has(r.id)).map(r=>({id:r.id,eligibleSince:ms(r.eligible_since),lastOfferedAt:r.last_offered_at?ms(r.last_offered_at):null,
      recentAccepted:Number(r.recent_accepted),recentOffered:Number(r.recent_offered)})),r.selection_seed);
    if(ranked.length)return{id:ranked[0]!.id,afterTime,afterId,complete:false};
    if(rows.length<50)return{afterTime,afterId,complete:true};
    afterTime=rows.at(-1)!.rank_time;afterId=rows.at(-1)!.id;
    }return{afterTime,afterId,complete:false};
  }
  private async exhaustedReason(c:PoolClient,r:Row):Promise<MatchingReason>{
    if(!r.attempt_count)return 'no_supply';
    const rows=(await c.query('SELECT s.reason FROM matching_attempts a JOIN call_sessions s ON s.id=a.call_id WHERE a.request_id=$1',[r.id])).rows;
    return rows.length&&rows.every(r=>r.reason==='declined')?'all_declined':'attempts_exhausted';
  }
  private async transition(id:string,options:{actor?:Actor;select:boolean;cancel?:{version:number;key:string;fingerprint:string}}):Promise<ReturnType<MatchingCoordinator['view']>>{
    const excluded:string[]=[];
    for(let probe=0;probe<MATCHING_LIMITS.probes;probe++){
      const initial=(await this.db.pool.query(`SELECT m.*,s.listener_id old_listener,s.state call_state,s.accepted_at FROM matching_requests m
        LEFT JOIN call_sessions s ON s.id=m.current_call_id WHERE m.id=$1`,[id])).rows[0];
      if(!initial||options.actor&&initial.customer_id!==options.actor.id)throw new ApiError(404,'MATCH_NOT_FOUND','Search not found.');
      const choose=options.select&&active(initial)&&!initial.accepted_at&&(!initial.current_call_id||initial.call_state==='ended')
        &&initial.attempt_count<3&&ms(initial.deadline_at)-this.clock()>=MATCHING_LIMITS.minRingMs;
      const selection=choose?await this.candidates(initial,excluded):undefined,candidate=selection?.id;
      if(candidate)excluded.push(candidate);
      try{return await this.db.tx(async c=>{
        const users=[...new Set([initial.customer_id,initial.old_listener,candidate].filter(Boolean))].sort();
        await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[users]);
        if(options.actor)await this.calls.authorize(c,options.actor);
        const r=(await c.query('SELECT * FROM matching_requests WHERE id=$1 FOR UPDATE',[id])).rows[0];
        if(r.current_call_id!==initial.current_call_id||r.version!==initial.version)throw new RetrySelection();
        let command:Row|undefined;
        if(options.cancel){command=(await c.query('SELECT fingerprint FROM matching_commands WHERE request_id=$1 AND key_hash=$2',[id,options.cancel.key])).rows[0];
          if(command)requireThat(command.fingerprint===options.cancel.fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different cancellation.');}
        const recordCancel=async()=>{if(options.cancel&&!command)await c.query('INSERT INTO matching_commands(request_id,customer_id,key_hash,fingerprint,created_at) VALUES($1,$2,$3,$4,$5)',
          [r.id,r.customer_id,options.cancel.key,options.cancel.fingerprint,new Date(this.clock())]);};
        if(!active(r)){await recordCancel();return this.view(r);}
        await c.query('UPDATE matching_requests SET last_processed_at=clock_timestamp() WHERE id=$1',[r.id]);
        let call=r.current_call_id?(await c.query('SELECT * FROM call_sessions WHERE id=$1 FOR UPDATE',[r.current_call_id])).rows[0]:undefined;
        // Acceptance is permanent even if the call already ended before this pass.
        if(call?.accepted_at){await this.update(c,r,'matched');await recordCancel();return this.view(r);}
        const owner=(await c.query('SELECT * FROM users WHERE id=$1',[r.customer_id])).rows[0],source=await this.source(c,r);
        const terminate=async(state:MatchingState,reason:MatchingReason)=>{
          if(call&&call.state!=='ended')await this.calls.finish(c,call,reason==='wait_budget_elapsed'?'timeout':'cancelled',this.clock());
          await this.update(c,r,state,reason);return this.view(r);
        };
        if(!owner||owner.suspended||!owner.adult_confirmed)return terminate('failed','account_restricted');
        if(!source)return terminate('cancelled','source_session_ended');
        if(owner.mode!=='customer'||!owner.languages.includes(r.language))return terminate('failed','account_restricted');
        if(options.cancel&&!command){
          requireThat(r.version===options.cancel.version,409,'MATCH_STALE_VERSION','Refresh the search before cancelling.');
          await recordCancel();
          return terminate('cancelled','customer_cancelled');
        }
        if(call){await this.calls.advance(c,call,this.clock());
          if(call.state==='ended'&&call.reason==='blocked')return terminate('cancelled','safety_blocked');
          if(call.state==='ended'&&['cancelled','participant_ended'].includes(call.reason))return terminate('cancelled','customer_cancelled');}
        if(this.clock()>=ms(r.deadline_at))return terminate('expired','wait_budget_elapsed');
        if(call&&call.state!=='ended')return this.view(r);
        if(r.attempt_count>=3)return terminate('exhausted',await this.exhaustedReason(c,r));
        if(!options.select){if(r.state==='ringing')await this.update(c,r,'searching');return this.view(r);}
        if(ms(r.deadline_at)-this.clock()<MATCHING_LIMITS.minRingMs)return terminate('expired','wait_budget_elapsed');
        // A ringing snapshot can expire during this pass: reselect next tick,
        // rather than treating an unperformed candidate read as no supply.
        if(!choose){if(r.state==='ringing')await this.update(c,r,'searching');return this.view(r);}
        if(!candidate){
          if(selection&&!selection.complete){r.scan_after_time=selection.afterTime;r.scan_after_id=selection.afterId;await this.update(c,r,'searching');return this.view(r);}
          return terminate('exhausted',await this.exhaustedReason(c,r));
        }
        try{call=await this.calls.reserve(c,source,candidate,r.quote_id,Math.min(this.clock()+MATCHING_LIMITS.ringMs,ms(r.deadline_at)),r.id,r.language);}
        catch(error){if(error instanceof ApiError&&error.code==='MATCH_DEADLINE')return terminate('expired','wait_budget_elapsed');
          if(error instanceof ApiError&&['INSUFFICIENT_BALANCE','QUOTE_EXPIRED'].includes(error.code))
            return terminate('failed',error.code==='INSUFFICIENT_BALANCE'?'insufficient_balance':'quote_unavailable');throw error;}
        await c.query('INSERT INTO matching_attempts(request_id,ordinal,listener_id,call_id,selection_reasons,created_at) VALUES($1,$2,$3,$4,$5,$6)',
          [r.id,r.attempt_count+1,candidate,call.id,[...reasons],new Date(this.clock())]);
        await c.query('INSERT INTO matching_listener_fairness(listener_id,last_offered_at) VALUES($1,$2) ON CONFLICT(listener_id) DO UPDATE SET last_offered_at=EXCLUDED.last_offered_at',[candidate,new Date(this.clock())]);
        r.attempt_count++;r.current_call_id=call.id;r.scan_after_time=null;r.scan_after_id=null;await this.update(c,r,'ringing');return this.view(r);
      });}catch(error){
        if(error instanceof RetrySelection||error instanceof ApiError&&retryable.has(error.code))continue;
        throw error;
      }
    }
    // Reads/workers can retry next pass; a successful command must never imply
    // that cancellation committed when every locked snapshot was superseded.
    return this.db.tx(async c=>{await c.query('SELECT id FROM users WHERE id=(SELECT customer_id FROM matching_requests WHERE id=$1) FOR NO KEY UPDATE',[id]);
      if(options.actor)await this.calls.authorize(c,options.actor);
      requireThat(!options.cancel,409,'MATCH_STALE_VERSION','Refresh the search before cancelling.');
      const row=(await c.query('SELECT * FROM matching_requests WHERE id=$1',[id])).rows[0];return this.view(row);});
  }
  async processPending(limit=20){
    requireThat(Number.isSafeInteger(limit)&&limit>=1&&limit<=100,400,'INVALID_MATCH_REQUEST','Use a bounded work limit.');
    const pending=(await this.db.pool.query("SELECT id,customer_id,version FROM matching_requests WHERE state IN ('searching','ringing') ORDER BY last_processed_at,sequence LIMIT $1",[limit])).rows;
    let processed=0,firstFailure:{error:unknown}|undefined;
    for(const r of pending){
      try{const next=await this.transition(r.id,{select:true});if(next.version!==r.version)processed++;}
      catch(error){
        firstFailure??={error};
        // A failed reservation rolls back all business state. Rotate only its
        // scheduling timestamp separately so one poison request cannot occupy
        // the first work slot forever. A DB-wide failure ends this pass.
        try{await this.db.tx(async c=>{
          await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[r.customer_id]);
          await c.query("UPDATE matching_requests SET last_processed_at=clock_timestamp() WHERE id=$1 AND state IN ('searching','ringing')",[r.id]);
        });}catch{throw error;}
      }
    }
    // Surface the original failure to the bounded worker's error boundary,
    // after giving the other selected requests their independent opportunity.
    if(firstFailure)throw firstFailure.error;
    return {processed};
  }
  /** Logout/deletion already holds this owner. No new participant/user locks
   * are taken here; accepted calls remain permanently matched. */
  async stopOwnerLocked(c:PoolClient,owner:string,reason:'source_session_ended'|'account_restricted'){
    const rows=(await c.query("SELECT * FROM matching_requests WHERE customer_id=$1 AND state IN ('searching','ringing') ORDER BY id FOR UPDATE",[owner])).rows;
    for(const r of rows){const accepted=r.current_call_id&&(await c.query('SELECT accepted_at FROM call_sessions WHERE id=$1',[r.current_call_id])).rows[0]?.accepted_at;
      await this.update(c,r,accepted?'matched':'cancelled',accepted?null:reason);}
  }
}

/** Caller already holds the owner lock used by matching creation. */
export async function assertNoActiveMatching(c:PoolClient,userId:string,allowedRequest?:string){
  const active=await c.query("SELECT id FROM matching_requests WHERE customer_id=$1 AND state IN ('searching','ringing') AND ($2::uuid IS NULL OR id<>$2)",[userId,allowedRequest??null]);
  requireThat(!active.rowCount,409,'MATCH_ACTIVE','Cancel the current search before starting another action.');
}
