import { randomUUID, createHash } from 'node:crypto';
import { PoolClient } from 'pg';
import { Database } from './db';
import { Presence } from './presence';
import { Actor } from './auth';
import { Config } from './config';
import { ApiError, requireThat, fields, object, string, uuid } from './errors';
import { MICRO, TEST_RATE, TEST_VIDEO_RATE, testCharge, testEarning } from '@nightshift/backend-domain';
import { Directory } from './directory';
import { MATCHING_LIMITS,MatchingCoordinator,assertNoActiveMatching } from './matching';
import {PushService} from './push';
import {PushTransport} from './push-transport';

type Row = Record<string, any>;
type Query = Pick<PoolClient, 'query'>;
const dateMs = (value: unknown) => value ? new Date(value as string).getTime() : 0;
const iso = (value: unknown) => value ? new Date(value as string).toISOString() : null;
export class NightShiftService {
  readonly directory:Directory;
  readonly matching:MatchingCoordinator;
  readonly push:PushService;
  constructor(readonly db: Database, readonly presence: Presence, readonly config: Config,
    private readonly clock: () => number = Date.now,dependencies:{pushTransport?:PushTransport}={}) {
    this.push=new PushService(db,presence,config,clock,dependencies.pushTransport);
    this.directory=new Directory(db,presence,()=>this.videoAvailable(),clock,(c,actor)=>this.liveOwner(c,actor),(c,ids)=>this.push.reachable(c,ids));
    this.matching=new MatchingCoordinator(db,presence,{
      authorize:(c,actor)=>this.liveOwner(c,actor),
      reserve:async(c,actor,listenerId,quoteId,expiresAt,requestId,language)=>{
        await this.liveOwner(c,actor);
        const users=(await c.query('SELECT * FROM users WHERE id=ANY($1::uuid[])',[[actor.id,listenerId]])).rows;
        return this.reserveCall(c,actor,{listenerId,quoteId,mediaType:'audio'},users,{expiresAt,requestId,language});
      },advance:(c,call,now)=>this.advance(c,call,now),finish:(c,call,reason,now)=>this.finish(c,call,reason,now),
      reachable:async ids=>new Set((await this.push.reachable(this.db.pool,ids)).keys())
    },clock);
  }

  private videoAvailable() {
    return this.config.videoCallsEnabled === true
      && /^[a-f\d]{32}$/i.test(this.config.agoraAppId ?? '')
      && /^[a-f\d]{32}$/i.test(this.config.agoraAppCertificate ?? '');
  }
  rtcConfig() {
    const videoEnabled = this.videoAvailable();
    return {appId: videoEnabled ? this.config.agoraAppId! : null, videoEnabled, testOnly: true};
  }
  rates() { return {items: this.videoAvailable() ? [TEST_RATE, TEST_VIDEO_RATE] : [TEST_RATE]}; }

  /** Revalidate after taking the same owner lock used by login and revocation.
   * An HTTP guard can have completed before a queued account mutation. */
  private async liveOwner(c: PoolClient, actor: Actor, requireAdult = true) {
    const { rows } = await c.query('SELECT * FROM users WHERE id=$1 FOR NO KEY UPDATE', [actor.id]);
    requireThat(rows.length && !rows[0].suspended, 401, 'UNAUTHENTICATED', 'Sign in again');
    const session = await c.query(`SELECT s.expires_at FROM auth_sessions s LEFT JOIN devices d ON d.id=s.device_record_id
      WHERE s.user_id=$1 AND s.token_hash=$2 AND s.revoked_at IS NULL AND s.expires_at>$3
      AND (s.auth_kind='development' OR (d.active AND d.revoked_at IS NULL AND d.last_token_hash=s.token_hash))`,
    [actor.id, actor.sessionHash, new Date(this.clock())]);
    requireThat(session.rows.length, 401, 'UNAUTHENTICATED', 'Sign in again');
    requireThat(!requireAdult || rows[0].adult_confirmed, 403, 'ONBOARDING_REQUIRED', 'Complete adult onboarding first.');
    return {...rows[0],session_expires_at:session.rows[0].expires_at};
  }

