import { randomUUID, createHash } from 'node:crypto';
import { PoolClient } from 'pg';
import { Database } from './db';
import { Presence } from './presence';
import { Actor } from './auth';
import { Config } from './config';
import { ApiError, requireThat, fields, object, string, uuid } from './errors';
import { MICRO, TEST_RATE, testCharge, testEarning } from '@nightshift/backend-domain';

type Row = Record<string, any>;
type Query = Pick<PoolClient, 'query'>;
const dateMs = (value: unknown) => value ? new Date(value as string).getTime() : 0;
const iso = (value: unknown) => value ? new Date(value as string).toISOString() : null;
export class NightShiftService {
  constructor(readonly db: Database, readonly presence: Presence, readonly config: Config,
    private readonly clock: () => number = Date.now) {}

  async user(id: string, c: Query = this.db.pool) {
    const { rows } = await c.query('SELECT * FROM users WHERE id=$1', [id]);
    requireThat(rows.length, 404, 'NOT_FOUND', 'Account not found');
    const u = rows[0];
    return { id: u.id, displayName: u.display_name, languages: u.languages, mode: u.mode,
      listenerApproved: u.listener_approved, online: u.desired_online && await this.presence.isOnline(id) };
  }
  async wallet(id: string, c: Query = this.db.pool) {
    const balance = await c.query('SELECT coalesce(sum(amount),0)::text total FROM journal_lines WHERE account_id=$1', [`customer:${id}`]);
    const holds = await c.query('SELECT coalesce(sum(amount),0)::text total FROM spend_holds WHERE user_id=$1 AND released_at IS NULL', [id]);
    const balanceMicrocredits = Number(balance.rows[0].total); const heldMicrocredits = Number(holds.rows[0].total);
    return { balanceMicrocredits, heldMicrocredits, availableMicrocredits: balanceMicrocredits-heldMicrocredits, testOnly: true };
  }
  async snapshot(actor: Actor, language = 'ta') {
    await this.recover();
    const active = await this.db.pool.query('SELECT call_id FROM active_participant_claims WHERE user_id=$1', [actor.id]);
    return { user: await this.user(actor.id), activeCall: active.rows[0] ? await this.call(actor.id, active.rows[0].call_id) : null,
      listeners: (await this.listeners(actor.id, language)).items, wallet: await this.wallet(actor.id), serverTime: new Date(this.clock()).toISOString() };
  }
  async heartbeat(actor: Actor) {
    const { rows } = await this.db.pool.query('SELECT desired_online,listener_approved,mode FROM users WHERE id=$1', [actor.id]);
    if (rows[0]?.desired_online && rows[0].listener_approved && rows[0].mode === 'listener') await this.presence.heartbeat(actor.id, actor.sessionHash);
    return { serverTime: new Date(this.clock()).toISOString() };
  }
  async mode(actor: Actor, raw: unknown) {
    const body = object(raw); fields(body, ['mode']);
    requireThat(['customer','listener'].includes(String(body.mode)), 400, 'INVALID_MODE', 'Choose Customer or Listener');
    await this.db.tx(async c => {
      const { rows } = await c.query('SELECT listener_approved FROM users WHERE id=$1 FOR NO KEY UPDATE', [actor.id]);
      requireThat(body.mode !== 'listener' || rows[0].listener_approved, 403, 'LISTENER_NOT_APPROVED', 'Listener approval is required');
      const active = await c.query('SELECT 1 FROM active_participant_claims WHERE user_id=$1', [actor.id]);
      requireThat(!active.rowCount, 409, 'CALL_ACTIVE', 'End the call before switching modes');
      await c.query('UPDATE users SET mode=$2,desired_online=false WHERE id=$1', [actor.id,body.mode]);
    });
    await this.presence.clear(actor.id);
    return this.user(actor.id);
  }
  async availability(actor: Actor, raw: unknown) {
    const body = object(raw); fields(body, ['online']);
    requireThat(typeof body.online === 'boolean', 400, 'INVALID_FIELD', 'online must be a boolean');
    await this.db.tx(async c => {
      const { rows } = await c.query('SELECT * FROM users WHERE id=$1 FOR NO KEY UPDATE', [actor.id]);
      requireThat(rows[0].listener_approved && rows[0].mode === 'listener', 403, 'LISTENER_NOT_APPROVED', 'Use approved Listener mode');
      await c.query('UPDATE users SET desired_online=$2 WHERE id=$1', [actor.id, body.online]);
    });
    if (body.online) await this.presence.heartbeat(actor.id, actor.sessionHash); else await this.presence.clear(actor.id);
    return this.user(actor.id);
  }
  async languages(actor: Actor, raw: unknown) {
    const body=object(raw); fields(body,['languages']);
    requireThat(Array.isArray(body.languages) && body.languages.length>0 && body.languages.length<=2 && body.languages.every(x=>['ta','en'].includes(x)),400,'INVALID_LANGUAGE','Select Tamil or English');
    await this.db.pool.query('UPDATE users SET languages=$2 WHERE id=$1',[actor.id,[...new Set(body.languages)]]);
    return this.user(actor.id);
  }
  async listeners(actorId: string, language = 'ta', cursor?: string) {
    requireThat(['ta','en'].includes(language), 400, 'INVALID_LANGUAGE', 'Select Tamil or English');
    if (cursor) uuid(cursor);
    // Scan only a bounded, stable identity slice. Presence is Redis TTL state, not a DB heartbeat write.
    const { rows } = await this.db.pool.query(`SELECT u.id,u.display_name,u.languages,
      EXISTS(SELECT 1 FROM active_participant_claims a WHERE a.user_id=u.id) busy,
      EXISTS(SELECT 1 FROM favorites f WHERE f.actor_id=$1 AND f.target_id=u.id) favorite
      FROM users u WHERE u.id<>$1 AND u.listener_approved AND u.adult_confirmed AND NOT u.suspended
      AND u.mode='listener' AND u.desired_online AND $2=ANY(u.languages)
      AND ($3::uuid IS NULL OR u.id>$3) AND NOT EXISTS(SELECT 1 FROM blocks b WHERE
        (b.actor_id=$1 AND b.target_id=u.id) OR (b.target_id=$1 AND b.actor_id=u.id)) ORDER BY u.id LIMIT 21`, [actorId,language,cursor??null]);
    const slice = rows.slice(0,20); const online = new Set(await this.presence.online(slice.map(r=>r.id)));
    return { items: slice.filter(r=>online.has(r.id)).map(r=>({id:r.id,displayName:r.display_name,languages:r.languages,
      online:true,available:!r.busy,busy:r.busy,favorite:r.favorite,testOnly:true,rate:TEST_RATE})), nextCursor: rows.length>20 ? slice.at(-1)!.id : null };
  }
  private async row(c: Query, actorId: string, id: string, lock=false): Promise<Row> {
    uuid(id);
    const { rows } = await c.query(`SELECT * FROM call_sessions WHERE id=$1 AND (customer_id=$2 OR listener_id=$2) ${lock?'FOR UPDATE':''}`, [id,actorId]);
    requireThat(rows.length,404,'CALL_NOT_FOUND','Call not found'); return rows[0];
  }
  private async view(c: Query, r: Row) {
    const names=await c.query('SELECT id,display_name FROM users WHERE id=ANY($1::uuid[])',[[r.customer_id,r.listener_id]]);
    return { id:r.id,customerId:r.customer_id,listenerId:r.listener_id,
      customerName:names.rows.find(u=>u.id===r.customer_id)?.display_name,
      listenerName:names.rows.find(u=>u.id===r.listener_id)?.display_name,state:r.state,version:r.version,
      createdAt:iso(r.created_at),expiresAt:iso(r.expires_at),acceptedAt:iso(r.accepted_at),endedAt:iso(r.ended_at),reason:r.reason,
      connectedMs:Number(r.connected_ms),chargeMicrocredits:Number(r.charge_microcredits),earningPaise:Number(r.earning_paise),
      rate:r.rate_snapshot,maxDurationSeconds:r.max_duration_seconds,testOnly:true };
  }
  async call(actorId: string,id: string) { return this.view(this.db.pool,await this.row(this.db.pool,actorId,id)); }
  async history(actorId: string,cursor?: string) {
    let anchor: Row|undefined;
    if(cursor) anchor=await this.row(this.db.pool,actorId,cursor);
    const {rows}=await this.db.pool.query(`SELECT * FROM call_sessions WHERE (customer_id=$1 OR listener_id=$1)
      AND ($2::timestamptz IS NULL OR (created_at,id)<($2::timestamptz,$3::uuid)) ORDER BY created_at DESC,id DESC LIMIT 21`,
      [actorId,anchor?.created_at??null,anchor?.id??null]);
    const selected=rows.slice(0,20);
    return { items:await Promise.all(selected.map(r=>this.view(this.db.pool,r))),nextCursor:rows.length>20?selected.at(-1)!.id:null };
  }
  private async idempotent<T>(actor: Actor,operation: string,key: unknown,body: unknown,fn:(c:PoolClient)=>Promise<T>):Promise<T> {
    const safeKey=string(key,'Idempotency-Key',128);
    const fingerprint=createHash('sha256').update(JSON.stringify(body)).digest('hex');
    try {
      return await this.db.tx(async c=>{
        await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`${actor.id}:${operation}:${safeKey}`]);
        const old=await c.query('SELECT fingerprint,response FROM idempotency_keys WHERE actor_id=$1 AND operation=$2 AND key=$3',[actor.id,operation,safeKey]);
        if(old.rowCount){ requireThat(old.rows[0].fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different request'); return old.rows[0].response as T; }
        const result=await fn(c);
        await c.query('INSERT INTO idempotency_keys(actor_id,operation,key,fingerprint,response) VALUES($1,$2,$3,$4,$5)',[actor.id,operation,safeKey,fingerprint,JSON.stringify(result)]);
        return result;
      });
    }catch(error){ if((error as {code?:string}).code==='23505')throw new ApiError(409,'LISTENER_BUSY','A participant is already in a call'); throw error; }
  }
  private async event(c: Query,r: Row,kind: string) {
    // Hold until transaction commit: no later committed event can overtake a
    // previously allocated sequence and become permanently invisible to a cursor.
    await c.query('SELECT pg_advisory_xact_lock(981277)');
    const id=randomUUID(); const payload=await this.view(c,r);
    await c.query('INSERT INTO call_events(id,call_id,version,kind,payload,created_at) VALUES($1,$2,$3,$4,$5,$6)',[id,r.id,r.version,kind,payload,new Date(this.clock())]);
    for(const recipient of [r.customer_id,r.listener_id])await c.query('INSERT INTO outbox_events(id,event_id,recipient_id) VALUES($1,$2,$3)',[randomUUID(),id,recipient]);
  }
  async createCall(actor: Actor,raw: unknown,key: unknown) {
    const body=object(raw);fields(body,['listenerId','quoteId']); const listenerId=uuid(body.listenerId);
    requireThat(actor.id!==listenerId,400,'SELF_CALL','You cannot call yourself');
    requireThat(body.quoteId===TEST_RATE.id,409,'QUOTE_EXPIRED','Refresh the test rate before calling');
    return this.idempotent(actor,'create-call',key,body,async c=>{
      const users=await c.query('SELECT * FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[[actor.id,listenerId]]);
      const customer=users.rows.find(u=>u.id===actor.id),listener=users.rows.find(u=>u.id===listenerId);
      requireThat(customer?.mode==='customer'&&!customer.suspended&&customer.adult_confirmed,403,'CUSTOMER_MODE_REQUIRED','Switch to Customer mode');
      requireThat(listener?.listener_approved&&listener.adult_confirmed&&!listener.suspended&&listener.mode==='listener'&&listener.desired_online&&await this.presence.isOnline(listenerId),409,'LISTENER_OFFLINE','Listener is unavailable');
      requireThat(customer.languages.some((language:string)=>listener.languages.includes(language)),409,'LANGUAGE_MISMATCH','Choose a listener who speaks one of your conversation languages');
      const blocked=await c.query('SELECT 1 FROM blocks WHERE (actor_id=$1 AND target_id=$2) OR (actor_id=$2 AND target_id=$1)',[actor.id,listenerId]);
      requireThat(!blocked.rowCount,403,'PAIR_BLOCKED','This listener is unavailable');
      const busy=await c.query('SELECT 1 FROM active_participant_claims WHERE user_id=ANY($1::uuid[])',[[actor.id,listenerId]]);
      requireThat(!busy.rowCount,409,'LISTENER_BUSY','A participant is already in a call');
      const balance=await this.wallet(actor.id,c);
      const maxDuration=Math.min(600,Math.floor(balance.availableMicrocredits/MICRO));
      requireThat(maxDuration>=60,409,'INSUFFICIENT_BALANCE','At least 60 test credits are required');
      const now=this.clock(),id=randomUUID();
      const {rows}=await c.query(`INSERT INTO call_sessions(id,customer_id,listener_id,state,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at)
        VALUES($1,$2,$3,'ringing',$4,$5,$6,$7,$8) RETURNING *`,[id,actor.id,listenerId,TEST_RATE.id,TEST_RATE,maxDuration,new Date(now),new Date(now+30_000)]);
      await c.query('INSERT INTO active_participant_claims(user_id,call_id) VALUES($1,$3),($2,$3)',[actor.id,listenerId,id]);
      await c.query('INSERT INTO call_participants(call_id,user_id,rtc_uid) VALUES($1,$2,1),($1,$3,2)',[id,actor.id,listenerId]);
      await c.query('INSERT INTO spend_holds(call_id,user_id,amount) VALUES($1,$2,$3)',[id,actor.id,maxDuration*MICRO]);
      await this.event(c,rows[0],'call.invited');return this.view(c,rows[0]);
    });
  }
  private async persist(c: Query,r: Row) {
    await c.query(`UPDATE call_sessions SET state=$2,version=$3,accepted_at=$4,ended_at=$5,reason=$6,
      connected_ms=$7,connected_since=$8,reconnect_since=$9,charge_microcredits=$10,earning_paise=$11,
      customer_ready=$12,listener_ready=$13,customer_media_at=$14,listener_media_at=$15 WHERE id=$1`,
      [r.id,r.state,r.version,r.accepted_at,r.ended_at,r.reason,r.connected_ms,r.connected_since,r.reconnect_since,
        r.charge_microcredits,r.earning_paise,r.customer_ready,r.listener_ready,r.customer_media_at,r.listener_media_at]);
  }
  private accrue(r: Row) {
    if(r.connected_since){
      // Only count intervals confirmed by BOTH clients. A lost heartbeat never bills its unseen tail.
      const through=Math.min(dateMs(r.customer_media_at),dateMs(r.listener_media_at));
      const delta=Math.max(0,through-dateMs(r.connected_since));
      r.connected_ms=Math.min(Number(r.connected_ms)+delta,r.max_duration_seconds*1000);
      r.connected_since=new Date(Math.max(through,dateMs(r.connected_since)));
    }
    r.charge_microcredits=Math.min(testCharge(Number(r.connected_ms)),r.max_duration_seconds*MICRO);
    r.earning_paise=testEarning(Number(r.connected_ms));
  }
  private async finish(c: Query,r: Row,reason: string,now:number) {
    if(r.state==='ended')return;
    this.accrue(r);r.state='ended';r.reason=reason;r.ended_at=new Date(now);r.connected_since=null;r.version++;
    r.customer_ready=false;r.listener_ready=false;
    await this.persist(c,r);
    const charge=Number(r.charge_microcredits),earnings=Number(r.earning_paise);
    if(charge){
      const batch=`call:${r.id}:credits`;
      await c.query("INSERT INTO journal_batches(id,call_id,kind) VALUES($1,$2,'test_call_settlement')",[batch,r.id]);
      await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,$3),($1,$4,$5)',[batch,`customer:${r.customer_id}`,-charge,'platform:test',charge]);
    }
    if(earnings){
      const batch=`call:${r.id}:earnings`;
      await c.query("INSERT INTO journal_batches(id,call_id,kind) VALUES($1,$2,'test_earning_illustration')",[batch,r.id]);
      await c.query('INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,$3),($1,$4,$5)',[batch,`listener:${r.listener_id}`,earnings,'subsidy:test',-earnings]);
    }
    await c.query('UPDATE spend_holds SET released_at=$2 WHERE call_id=$1',[r.id,new Date(now)]);
    await c.query('DELETE FROM active_participant_claims WHERE call_id=$1',[r.id]);
    await this.event(c,r,'call.state_changed');
  }
  private async advance(c: Query,r: Row,now:number) {
    if(r.state==='ended')return;
    if(r.state==='ringing') { if(now>=dateMs(r.expires_at))await this.finish(c,r,'timeout',now);return; }
    this.accrue(r);
    if(Number(r.connected_ms)>=r.max_duration_seconds*1000){await this.finish(c,r,'test_credit_limit',now);return;}
    let changed=false;
    for(const role of ['customer','listener']) if(r[`${role}_ready`]&&now-dateMs(r[`${role}_media_at`])>5000){r[`${role}_ready`]=false;changed=true;}
    if(changed){r.connected_since=null;r.reconnect_since??=new Date(now);if(r.state!=='reconnecting'){r.state='reconnecting';r.version++;await this.event(c,r,'call.state_changed');}}
    const waitingSince=dateMs(r.reconnect_since)||dateMs(r.accepted_at);
    if((!r.customer_ready||!r.listener_ready)&&now-waitingSince>=45_000){await this.finish(c,r,'connection_timeout',now);return;}
    // Absolute bound also terminates perpetual reconnect attempts and unmetered sessions.
    if(now-dateMs(r.accepted_at)>=(r.max_duration_seconds+120)*1000){await this.finish(c,r,'session_limit',now);return;}
    await this.persist(c,r);
  }
  async action(actor: Actor,id:string,action:string,raw:unknown,key:unknown) {
    const body=object(raw);fields(body,['expectedVersion']);
    requireThat(Number.isSafeInteger(body.expectedVersion),400,'VERSION_REQUIRED','Expected call version is required');
    requireThat(['accept','decline','cancel','end'].includes(action),404,'NOT_FOUND','Unknown action');
    return this.idempotent(actor,`call:${id}:${action}`,key,body,async c=>{
      const r=await this.row(c,actor.id,id,true);await this.advance(c,r,this.clock());
      if(r.state==='ended') {
        requireThat(action!=='accept',409,'CALL_ALREADY_ENDED','The invitation has ended');
        return this.view(c,r);
      }
      requireThat(r.version===body.expectedVersion,409,'STALE_VERSION','Refresh the call and try again');
      if(action==='accept'||action==='decline')requireThat(actor.id===r.listener_id&&r.state==='ringing',409,'INVALID_TRANSITION','Only the invited listener may respond');
      if(action==='cancel')requireThat(actor.id===r.customer_id&&r.state==='ringing',409,'INVALID_TRANSITION','Only the caller may cancel an invitation');
      if(action==='accept'){
        r.state='connecting';r.accepted_at=new Date(this.clock());r.version++;
        await this.persist(c,r);await this.event(c,r,'call.state_changed');
      }else await this.finish(c,r,action==='decline'?'declined':action==='cancel'?'cancelled':'participant_ended',this.clock());
      return this.view(c,r);
    });
  }
  async media(actor:Actor,id:string,raw:unknown) {
    const body=object(raw);fields(body,['ready']);requireThat(typeof body.ready==='boolean',400,'INVALID_FIELD','ready must be a boolean');
    return this.db.tx(async c=>{
      const r=await this.row(c,actor.id,id,true);const now=this.clock();await this.advance(c,r,now);
      requireThat(r.state!=='ringing',409,'INVALID_TRANSITION','Accept before joining media');
      if(r.state==='ended')return this.view(c,r);
      const role=actor.id===r.customer_id?'customer':'listener';
      r[`${role}_ready`]=body.ready;r[`${role}_media_at`]=new Date(now);
      this.accrue(r);
      if(r.customer_ready&&r.listener_ready){
        if(!r.connected_since)r.connected_since=new Date(now);
        r.reconnect_since=null;
        if(r.state!=='connected'){r.state='connected';r.version++;await this.event(c,r,'call.state_changed');}
      }else{
        r.connected_since=null;r.reconnect_since??=new Date(now);
        if(r.state==='connected'){r.state='reconnecting';r.version++;await this.event(c,r,'call.state_changed');}
      }
      if(Number(r.connected_ms)>=r.max_duration_seconds*1000)await this.finish(c,r,'test_credit_limit',now);else await this.persist(c,r);
      return this.view(c,r);
    });
  }
  async rtcToken(actor:Actor,id:string) {
    return this.db.tx(async c=>{
      const r=await this.row(c,actor.id,id,true);await this.advance(c,r,this.clock());
      requireThat(['connecting','connected','reconnecting'].includes(r.state),409,'CALL_NOT_ACTIVE','This call cannot join media');
      const eligible=await c.query('SELECT id,listener_approved,adult_confirmed,suspended FROM users WHERE id=ANY($1::uuid[])',[[r.customer_id,r.listener_id]]);
      requireThat(eligible.rows.length===2&&eligible.rows.every(u=>u.adult_confirmed&&!u.suspended)&&eligible.rows.find(u=>u.id===r.listener_id)?.listener_approved,403,'CALL_NOT_ELIGIBLE','This call is no longer eligible for media');
      const blocked=await c.query('SELECT 1 FROM blocks WHERE (actor_id=$1 AND target_id=$2) OR (actor_id=$2 AND target_id=$1)',[r.customer_id,r.listener_id]);
      const hold=await c.query('SELECT amount FROM spend_holds WHERE call_id=$1 AND released_at IS NULL',[r.id]);
      requireThat(!blocked.rowCount&&hold.rowCount&&Number(hold.rows[0].amount)>=Number(r.charge_microcredits),403,'CALL_NOT_AUTHORIZED','Media authorization has ended');
      const appId=this.config.agoraAppId,certificate=this.config.agoraAppCertificate;
      requireThat(appId&&certificate&&/^[a-f\d]{32}$/i.test(appId)&&/^[a-f\d]{32}$/i.test(certificate),503,'RTC_UNAVAILABLE','Configure an Agora test project on the backend before calling');
      // AccessToken2 expiration uses relative seconds, not an absolute epoch.
      // Provider-side immediate cutoff is a paid-launch gate; this is bounded test media.
      const duration=Math.max(1,Math.min(120,Math.ceil(r.max_duration_seconds-Number(r.connected_ms)/1000)));
      const { RtcTokenBuilder, RtcRole } = require('agora-token') as {RtcTokenBuilder:{buildTokenWithUid:(...args:unknown[])=>string},RtcRole:{PUBLISHER:number}};
      const uid=actor.id===r.customer_id?1:2,channel=`ns_${r.id.replaceAll('-','')}`;
      const token=RtcTokenBuilder.buildTokenWithUid(appId,certificate,channel,uid,RtcRole.PUBLISHER,duration,duration);
      requireThat(token,503,'RTC_UNAVAILABLE','Media authorization could not be generated');
      return { appId,channel,uid,remoteUid:uid===1?2:1,token,expiresAt:new Date(this.clock()+duration*1000).toISOString() };
    });
  }
  async recover() {
    await this.db.tx(async c=>{
      const {rows}=await c.query("SELECT * FROM call_sessions WHERE state<>'ended' ORDER BY id FOR UPDATE SKIP LOCKED");
      for(const r of rows)await this.advance(c,r,this.clock());
    });
  }
  async logoutCall(actor:Actor) {
    await this.db.tx(async c=>{
      const {rows}=await c.query("SELECT * FROM call_sessions WHERE (customer_id=$1 OR listener_id=$1) AND state<>'ended' FOR UPDATE",[actor.id]);
      for(const r of rows)await this.finish(c,r,'signed_out',this.clock());
    });
  }
  async block(actor:Actor,target:string) {
    uuid(target);requireThat(target!==actor.id,400,'SELF_BLOCK','Cannot block yourself');
    await this.db.tx(async c=>{
      await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[[actor.id,target]]);
      const {rows}=await c.query("SELECT * FROM call_sessions WHERE ((customer_id=$1 AND listener_id=$2) OR (customer_id=$2 AND listener_id=$1)) AND state<>'ended' FOR UPDATE",[actor.id,target]);
      await c.query('INSERT INTO blocks(actor_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[actor.id,target]);
      for(const r of rows)await this.finish(c,r,'blocked',this.clock());
    });return {blocked:true};
  }
  async favorite(actor:Actor,target:string,enabled:boolean) {
    uuid(target);requireThat(target!==actor.id,400,'INVALID_TARGET','Choose another listener');
    const {rows}=await this.db.pool.query('SELECT id FROM users WHERE id=$1 AND listener_approved AND NOT suspended',[target]);
    requireThat(rows.length,404,'NOT_FOUND','Listener not found');
    if(enabled){
      const blocked=await this.db.pool.query('SELECT 1 FROM blocks WHERE (actor_id=$1 AND target_id=$2) OR (actor_id=$2 AND target_id=$1)',[actor.id,target]);
      requireThat(!blocked.rowCount,403,'PAIR_BLOCKED','This listener is unavailable');
    }
    if(enabled)await this.db.pool.query('INSERT INTO favorites(actor_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[actor.id,target]);
    else await this.db.pool.query('DELETE FROM favorites WHERE actor_id=$1 AND target_id=$2',[actor.id,target]);
    return {favorite:enabled};
  }
  async report(actor:Actor,raw:unknown,key:unknown) {
    const body=object(raw);fields(body,['callId','reason']);const id=uuid(body.callId),reason=string(body.reason,'reason',1000);
    return this.idempotent(actor,'report',key,body,async c=>{
      await this.row(c,actor.id,id);const reportId=randomUUID();
      await c.query('INSERT INTO reports(id,actor_id,call_id,reason) VALUES($1,$2,$3,$4)',[reportId,actor.id,id,reason]);
      return {id:reportId,status:'open'};
    });
  }
  async earnings(actor:Actor) {
    const user=await this.user(actor.id);requireThat(user.listenerApproved,403,'LISTENER_NOT_APPROVED','Listener approval required');
    const {rows}=await this.db.pool.query('SELECT coalesce(sum(amount),0)::text total FROM journal_lines WHERE account_id=$1',[`listener:${actor.id}`]);
    return {illustrativePaise:Number(rows[0].total),availablePaise:0,paidPaise:0,testOnly:true,listenerPaisePerHour:50000};
  }
  async events(actor:Actor,cursor?:string) {
    if(cursor){
      uuid(cursor);
      const owned=await this.db.pool.query('SELECT 1 FROM call_events e JOIN call_sessions c ON c.id=e.call_id WHERE e.id=$1 AND (c.customer_id=$2 OR c.listener_id=$2)',[cursor,actor.id]);
      requireThat(owned.rowCount,404,'EVENT_NOT_FOUND','Event cursor not found');
    }
    const {rows}=await this.db.pool.query(`SELECT e.* FROM call_events e JOIN call_sessions c ON c.id=e.call_id
      WHERE (c.customer_id=$1 OR c.listener_id=$1) AND ($2::uuid IS NULL OR e.sequence>(SELECT sequence FROM call_events WHERE id=$2))
      ORDER BY e.sequence LIMIT 100`,[actor.id,cursor??null]);
    return {items:rows.map(e=>({id:e.id,type:e.kind,entityId:e.call_id,version:e.version,timestamp:iso(e.created_at),data:e.payload})),nextCursor:rows.at(-1)?.id??cursor??null};
  }
}
