import { createHash,createHmac,randomUUID,timingSafeEqual } from 'node:crypto';
import { PoolClient } from 'pg';
import { Database } from '../db';
import { ApiError,fields,object,requireThat,uuid } from '../errors';
import { validateReviewWave } from '../listener-applications';
import { StaffActor,StaffAuthority } from './authority';

const MAX_BYTES=2097152,PAGE=20,TTL=300000;
type Row=Record<string,any>;
type Cursor={v:1;owner:string;language:'ta'|'en'|null;cutoff:string;afterTime:string;afterId:string;expires:number};
const hex=/^[a-f0-9]{64}$/;
const hash=(value:string|Buffer)=>createHash('sha256').update(value).digest('hex');
const timestamp=(value:unknown)=>new Date(value as string).toISOString();
const sortTime=`to_char(a.submitted_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')`;
const changeTime=`to_char(a.updated_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')`;
const missing=()=>new ApiError(404,'REVIEW_NOT_AVAILABLE','This submitted review material is unavailable.');
export interface StaffReviewOptions {cursorKey:string;storage?:{read(id:string):Promise<Buffer>};readTimeoutMs?:number;maxConcurrentReads?:number;decisionsEnabled?:()=>boolean;}

/** Submitted evidence only. This service has no decision/entitlement methods. */
export class StaffReviewQueries {
  private inFlight=0;
  private readonly timeout:number;private readonly capacity:number;
  constructor(private readonly db:Database,private readonly authority:StaffAuthority,private readonly options:StaffReviewOptions,
    private readonly clock:()=>number=Date.now){
    this.timeout=options.readTimeoutMs??5000;this.capacity=options.maxConcurrentReads??4;
    requireThat(options.cursorKey.length>=32&&options.cursorKey.length<=256&&Number.isSafeInteger(this.timeout)&&this.timeout>=1&&this.timeout<=5000
      &&Number.isSafeInteger(this.capacity)&&this.capacity>=1&&this.capacity<=8,503,'REVIEW_UNAVAILABLE','Review access is unavailable.');
  }
  private mac(value:string){return createHmac('sha256',this.options.cursorKey).update(`staff-review:${value}`).digest('hex');}
  private owner(actor:StaffActor){return this.mac(JSON.stringify([actor.staffId,actor.sessionId,actor.sessionHash]));}
  private cursor(actor:StaffActor,language:Cursor['language'],value:unknown):Cursor|undefined{
    if(value===undefined)return;
    const invalid=()=>new ApiError(400,'INVALID_REVIEW_CURSOR','Refresh the submitted review queue.');
    if(typeof value!=='string'||value.length>2048||!/^[A-Za-z0-9_-]+\.[a-f0-9]{64}$/.test(value))throw invalid();
    const [payload,signature]=value.split('.');
    if(!timingSafeEqual(Buffer.from(this.mac(payload!),'hex'),Buffer.from(signature!,'hex')))throw invalid();
    let c:Cursor;try{c=JSON.parse(Buffer.from(payload!,'base64url').toString('utf8'));}catch{throw invalid();}
    const iso=(s:unknown)=>typeof s==='string'&&/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z$/.test(s)
      &&Number.isFinite(Date.parse(s))&&new Date(s).toISOString()===`${s.slice(0,23)}Z`;
    if(!c||c.v!==1||c.owner!==this.owner(actor)||c.language!==language||!iso(c.cutoff)||!iso(c.afterTime)
      ||!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(c.afterId)
      ||!Number.isSafeInteger(c.expires)||c.expires>this.clock()+TTL||c.afterTime>c.cutoff)throw invalid();
    requireThat(c.expires>this.clock(),410,'REVIEW_CURSOR_EXPIRED','Refresh the submitted review queue.');return c;
  }
  private encode(c:Cursor){const payload=Buffer.from(JSON.stringify(c)).toString('base64url');return `${payload}.${this.mac(payload)}`;}
  private alias(row:Row){const name=row.display_name;
    return typeof name==='string'&&name.length>=1&&name.length<=80&&/^[\p{L}\p{M}\p{N} ._-]+$/u.test(name)&&/[\p{L}]/u.test(name)&&!/[\p{N}]{6}/u.test(name)
      ?name:`Applicant ${String(row.id).slice(0,8)}`;
  }
  private sample(row:Row){return row.voice_sample_consent===true&&row.consent_version==='listener-review-v1'
    &&row.voice_sample_upload_id&&row.upload_state==='ready'&&hex.test(row.sha256??'')&&Number.isInteger(row.byte_length)
    &&row.byte_length>=44&&row.byte_length<=MAX_BYTES;}
  private version(row:Row){return hash(JSON.stringify([row.id,row.state,row.bio,row.topics,row.languages,row.sort_time,row.change_time,
    row.voice_sample_consent,row.consent_version,row.voice_sample_upload_id,row.upload_state,row.sha256,row.byte_length]));}
  private async audit(c:PoolClient,actor:StaffActor,row:Row,action:string,version:string|null){
    await c.query('INSERT INTO staff_review_access_events(id,principal_id,session_id,application_id,action,material_version,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)',
      [randomUUID(),actor.staffId,actor.sessionId,row.id,action,version,new Date(this.clock())]);
  }
  private async authorize(c:PoolClient,actor:StaffActor,owners:string[],evidence=false){
    const view=await this.authority.authorize(c,actor,'listener.review.read',owners);
    requireThat(!evidence||view.permissions.includes('listener.review.evidence.read'),403,'STAFF_FORBIDDEN','Staff evidence permission is required.');
    // Same complete set was already locked by the real app-bound authority.
    // Also maintain applicant ordering in isolated provider-only fixture harnesses.
    await c.query('SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE',[[...new Set(owners)].sort()]);
    return new Set<string>((await c.query(`SELECT linked_user_id user_id FROM staff_principals WHERE id=$1
      UNION SELECT user_id FROM staff_review_conflicts WHERE principal_id=$1`,[actor.staffId])).rows.map(r=>r.user_id).filter(Boolean));
  }
  private async material(c:PoolClient,id:string,self:Set<string>){
    const app=(await c.query(`SELECT a.*,${sortTime} sort_time,${changeTime} change_time,u.display_name,u.adult_confirmed,u.suspended FROM listener_applications a
      JOIN users u ON u.id=a.user_id WHERE a.id=$1 FOR SHARE OF a`,[id])).rows[0];
    if(!app||self.has(app.user_id)||app.state!=='submitted'||app.suspended||!app.adult_confirmed)throw missing();
    const upload=app.voice_sample_upload_id?(await c.query(`SELECT state upload_state,sha256,byte_length FROM listener_review_uploads
      WHERE id=$1 AND application_id=$2 AND user_id=$3 FOR SHARE`,[app.voice_sample_upload_id,id,app.user_id])).rows[0]:undefined;
    return {...app,...upload};
  }
  async queue(actor:StaffActor,raw:unknown={}){
    const query=object(raw);fields(query,['language','cursor']);
    requireThat(query.language===undefined||query.language==='ta'||query.language==='en',400,'INVALID_FIELD','Choose Tamil or English.');
    const language=(query.language??null) as Cursor['language'],cursor=this.cursor(actor,language,query.cursor);
    const cutoff=cursor?.cutoff??(await this.db.pool.query(`SELECT to_char(clock_timestamp() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') value`)).rows[0].value as string;
    // Only routing IDs and exact position/revision keys before locking; nothing from this pre-read is
    // returned until permission and all candidate owners have been rechecked.
    const candidates=(await this.db.pool.query(`SELECT a.id,a.user_id,${sortTime} sort_time,${changeTime} change_time FROM listener_applications a
      JOIN users u ON u.id=a.user_id WHERE a.state='submitted' AND NOT u.suspended AND u.adult_confirmed
      AND a.user_id IS DISTINCT FROM (SELECT linked_user_id FROM staff_principals WHERE id=$1)
      AND NOT EXISTS(SELECT 1 FROM staff_review_conflicts f WHERE f.principal_id=$1 AND f.user_id=a.user_id)
      AND ($2::text IS NULL OR $2=ANY(a.languages)) AND a.submitted_at<=$3 AND a.updated_at<=$3
      AND ($4::timestamptz IS NULL OR (a.submitted_at,a.id)>($4,$5::uuid)) ORDER BY a.submitted_at,a.id LIMIT 21`,
      [actor.staffId,language,cutoff,cursor?.afterTime??null,cursor?.afterId??null])).rows;
    const slice=candidates.slice(0,PAGE);
    return this.db.tx(async c=>{
      const self=await this.authorize(c,actor,slice.map(r=>r.user_id));const items=[];
      for(const candidate of slice){
        let row:Row;try{row=await this.material(c,candidate.id,self);}catch(error){if(error instanceof ApiError&&error.code==='REVIEW_NOT_AVAILABLE')continue;throw error;}
        // A withdrawal/resubmission may change the ordered position while the
        // pre-read waits for its owner lock. Do not admit that new position.
        if(row.sort_time!==candidate.sort_time||row.change_time!==candidate.change_time||row.sort_time>cutoff||row.change_time>cutoff
          ||(cursor&&(row.sort_time<cursor.afterTime||row.sort_time===cursor.afterTime&&row.id<=cursor.afterId))
          ||language&&!row.languages.includes(language))continue;
        items.push({id:row.id,alias:this.alias(row),state:'submitted' as const,languages:row.languages as string[],submittedAt:timestamp(row.submitted_at),voiceSampleAvailable:!!this.sample(row)});
        await this.audit(c,actor,row,'queue.read',null);
      }
      const last=slice.at(-1),nextCursor=candidates.length>PAGE&&last?this.encode({v:1,owner:this.owner(actor),language,cutoff,
        afterTime:last.sort_time,afterId:last.id,expires:cursor?.expires??this.clock()+TTL}):null;
      return {items,nextCursor,decisionsEnabled:this.options.decisionsEnabled?.()??false};
    });
  }
  private async snapshot(actor:StaffActor,id:string,evidence:boolean,audit:boolean){
    uuid(id);const owner=(await this.db.pool.query('SELECT user_id FROM listener_applications WHERE id=$1',[id])).rows[0]?.user_id;
    return this.db.tx(async c=>{
      const self=await this.authorize(c,actor,owner?[owner]:[],evidence);
      const row=await this.material(c,id,self),version=this.version(row);
      if(audit)await this.audit(c,actor,row,'detail.read',version);
      return {row,version};
    });
  }
  async detail(actor:StaffActor,id:string){
    const {row,version}=await this.snapshot(actor,id,true,true);
    return {application:{id:row.id,alias:this.alias(row),state:'submitted' as const,bio:row.bio as string,topics:row.topics as string[],languages:row.languages as string[],
      submittedAt:timestamp(row.submitted_at),materialVersion:version,adultStatus:'self_declared' as const,
      voiceSample:this.sample(row)?{contentType:'audio/wav' as const,byteLength:row.byte_length as number}:null},decisionsEnabled:this.options.decisionsEnabled?.()??false};
  }
  /** Internal decision boundary: caller already holds staff and every owner lock. */
  async lockedMaterial(c:PoolClient,id:string){const row=await this.material(c,id,new Set());return {row,version:this.version(row),sampleAvailable:!!this.sample(row)};}
  private async read(id:string){
    requireThat(this.options.storage,503,'REVIEW_SAMPLE_UNAVAILABLE','Private review sample storage is unavailable.');
    requireThat(this.inFlight<this.capacity,503,'REVIEW_SAMPLE_BUSY','Wait before reading another review sample.');
    this.inFlight++;let settled=false,finished=false,released=false;
    const release=()=>{finished=true;if(settled&&!released){released=true;this.inFlight--;}};
    const pending=Promise.resolve().then(()=>this.options.storage!.read(id));
    const settle=()=>{settled=true;if(finished)release();};void pending.then(settle,settle);
    let timer:ReturnType<typeof setTimeout>|undefined;
    try{const bytes=await Promise.race([pending,new Promise<never>((_,reject)=>{timer=setTimeout(()=>reject(new Error('read deadline')),this.timeout);})]);return {bytes,release};}
    catch(error){release();if(error instanceof ApiError&&error.status===404)throw missing();throw new ApiError(503,'REVIEW_SAMPLE_UNAVAILABLE','Private review sample storage is unavailable.');}
    finally{if(timer)clearTimeout(timer);}
  }
  async sampleBytes(actor:StaffActor,id:string,expected:unknown){
    requireThat(typeof expected==='string'&&hex.test(expected),400,'INVALID_FIELD','Use the current review material version.');
    const initial=await this.snapshot(actor,id,true,false);
    if(!this.sample(initial.row))throw missing();
    requireThat(initial.version===expected,409,'REVIEW_MATERIAL_CHANGED','Reload the application before reading its sample.');
    const read=await this.read(initial.row.voice_sample_upload_id),bytes=read.bytes;
    try{
      requireThat(bytes.length>=44&&bytes.length<=MAX_BYTES,503,'REVIEW_SAMPLE_UNAVAILABLE','Private review sample storage is unavailable.');
      await this.authority.revalidate(actor);
      // Storage I/O holds no authority/user/application lock. Final locked
      // checks catch withdrawal, deletion, edits and revocation during that I/O.
      // The bounded read slot also covers retained bytes during revalidation.
      return await this.db.tx(async c=>{
        const self=await this.authorize(c,actor,[initial.row.user_id],true),row=await this.material(c,id,self),version=this.version(row);
        if(!this.sample(row))throw missing();
        requireThat(version===expected,409,'REVIEW_MATERIAL_CHANGED','Reload the application before reading its sample.');
        requireThat(bytes.length===row.byte_length&&hash(bytes)===row.sha256,503,'REVIEW_SAMPLE_UNAVAILABLE','Private review sample storage is unavailable.');
        try{validateReviewWave(bytes);}catch{throw new ApiError(503,'REVIEW_SAMPLE_UNAVAILABLE','Private review sample storage is unavailable.');}
        await this.audit(c,actor,row,'sample.read',version);
        return {bytes,contentType:'audio/wav' as const,materialVersion:version};
      });
    }finally{read.release();}
  }
}