  /** A Redis value alone never establishes reachability. A stale writer after
   * cache loss must match the durable intent and a current authorized session. */
  private async reachable(ids: string[], c: Query = this.db.pool): Promise<Set<string>> {
    if (!ids.length) return new Set();
    const { rows } = await c.query(`SELECT u.id,u.presence_version FROM users u
      WHERE u.id=ANY($1::uuid[]) AND u.desired_online AND u.listener_approved AND u.adult_confirmed
      AND NOT u.suspended AND u.mode='listener' AND EXISTS (
        SELECT 1 FROM auth_sessions s LEFT JOIN devices d ON d.id=s.device_record_id
        WHERE s.user_id=u.id AND s.revoked_at IS NULL AND s.expires_at>$2
        AND (s.auth_kind='development' OR (d.active AND d.revoked_at IS NULL AND d.last_token_hash=s.token_hash)))`,
    [ids, new Date(this.clock())]);
    return new Set(await this.presence.online(rows.map(row => row.id),
      new Map(rows.map(row => [row.id, String(row.presence_version)]))));
  }

  async withdrawPresence(userId: string) {
    const version = await this.db.tx(async c => {
      const { rows } = await c.query('SELECT * FROM users WHERE id=$1 FOR NO KEY UPDATE', [userId]);
      const user = rows[0];
      // Restriction/deletion recovery may be delayed. Never clear a later
      // eligible availability intent just because an older callback resumed.
      return user && (!user.desired_online || !user.listener_approved || !user.adult_confirmed
        || user.suspended || user.mode !== 'listener') ? String(user.presence_version) : undefined;
    });
    if (version !== undefined) await this.presence.clear(userId, version);
  }

  async user(id: string, c: Query = this.db.pool) {
    const { rows } = await c.query('SELECT * FROM users WHERE id=$1', [id]);
    requireThat(rows.length, 404, 'NOT_FOUND', 'Account not found');
    const u = rows[0];
    return { id: u.id, displayName: u.display_name, languages: u.languages, mode: u.mode,
      listenerApproved: u.listener_approved, online: (await this.reachable([id], c)).has(id) };
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
    const version = await this.db.tx(async c => {
      const user = await this.liveOwner(c, actor);
      return user.desired_online && user.listener_approved && user.mode === 'listener'
        ? String(user.presence_version) : undefined;
    });
    if (version !== undefined) await this.presence.heartbeat(actor.id, version);
    return { serverTime: new Date(this.clock()).toISOString() };
  }
  async mode(actor: Actor, raw: unknown) {
    const body = object(raw); fields(body, ['mode']);
    requireThat(typeof body.mode==='string' && ['customer','listener'].includes(body.mode), 400, 'INVALID_MODE', 'Choose Customer or Listener');
    const version = await this.db.tx(async c => {
      const user = await this.liveOwner(c, actor);
      requireThat(body.mode !== 'listener' || user.listener_approved, 403, 'LISTENER_NOT_APPROVED', 'Listener approval is required');
      await assertNoActiveMatching(c,actor.id);
      const active = await c.query('SELECT 1 FROM active_participant_claims WHERE user_id=$1', [actor.id]);
      requireThat(!active.rowCount, 409, 'CALL_ACTIVE', 'End the call before switching modes');
      const updated = await c.query('UPDATE users SET mode=$2,desired_online=false,presence_version=presence_version+1 WHERE id=$1 RETURNING presence_version', [actor.id,body.mode]);
      return String(updated.rows[0].presence_version);
    });
    await this.presence.clear(actor.id, version);
    return this.user(actor.id);
  }
  async availability(actor: Actor, raw: unknown) {
    const body = object(raw); fields(body, ['online']);
    requireThat(typeof body.online === 'boolean', 400, 'INVALID_FIELD', 'online must be a boolean');
    const version = await this.db.tx(async c => {
      const user = await this.liveOwner(c, actor);
      requireThat(user.listener_approved && user.mode === 'listener', 403, 'LISTENER_NOT_APPROVED', 'Use approved Listener mode');
      const updated = await c.query('UPDATE users SET desired_online=$2,presence_version=presence_version+1 WHERE id=$1 RETURNING presence_version', [actor.id, body.online]);
      return String(updated.rows[0].presence_version);
    });
    if (body.online) await this.presence.heartbeat(actor.id, version); else await this.presence.clear(actor.id, version);
    return this.user(actor.id);
  }
  async languages(actor: Actor, raw: unknown) {
    const body=object(raw); fields(body,['languages']);
    requireThat(Array.isArray(body.languages) && body.languages.length>0 && body.languages.length<=2 && body.languages.every(x=>['ta','en'].includes(x)),400,'INVALID_LANGUAGE','Select Tamil or English');
    await this.db.tx(async c=>{await this.liveOwner(c,actor);await c.query('UPDATE users SET languages=$2 WHERE id=$1',[actor.id,[...new Set(body.languages as string[])]]);});
    return this.user(actor.id);
  }
  async listeners(actorId: string, language = 'ta') {
    // Snapshot compatibility does not allocate/evict the scrolling client's view.
    return this.directory.preview(actorId,language);
  }
  private async row(c: Query, actorId: string, id: string, lock=false): Promise<Row> {
    uuid(id);
    const { rows } = await c.query(`SELECT * FROM call_sessions WHERE id=$1 AND (customer_id=$2 OR listener_id=$2) ${lock?'FOR UPDATE':''}`, [id,actorId]);
    requireThat(rows.length,404,'CALL_NOT_FOUND','Call not found'); return rows[0];
  }
  private async lockParticipants(c: PoolClient, actor: Actor, ids: string[], requireAdult = true): Promise<Row[]> {
    const {rows}=await c.query('SELECT * FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[ids]);
    // Login, logout, blocking and account restriction use these same user locks.
    // Never take the actor lock alone before a pair: opposite participants can
    // issue concurrent requests, and both must acquire users in the same order.
    await this.liveOwner(c,actor,requireAdult);
    return rows;
  }
  private async authorizedCall(c: PoolClient, actor: Actor, id: string, requireAdult = true): Promise<Row> {
    const initial=await this.row(c,actor.id,id);
    await this.lockParticipants(c,actor,[initial.customer_id,initial.listener_id],requireAdult);
    const locked=await this.row(c,actor.id,id,true);
    requireThat(locked.customer_id===initial.customer_id&&locked.listener_id===initial.listener_id,
      409,'CALL_CHANGED','Refresh the call and try again');
    return locked;
  }
  /** Call users are already locked by authorizedCall. Unlike discovery, an
   * existing invitation/call does not require online intent or Listener mode. */
  private async eligibleCall(c: PoolClient, r: Row) {
    const eligible=await c.query('SELECT id,listener_approved,adult_confirmed,suspended FROM users WHERE id=ANY($1::uuid[])',[[r.customer_id,r.listener_id]]);
    requireThat(eligible.rows.length===2&&eligible.rows.every(u=>u.adult_confirmed&&!u.suspended)&&eligible.rows.find(u=>u.id===r.listener_id)?.listener_approved,
      403,'CALL_NOT_ELIGIBLE','This call is no longer eligible for media');
    const blocked=await c.query('SELECT 1 FROM blocks WHERE (actor_id=$1 AND target_id=$2) OR (actor_id=$2 AND target_id=$1)',[r.customer_id,r.listener_id]);
    const hold=await c.query('SELECT amount FROM spend_holds WHERE call_id=$1 AND released_at IS NULL',[r.id]);
    requireThat(!blocked.rowCount&&hold.rowCount&&Number(hold.rows[0].amount)>=Number(r.charge_microcredits),
      403,'CALL_NOT_AUTHORIZED','Media authorization has ended');
    const matching=(await c.query(`SELECT m.language FROM matching_attempts a JOIN matching_requests m ON m.id=a.request_id WHERE a.call_id=$1`,[r.id])).rows[0];
    if(matching){const shared=await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) AND $2=ANY(languages)',[[r.customer_id,r.listener_id],matching.language]);
      requireThat(shared.rows.length===2,403,'CALL_NOT_ELIGIBLE','The selected conversation language is no longer available.');}
  }
  private async view(c: Query, r: Row) {
    const names=await c.query('SELECT id,display_name FROM users WHERE id=ANY($1::uuid[])',[[r.customer_id,r.listener_id]]);
    return { id:r.id,customerId:r.customer_id,listenerId:r.listener_id,mediaType:r.media_type??'audio',
      customerName:names.rows.find(u=>u.id===r.customer_id)?.display_name,
      listenerName:names.rows.find(u=>u.id===r.listener_id)?.display_name,state:r.state,version:r.version,
      createdAt:iso(r.created_at),expiresAt:iso(r.expires_at),acceptedAt:iso(r.accepted_at),endedAt:iso(r.ended_at),reason:r.reason,
      connectedMs:Number(r.connected_ms),chargeMicrocredits:Number(r.charge_microcredits),earningPaise:Number(r.earning_paise),
      // The frozen 60..600-second development allowance includes free time.
      // Later wallet changes do not alter which limit admitted this call.
      rate:r.rate_snapshot,maxDurationSeconds:r.max_duration_seconds,
      durationLimitReason:r.max_duration_seconds<600?'test_credit_balance':'test_duration_cap',testOnly:true };
  }
  async call(actorId: string,id: string) { return this.view(this.db.pool,await this.row(this.db.pool,actorId,id)); }
  async history(actorId: string,cursor?: string) {
    let anchor: Row|undefined;
    if(cursor) anchor=await this.row(this.db.pool,actorId,cursor);
    // Keep the stored tuple in PostgreSQL: a JS Date would truncate microseconds.
    const {rows}=await this.db.pool.query(`SELECT * FROM call_sessions WHERE (customer_id=$1 OR listener_id=$1)
      AND ($2::uuid IS NULL OR (created_at,id)<(SELECT anchor.created_at,anchor.id FROM call_sessions anchor
        WHERE anchor.id=$2::uuid AND (anchor.customer_id=$1 OR anchor.listener_id=$1)))
      ORDER BY created_at DESC,id DESC LIMIT 21`,[actorId,anchor?.id??null]);
    const selected=rows.slice(0,20);
    return { items:await Promise.all(selected.map(r=>this.view(this.db.pool,r))),nextCursor:rows.length>20?selected.at(-1)!.id:null };
  }
  private async idempotent<T,A>(actor: Actor,operation: string,key: unknown,body: unknown,
    authorize:(c:PoolClient)=>Promise<A>,fn:(c:PoolClient,authorization:A)=>Promise<T>):Promise<T> {
    const safeKey=string(key,'Idempotency-Key',128);
    const fingerprint=createHash('sha256').update(JSON.stringify(body)).digest('hex');
    try {
      return await this.db.tx(async c=>{
        // Cached responses are private results too. Authorization acquires the
        // operation's user/call locks before the key lock and remains valid
        // through either the cache return or the mutation's commit.
        const authorization=await authorize(c);
        await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`${actor.id}:${operation}:${safeKey}`]);
        const old=await c.query('SELECT fingerprint,response FROM idempotency_keys WHERE actor_id=$1 AND operation=$2 AND key=$3',[actor.id,operation,safeKey]);
        if(old.rowCount){ requireThat(old.rows[0].fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different request'); return old.rows[0].response as T; }
        const result=await fn(c,authorization);
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
    await this.push.enqueue(c,id,r);
  }
  async createCall(actor: Actor,raw: unknown,key: unknown) {
    const body=object(raw);fields(body,['listenerId','quoteId','mediaType','videoConsent']); const listenerId=uuid(body.listenerId);
    const mediaType=body.mediaType===undefined?'audio':body.mediaType;
    requireThat(mediaType==='audio'||mediaType==='video',400,'INVALID_MEDIA_TYPE','Choose audio or video');
    requireThat(body.videoConsent===undefined||typeof body.videoConsent==='boolean',400,'INVALID_FIELD','videoConsent must be a boolean');
    const rate=mediaType==='video'?TEST_VIDEO_RATE:TEST_RATE;
    requireThat(actor.id!==listenerId,400,'SELF_CALL','You cannot call yourself');
    requireThat(body.quoteId===rate.id,409,'QUOTE_EXPIRED','Refresh the test rate before calling');
    return this.idempotent(actor,'create-call',key,body,
      c=>this.lockParticipants(c,actor,[actor.id,listenerId]),async(c,users)=>{
      const row=await this.reserveCall(c,actor,body,users);return this.view(c,row);
    });
  }
  /** Internal reservation primitive: callers hold the complete sorted user
   * set. Matching attaches its attempt and request in this same transaction. */
  private async reserveCall(c:PoolClient,actor:Actor,body:Row,users:Row[],matching?:{expiresAt:number;requestId:string;language:string}){
      const listenerId=body.listenerId as string,mediaType=body.mediaType??'audio';
      const rate=mediaType==='video'?TEST_VIDEO_RATE:TEST_RATE;
      requireThat(body.quoteId===rate.id,409,'QUOTE_EXPIRED','Refresh the test rate before calling');
      if(mediaType==='video'){
        requireThat(this.videoAvailable(),503,'VIDEO_UNAVAILABLE','Private test video is not available');
        requireThat(body.videoConsent===true,400,'VIDEO_CONSENT_REQUIRED','Review the camera preview and consent before starting video');
      }
      const customer=users.find(u=>u.id===actor.id),listener=users.find(u=>u.id===listenerId);
      requireThat(customer?.mode==='customer'&&!customer.suspended&&customer.adult_confirmed,403,'CUSTOMER_MODE_REQUIRED','Switch to Customer mode');
      await assertNoActiveMatching(c,actor.id,matching?.requestId);
      const channel=(await this.push.reachable(c,[listenerId])).get(listenerId);
      requireThat(listener?.listener_approved&&listener.adult_confirmed&&!listener.suspended&&listener.mode==='listener'&&listener.desired_online
        &&channel&&(mediaType==='audio'||channel==='foreground'),409,'LISTENER_OFFLINE','Listener is unavailable');
      requireThat(customer.languages.some((language:string)=>listener.languages.includes(language)),409,'LANGUAGE_MISMATCH','Choose a listener who speaks one of your conversation languages');
      requireThat(!matching||customer.languages.includes(matching.language)&&listener.languages.includes(matching.language),409,'LANGUAGE_MISMATCH','The selected language must match both participants.');
      const blocked=await c.query('SELECT 1 FROM blocks WHERE (actor_id=$1 AND target_id=$2) OR (actor_id=$2 AND target_id=$1)',[actor.id,listenerId]);
      requireThat(!blocked.rowCount,403,'PAIR_BLOCKED','This listener is unavailable');
      const busy=await c.query('SELECT 1 FROM active_participant_claims WHERE user_id=ANY($1::uuid[])',[[actor.id,listenerId]]);
      requireThat(!busy.rowCount,409,'LISTENER_BUSY','A participant is already in a call');
      const balance=await this.wallet(actor.id,c);
      const maxDuration=Math.min(600,Math.floor(balance.availableMicrocredits/rate.microcreditsPerSecond));
      requireThat(maxDuration>=60,409,'INSUFFICIENT_BALANCE',`At least ${60*rate.microcreditsPerSecond/MICRO} test credits are required`);
      // User locks serialize revocation, but cannot stop time from advancing
      // while Redis responds. Recheck both sessions after that external wait.
      const currentOwner=await this.liveOwner(c,actor);
      const listenerSession=await c.query(`SELECT s.expires_at FROM auth_sessions s LEFT JOIN devices d ON d.id=s.device_record_id
        WHERE s.user_id=$1 AND s.revoked_at IS NULL AND s.expires_at>$2
        AND (s.auth_kind='development' OR (d.active AND d.revoked_at IS NULL AND d.last_token_hash=s.token_hash))`,
        [listenerId,new Date(this.clock())]);
      requireThat(channel!=='background_eligible'||await this.push.backgroundEligible(c,listenerId),409,'LISTENER_OFFLINE','Listener is unavailable');
      const now=this.clock(),id=randomUUID();
      requireThat(dateMs(currentOwner.session_expires_at)>now,401,'UNAUTHENTICATED','Sign in again');
      requireThat(listenerSession.rows.some(s=>dateMs(s.expires_at)>now),409,'LISTENER_OFFLINE','Listener is unavailable');
      requireThat(!matching||matching.expiresAt-now>=MATCHING_LIMITS.minRingMs,409,'MATCH_DEADLINE','The search wait budget has ended.');
      const {rows}=await c.query(`INSERT INTO call_sessions(id,customer_id,listener_id,state,rate_id,rate_snapshot,max_duration_seconds,created_at,expires_at,media_type,customer_video_consent_at)
        VALUES($1,$2,$3,'ringing',$4,$5,$6,$7,$8,$9,$10) RETURNING *`,[id,actor.id,listenerId,rate.id,rate,maxDuration,new Date(now),new Date(matching?.expiresAt??now+30_000),mediaType,mediaType==='video'?new Date(now):null]);
      await c.query('INSERT INTO active_participant_claims(user_id,call_id) VALUES($1,$3),($2,$3)',[actor.id,listenerId,id]);
      await c.query('INSERT INTO call_participants(call_id,user_id,rtc_uid) VALUES($1,$2,1),($1,$3,2)',[id,actor.id,listenerId]);
      await c.query('INSERT INTO spend_holds(call_id,user_id,amount) VALUES($1,$2,$3)',[id,actor.id,maxDuration*rate.microcreditsPerSecond]);
      await this.event(c,rows[0],'call.invited');return rows[0];
  }
  private async persist(c: Query,r: Row) {
    await c.query(`UPDATE call_sessions SET state=$2,version=$3,accepted_at=$4,ended_at=$5,reason=$6,
      connected_ms=$7,connected_since=$8,reconnect_since=$9,charge_microcredits=$10,earning_paise=$11,
      customer_ready=$12,listener_ready=$13,customer_media_at=$14,listener_media_at=$15,listener_video_consent_at=$16 WHERE id=$1`,
      [r.id,r.state,r.version,r.accepted_at,r.ended_at,r.reason,r.connected_ms,r.connected_since,r.reconnect_since,
        r.charge_microcredits,r.earning_paise,r.customer_ready,r.listener_ready,r.customer_media_at,r.listener_media_at,r.listener_video_consent_at]);
  }
  private accrue(r: Row) {
    if(r.connected_since){
      // Only count intervals confirmed by BOTH clients. A lost heartbeat never bills its unseen tail.
      const through=Math.min(dateMs(r.customer_media_at),dateMs(r.listener_media_at));
      const delta=Math.max(0,through-dateMs(r.connected_since));
      r.connected_ms=Math.min(Number(r.connected_ms)+delta,r.max_duration_seconds*1000);
      r.connected_since=new Date(Math.max(through,dateMs(r.connected_since)));
    }
    r.charge_microcredits=Math.min(testCharge(Number(r.connected_ms),r.rate_snapshot),r.max_duration_seconds*r.rate_snapshot.microcreditsPerSecond);
    r.earning_paise=testEarning(Number(r.connected_ms),r.rate_snapshot);
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
    if(r.media_type==='video'&&!this.videoAvailable()){await this.finish(c,r,'video_unavailable',now);return;}
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
    const body=object(raw);fields(body,action==='accept'?['expectedVersion','videoConsent']:['expectedVersion']);
    requireThat(Number.isSafeInteger(body.expectedVersion),400,'VERSION_REQUIRED','Expected call version is required');
    requireThat(body.videoConsent===undefined||typeof body.videoConsent==='boolean',400,'INVALID_FIELD','videoConsent must be a boolean');
    requireThat(['accept','decline','cancel','end'].includes(action),404,'NOT_FOUND','Unknown action');
    return this.idempotent(actor,`call:${id}:${action}`,key,body,
      c=>this.authorizedCall(c,actor,id,action==='accept'),async(c,r)=>{
      const lockedVersion=r.version;
      await this.advance(c,r,this.clock());
      if(r.state==='ended') {
        requireThat(action!=='accept',409,'CALL_ALREADY_ENDED','The invitation has ended');
        return this.view(c,r);
      }
      // End may itself advance stale media to reconnecting. Validate against
      // the persisted version locked above, not that uncommitted transition.
      requireThat((action==='end'?lockedVersion:r.version)===body.expectedVersion,409,'STALE_VERSION','Refresh the call and try again');
      if(action==='accept'||action==='decline')requireThat(actor.id===r.listener_id&&r.state==='ringing',409,'INVALID_TRANSITION','Only the invited listener may respond');
      if(action==='cancel')requireThat(actor.id===r.customer_id&&r.state==='ringing',409,'INVALID_TRANSITION','Only the caller may cancel an invitation');
      if(action==='accept'){
        await this.eligibleCall(c,r);
        if(r.media_type==='video'){
          requireThat(body.videoConsent===true,400,'VIDEO_CONSENT_REQUIRED','Review the camera preview and consent before accepting video');
          r.listener_video_consent_at=new Date(this.clock());
        }
        r.state='connecting';r.accepted_at=new Date(this.clock());r.version++;
        await this.persist(c,r);await this.event(c,r,'call.state_changed');
      }else await this.finish(c,r,action==='decline'?'declined':action==='cancel'?'cancelled':'participant_ended',this.clock());
      return this.view(c,r);
    });
  }
  async media(actor:Actor,id:string,raw:unknown) {
    const body=object(raw);fields(body,['ready','videoReady']);requireThat(typeof body.ready==='boolean',400,'INVALID_FIELD','ready must be a boolean');
    requireThat(body.videoReady===undefined||typeof body.videoReady==='boolean',400,'INVALID_FIELD','videoReady must be a boolean');
    return this.db.tx(async c=>{
      const r=await this.authorizedCall(c,actor,id);const now=this.clock();await this.advance(c,r,now);
      requireThat(r.state!=='ringing',409,'INVALID_TRANSITION','Accept before joining media');
      if(r.state==='ended')return this.view(c,r);
      await this.eligibleCall(c,r);
      if(r.media_type==='video')requireThat(typeof body.videoReady==='boolean',400,'VIDEO_READINESS_REQUIRED','Video readiness must include camera capture and the remote video');
      const role=actor.id===r.customer_id?'customer':'listener';
      r[`${role}_ready`]=body.ready&&(r.media_type!=='video'||body.videoReady===true);r[`${role}_media_at`]=new Date(now);
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
      const r=await this.authorizedCall(c,actor,id);await this.advance(c,r,this.clock());
      requireThat(['connecting','connected','reconnecting'].includes(r.state),409,'CALL_NOT_ACTIVE','This call cannot join media');
      if(r.media_type==='video')requireThat(r.customer_video_consent_at&&r.listener_video_consent_at,403,'VIDEO_CONSENT_REQUIRED','Both participants must consent before joining video');
      await this.eligibleCall(c,r);
      const appId=this.config.agoraAppId,certificate=this.config.agoraAppCertificate;
      requireThat(appId&&certificate&&/^[a-f\d]{32}$/i.test(appId)&&/^[a-f\d]{32}$/i.test(certificate),503,'RTC_UNAVAILABLE','Configure an Agora test project on the backend before calling');
      // AccessToken2 expiration uses relative seconds, not an absolute epoch.
      // Provider-side immediate cutoff is a paid-launch gate; this is bounded test media.
      const duration=Math.max(1,Math.min(120,Math.ceil(r.max_duration_seconds-Number(r.connected_ms)/1000)));
      const { RtcTokenBuilder, RtcRole } = require('agora-token') as {RtcTokenBuilder:{buildTokenWithUid:(...args:unknown[])=>string},RtcRole:{PUBLISHER:number}};
      const uid=actor.id===r.customer_id?1:2,channel=`ns_${r.id.replaceAll('-','')}`;
      const token=RtcTokenBuilder.buildTokenWithUid(appId,certificate,channel,uid,RtcRole.PUBLISHER,duration,duration);
      requireThat(token,503,'RTC_UNAVAILABLE','Media authorization could not be generated');
      return { appId,channel,uid,remoteUid:uid===1?2:1,token,expiresAt:new Date(this.clock()+duration*1000).toISOString(),mediaType:r.media_type??'audio' };
    });
  }
  async recover() {
    await this.db.tx(async c=>{
      const {rows}=await c.query("SELECT * FROM call_sessions WHERE state<>'ended' ORDER BY id FOR UPDATE SKIP LOCKED");
      for(const r of rows)await this.advance(c,r,this.clock());
    });
  }
  async logoutCall(actor:Actor, transaction?:PoolClient) {
    const end = async (c:PoolClient) => {
      await this.matching.stopOwnerLocked(c,actor.id,'source_session_ended');
      const {rows}=await c.query("SELECT * FROM call_sessions WHERE (customer_id=$1 OR listener_id=$1) AND state<>'ended' FOR UPDATE",[actor.id]);
      for(const r of rows)await this.finish(c,r,'signed_out',this.clock());
    };
    if(transaction) await end(transaction);
    else await this.db.tx(async c=>{await this.liveOwner(c,actor,false);await end(c);});
  }
  async block(actor:Actor,target:string) {
    uuid(target);requireThat(target!==actor.id,400,'SELF_BLOCK','Cannot block yourself');
    await this.db.tx(async c=>{
      await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[[actor.id,target]]);
      await this.liveOwner(c,actor);
      const {rows}=await c.query("SELECT * FROM call_sessions WHERE ((customer_id=$1 AND listener_id=$2) OR (customer_id=$2 AND listener_id=$1)) AND state<>'ended' FOR UPDATE",[actor.id,target]);
      await c.query('INSERT INTO blocks(actor_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[actor.id,target]);
      await c.query('DELETE FROM favorites WHERE (actor_id=$1 AND target_id=$2) OR (actor_id=$2 AND target_id=$1)',[actor.id,target]);
      for(const r of rows)await this.finish(c,r,'blocked',this.clock());
    });return {blocked:true};
  }
  async favorite(actor:Actor,target:string,enabled:boolean) {
    uuid(target);requireThat(target!==actor.id,400,'INVALID_TARGET','Choose another listener');
    await this.db.tx(async c=>{
      const {rows}=await c.query('SELECT * FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[[actor.id,target]]);
      await this.liveOwner(c,actor);
      if(enabled){
        const listener=rows.find(r=>r.id===target);
        requireThat(listener?.listener_approved&&listener.adult_confirmed&&!listener.suspended,404,'NOT_FOUND','Listener not found');
        const blocked=await c.query('SELECT 1 FROM blocks WHERE (actor_id=$1 AND target_id=$2) OR (actor_id=$2 AND target_id=$1)',[actor.id,target]);
        requireThat(!blocked.rowCount,403,'PAIR_BLOCKED','This listener is unavailable');
        await c.query('INSERT INTO favorites(actor_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[actor.id,target]);
      }else await c.query('DELETE FROM favorites WHERE actor_id=$1 AND target_id=$2',[actor.id,target]);
    });
    return {favorite:enabled};
  }
  async report(actor:Actor,raw:unknown,key:unknown) {
    const body=object(raw);fields(body,['callId','reason']);const id=uuid(body.callId),reason=string(body.reason,'reason',1000);
    return this.idempotent(actor,'report',key,body,c=>this.liveOwner(c,actor),async c=>{
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
