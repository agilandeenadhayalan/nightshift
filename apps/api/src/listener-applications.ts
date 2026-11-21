import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { lstat, mkdir, readFile, readdir, realpath, rename, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { PoolClient } from 'pg';
import { Actor } from './auth';
import { Database } from './db';
import { ApiError, fields, object, requireThat, string, uuid } from './errors';

const MAX_BYTES=2*1024*1024, CONSENT='listener-review-v1';
const hash=(value:string|Buffer)=>createHash('sha256').update(value).digest('hex');
const iso=(value:unknown)=>value?new Date(value as string).toISOString():null;
type Row=Record<string,any>;
const absent=(error:unknown)=>typeof error==='object' && error!==null && 'code' in error && error.code==='ENOENT';

/** Private development storage. No configured root or caller-provided filenames are exposed over HTTP. */
export class LocalReviewStorage {
  private readonly base:string;
  constructor(directory:string){
    requireThat(path.isAbsolute(directory),503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
    this.base=path.resolve(directory);
  }
  private async root(){
    await mkdir(this.base,{recursive:true,mode:0o700});
    const info=await lstat(this.base), actual=await realpath(this.base);
    requireThat(info.isDirectory() && !info.isSymbolicLink() && path.resolve(actual)===this.base,
      503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
    return actual;
  }
  private async file(id:string){
    uuid(id);const root=await this.root(),file=path.resolve(root,`${id}.wav`);
    requireThat(path.dirname(file)===root,503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
    return file;
  }
  async write(id:string,bytes:Buffer){
    requireThat(bytes.length<=MAX_BYTES,400,'INVALID_UPLOAD','Review sample is too large.');
    const file=await this.file(id);
    try{
      const existing=await lstat(file);
      requireThat(existing.isFile() && !existing.isSymbolicLink(),503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
      requireThat(existing.size===bytes.length && hash(await readFile(file))===hash(bytes),503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
      return;
    }catch(error){if(!absent(error))throw error;}
    const temporary=`${file}.part-${randomUUID()}`;
    try{await writeFile(temporary,bytes,{flag:'wx',mode:0o600});await rename(temporary,file);}
    finally{await unlink(temporary).catch(error=>{if(!absent(error))throw error;});}
  }
  async read(id:string){
    const file=await this.file(id);
    try{
      const info=await lstat(file);
      requireThat(info.isFile() && !info.isSymbolicLink() && info.size<=MAX_BYTES,503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
      return await readFile(file);
    }catch(error){if(absent(error))throw new ApiError(404,'UPLOAD_NOT_FOUND','Review sample is unavailable.');throw error;}
  }
  async remove(id:string){
    const file=await this.file(id),root=path.dirname(file);
    // Unlink never follows a symlink. No recursive user-controlled deletion.
    await unlink(file).catch(error=>{if(!absent(error))throw error;});
    for(const name of await readdir(root)){
      if(name.startsWith(`${id}.wav.part-`) && /^[0-9a-f-]+$/.test(name.slice(`${id}.wav.part-`.length))){
        const temporary=path.resolve(root,name);
        requireThat(path.dirname(temporary)===root,503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
        await unlink(temporary).catch(error=>{if(!absent(error))throw error;});
      }
    }
  }
}

/** Validate actual PCM WAV structure and duration, not an extension or declared MIME alone. */
export function validateReviewWave(bytes:Buffer){
  const valid=(condition:unknown)=>requireThat(condition,400,'INVALID_WAV','Use a PCM WAV voice review sample lasting 2–60 seconds.');
  valid(bytes.length>=44 && bytes.length<=MAX_BYTES);
  valid(bytes.toString('latin1',0,4)==='RIFF' && bytes.toString('latin1',8,12)==='WAVE' && bytes.readUInt32LE(4)+8===bytes.length);
  let offset=12,format=false,dataBytes=0,byteRate=0,blockAlign=0,dataChunks=0;
  while(offset+8<=bytes.length){
    const tag=bytes.toString('latin1',offset,offset+4),length=bytes.readUInt32LE(offset+4),start=offset+8,end=start+length;
    valid(end<=bytes.length);
    if(tag==='fmt '){
      valid(!format && length===16);format=true;
      const encoding=bytes.readUInt16LE(start),channels=bytes.readUInt16LE(start+2),rate=bytes.readUInt32LE(start+4),bits=bytes.readUInt16LE(start+14);
      byteRate=bytes.readUInt32LE(start+8);blockAlign=bytes.readUInt16LE(start+12);
      valid(encoding===1 && [1,2].includes(channels) && rate>=8000 && rate<=48000 && bits===16
        && blockAlign===channels*2 && byteRate===rate*blockAlign);
    }else if(tag==='data'){valid(format);dataChunks++;dataBytes=length;}
    else valid(false); // No embedded metadata, scripts, pictures or unreviewed chunks.
    offset=end+(length%2);
  }
  valid(offset===bytes.length && format && dataChunks===1 && dataBytes>0 && dataBytes%blockAlign===0
    && dataBytes/byteRate>=2 && dataBytes/byteRate<=60);
}

export interface ListenerApplicationView {
  id:string;state:'draft'|'submitted'|'needs_information'|'approved'|'rejected'|'withdrawn';
  bio:string;topics:string[];languages:string[];voiceSampleConsent:boolean;consentVersion:string|null;
  voiceSampleUploadId:string|null;submittedAt:string|null;decidedAt:string|null;updatedAt:string;
}

export class ListenerApplications {
  constructor(private readonly db:Database,private readonly options:{storage?:LocalReviewStorage;capabilityKey:string},private readonly clock:()=>number=Date.now){
    requireThat(options.capabilityKey.length>=24,503,'REVIEW_UPLOAD_UNAVAILABLE','Private review storage is unavailable.');
  }
  private storage(){requireThat(this.options.storage,503,'REVIEW_UPLOAD_UNAVAILABLE','Private review uploads are unavailable.');return this.options.storage;}
  private async owner(c:PoolClient,actor:Actor){
    const {rows}=await c.query('SELECT suspended,adult_confirmed,listener_approved FROM users WHERE id=$1 FOR NO KEY UPDATE',[actor.id]);
    requireThat(rows.length && !rows[0].suspended,401,'UNAUTHENTICATED','Sign in again.');
    const session=await c.query('SELECT 1 FROM auth_sessions WHERE user_id=$1 AND token_hash=$2 AND revoked_at IS NULL AND expires_at>$3',[actor.id,actor.sessionHash,new Date(this.clock())]);
    requireThat(session.rows.length,401,'UNAUTHENTICATED','Sign in again.');
    requireThat(rows[0].adult_confirmed,403,'ADULT_ONLY','Listener applications are for adults aged 18 and over.');
    return rows[0];
  }
  private async row(c:PoolClient,actor:Actor,id:string){
    uuid(id);const {rows}=await c.query('SELECT * FROM listener_applications WHERE id=$1 AND user_id=$2 FOR UPDATE',[id,actor.id]);
    requireThat(rows.length,404,'APPLICATION_NOT_FOUND','Application not found.');return rows[0];
  }
  private view(row:Row):ListenerApplicationView{return {id:row.id,state:row.state,bio:row.bio,topics:row.topics,languages:row.languages,
    voiceSampleConsent:row.voice_sample_consent,consentVersion:row.consent_version,voiceSampleUploadId:row.voice_sample_upload_id,
    submittedAt:iso(row.submitted_at),decidedAt:iso(row.decided_at),updatedAt:iso(row.updated_at)!};}
  private editable(row:Row){requireThat(['draft','needs_information'].includes(row.state),409,'APPLICATION_NOT_EDITABLE','This application cannot be edited now.');}
  private input(raw:unknown){
    const body=object(raw);fields(body,['bio','topics','languages','voiceSampleConsent','consentVersion']);
    requireThat(typeof body.bio==='string' && [...body.bio].length<=1000 && !/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(body.bio),400,'INVALID_APPLICATION','Use a bio of at most 1,000 characters.');
    const allowed=['everyday','work','study','hobbies','language-practice'];
    requireThat(Array.isArray(body.topics) && body.topics.length<=5 && new Set(body.topics).size===body.topics.length && body.topics.every(x=>typeof x==='string' && allowed.includes(x)),400,'INVALID_APPLICATION','Choose supported conversation topics.');
    requireThat(Array.isArray(body.languages) && body.languages.length>=1 && body.languages.length<=2 && new Set(body.languages).size===body.languages.length && body.languages.every(x=>['ta','en'].includes(x)),400,'INVALID_LANGUAGE','Choose Tamil or English.');
    requireThat(typeof body.voiceSampleConsent==='boolean' && body.consentVersion===CONSENT,400,'REVIEW_CONSENT_REQUIRED','Review the current voice-sample consent notice.');
    return {bio:body.bio.trim(),topics:body.topics as string[],languages:body.languages as string[],voiceSampleConsent:body.voiceSampleConsent,consentVersion:CONSENT};
  }
  private async consent(c:PoolClient,actor:Actor,id:string,granted:boolean){
    await c.query('INSERT INTO listener_application_consents(id,application_id,user_id,notice_version,granted) VALUES($1,$2,$3,$4,$5)',[randomUUID(),id,actor.id,CONSENT,granted]);
    await c.query("INSERT INTO consents(id,user_id,purpose,notice_version,granted) VALUES($1,$2,'listener-review-material',$3,$4)",[randomUUID(),actor.id,CONSENT,granted]);
  }
  private async idempotent(c:PoolClient,actor:Actor,operation:string,key:unknown,body:unknown,fn:()=>Promise<ListenerApplicationView>){
    const requestKey=string(key,'Idempotency-Key',128),fingerprint=hash(JSON.stringify(body));
    const prior=await c.query('SELECT fingerprint,response FROM idempotency_keys WHERE actor_id=$1 AND operation=$2 AND key=$3',[actor.id,operation,requestKey]);
    if(prior.rows.length){requireThat(prior.rows[0].fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different request.');return prior.rows[0].response as ListenerApplicationView;}
    const result=await fn();
    await c.query('INSERT INTO idempotency_keys(actor_id,operation,key,fingerprint,response) VALUES($1,$2,$3,$4,$5)',[actor.id,operation,requestKey,fingerprint,result]);return result;
  }
  async get(actor:Actor){return this.db.tx(async c=>{await this.owner(c,actor);const {rows}=await c.query('SELECT * FROM listener_applications WHERE user_id=$1 ORDER BY created_at DESC,id DESC LIMIT 1',[actor.id]);return {application:rows[0]?this.view(rows[0]):null};});}
  async create(actor:Actor,raw:unknown,key:unknown){
    const input=this.input(raw);
    return this.db.tx(async c=>{
      const owner=await this.owner(c,actor);requireThat(!owner.listener_approved,409,'LISTENER_ALREADY_APPROVED','Your Listener access is already approved.');
      return this.idempotent(c,actor,'listener.application.create',key,input,async()=>{
        // A durable approval may still be waiting for its entitlement worker.
        // It must not open a second application during that commit/projection gap.
        const active=await c.query("SELECT id FROM listener_applications WHERE user_id=$1 AND state IN ('draft','submitted','needs_information','approved')",[actor.id]);
        requireThat(!active.rows.length,409,'APPLICATION_EXISTS','Continue your existing application.');
        const id=randomUUID(),{rows}=await c.query(`INSERT INTO listener_applications(id,user_id,bio,topics,languages,voice_sample_consent,consent_version)
          VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`,[id,actor.id,input.bio,input.topics,input.languages,input.voiceSampleConsent,CONSENT]);
        await this.consent(c,actor,id,input.voiceSampleConsent);return this.view(rows[0]);
      });
    });
  }
  private async scrubRows(c:PoolClient,appId:string){
    const {rows}=await c.query('SELECT id FROM listener_review_uploads WHERE application_id=$1 AND purged_at IS NULL',[appId]);
    await c.query('UPDATE listener_applications SET voice_sample_upload_id=NULL WHERE id=$1',[appId]);
    await c.query(`UPDATE listener_review_uploads SET state='deleted',token_hash=NULL,request_key_digest=NULL,request_fingerprint=NULL,
      content_type=NULL,byte_length=NULL,sha256=NULL,stored_at=NULL WHERE application_id=$1`,[appId]);
    return rows.map(row=>row.id as string);
  }
  private async removeFiles(ids:string[]){
    if(ids.length){const storage=this.storage();for(const id of ids){
      await storage.remove(id);
      await this.db.pool.query("UPDATE listener_review_uploads SET purged_at=$2 WHERE id=$1 AND state='deleted'",[id,new Date(this.clock())]);
    }}
  }
  private async deletedIds(id:string){return (await this.db.pool.query("SELECT id FROM listener_review_uploads WHERE application_id=$1 AND state='deleted' AND purged_at IS NULL",[id])).rows.map(row=>row.id as string);}
  async update(actor:Actor,id:string,raw:unknown){
    const input=this.input(raw);let remove:string[]=[];
    const result=await this.db.tx(async c=>{
      await this.owner(c,actor);const row=await this.row(c,actor,id);this.editable(row);
      if(!input.voiceSampleConsent)remove=await this.scrubRows(c,id);
      if(input.voiceSampleConsent!==row.voice_sample_consent)await this.consent(c,actor,id,input.voiceSampleConsent);
      const {rows}=await c.query(`UPDATE listener_applications SET bio=$2,topics=$3,languages=$4,voice_sample_consent=$5,consent_version=$6
        WHERE id=$1 RETURNING *`,[id,input.bio,input.topics,input.languages,input.voiceSampleConsent,CONSENT]);return this.view(rows[0]);
    });await this.removeFiles([...new Set([...remove,...await this.deletedIds(id)])]);return result;
  }
  private capability(row:Row){return createHmac('sha256',this.options.capabilityKey).update(JSON.stringify([row.id,row.user_id,row.application_id,iso(row.expires_at)])).digest('base64url');}
  async issueUpload(actor:Actor,id:string,raw:unknown,key:unknown){
    this.storage();const body=object(raw);fields(body,['contentType','byteLength','sha256']);
    requireThat(body.contentType==='audio/wav' && typeof body.byteLength==='number' && Number.isInteger(body.byteLength) && body.byteLength>=44 && body.byteLength<=MAX_BYTES && typeof body.sha256==='string' && /^[a-f0-9]{64}$/.test(body.sha256),400,'INVALID_UPLOAD','Use a WAV review sample of at most 2 MiB.');
    const requestKey=hash(string(key,'Idempotency-Key',128)),fingerprint=hash(JSON.stringify([body.contentType,body.byteLength,body.sha256]));
    return this.db.tx(async c=>{
      await this.owner(c,actor);const app=await this.row(c,actor,id);this.editable(app);requireThat(app.voice_sample_consent,403,'REVIEW_CONSENT_REQUIRED','Consent is required for a private review sample.');
      const prior=await c.query('SELECT * FROM listener_review_uploads WHERE application_id=$1 AND request_key_digest=$2',[id,requestKey]);
      let row=prior.rows[0];
      if(row)requireThat(row.request_fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','Use a new key for a different upload.');
      else{
        const limits=await c.query(`SELECT count(*) FILTER(WHERE created_at>$2) hour_count,
          count(*) FILTER(WHERE state='pending' AND expires_at>$3) active_count FROM listener_review_uploads WHERE user_id=$1`,[actor.id,new Date(this.clock()-3600000),new Date(this.clock())]);
        requireThat(Number(limits.rows[0].hour_count)<20 && Number(limits.rows[0].active_count)<3,429,'UPLOAD_LIMIT','Wait before requesting another review upload.');
        row={id:randomUUID(),user_id:actor.id,application_id:id,expires_at:new Date(this.clock()+300000)};
        const token=this.capability(row);
        await c.query(`INSERT INTO listener_review_uploads(id,application_id,user_id,token_hash,request_key_digest,request_fingerprint,content_type,byte_length,sha256,expires_at,created_at)
          VALUES($1,$2,$3,$4,$5,$6,'audio/wav',$7,$8,$9,$10)`,[row.id,id,actor.id,hash(token),requestKey,fingerprint,body.byteLength,body.sha256,row.expires_at,new Date(this.clock())]);
      }
      requireThat(new Date(row.expires_at).getTime()>this.clock(),410,'UPLOAD_EXPIRED','Request a new upload capability.');
      return {uploadId:row.id as string,uploadToken:this.capability(row),expiresAt:iso(row.expires_at)!,maxBytes:MAX_BYTES,contentType:'audio/wav'};
    });
  }
  async upload(actor:Actor,id:string,uploadId:string,token:unknown,contentType:unknown,bytes:Buffer){
    const storage=this.storage();uuid(uploadId);let remove:string[]=[],invalidWave:ApiError|undefined;
    const result=await this.db.tx(async c=>{
      await this.owner(c,actor);const app=await this.row(c,actor,id);this.editable(app);
      requireThat(app.voice_sample_consent,403,'REVIEW_CONSENT_REQUIRED','Consent is required for a private review sample.');
      const {rows}=await c.query("SELECT * FROM listener_review_uploads WHERE id=$1 AND application_id=$2 AND user_id=$3 AND state<>'deleted' FOR UPDATE",[uploadId,id,actor.id]);
      requireThat(rows.length,404,'UPLOAD_NOT_FOUND','Review sample is unavailable.');const row=rows[0];
      requireThat(typeof token==='string' && token.length<=256 && timingSafeEqual(Buffer.from(hash(token)),Buffer.from(row.token_hash)),403,'UPLOAD_CAPABILITY_INVALID','Upload capability is invalid.');
      requireThat(new Date(row.expires_at).getTime()>this.clock(),410,'UPLOAD_EXPIRED','Request a new upload capability.');
      requireThat(contentType==='audio/wav' && Buffer.isBuffer(bytes) && bytes.length<=MAX_BYTES,400,'INVALID_UPLOAD','Use a WAV review sample of at most 2 MiB.');
      requireThat(bytes.length===row.byte_length,400,'UPLOAD_LENGTH_MISMATCH','Upload was incomplete. Retry the complete sample.');
      requireThat(hash(bytes)===row.sha256,400,'UPLOAD_DIGEST_MISMATCH','The sample differs from the upload request.');
      try{validateReviewWave(bytes);}catch(error){
        if(!(error instanceof ApiError))throw error;
        // Correct descriptor but unusable content cannot become a valid retry.
        // Commit capability revocation before returning the validation failure.
        invalidWave=error;
        await c.query(`UPDATE listener_review_uploads SET state='deleted',token_hash=NULL,request_key_digest=NULL,request_fingerprint=NULL,
          content_type=NULL,byte_length=NULL,sha256=NULL,stored_at=NULL WHERE id=$1`,[uploadId]);
        return this.view(app);
      }
      if(row.state==='ready')return this.view(app);
      // The owner/application lock spans the bounded disk write. Deletion or
      // consent withdrawal cannot commit and then be undone by this upload.
      await storage.write(uploadId,bytes);
      await c.query("UPDATE listener_review_uploads SET state='ready',stored_at=$2 WHERE id=$1",[uploadId,new Date(this.clock())]);
      if(app.voice_sample_upload_id && app.voice_sample_upload_id!==uploadId){
        remove=[app.voice_sample_upload_id];
        await c.query(`UPDATE listener_review_uploads SET state='deleted',token_hash=NULL,request_key_digest=NULL,request_fingerprint=NULL,
          content_type=NULL,byte_length=NULL,sha256=NULL,stored_at=NULL WHERE id=$1`,[app.voice_sample_upload_id]);
      }
      const updated=await c.query('UPDATE listener_applications SET voice_sample_upload_id=$2 WHERE id=$1 RETURNING *',[id,uploadId]);return this.view(updated.rows[0]);
    });await this.removeFiles([...new Set([...remove,...await this.deletedIds(id)])]);if(invalidWave)throw invalidWave;return result;
  }
  async readUpload(actor:Actor,id:string,uploadId:string){
    const storage=this.storage();uuid(uploadId);
    return this.db.tx(async c=>{
      await this.owner(c,actor);const app=await this.row(c,actor,id);
      const {rows}=await c.query("SELECT sha256,byte_length FROM listener_review_uploads WHERE id=$1 AND application_id=$2 AND user_id=$3 AND state='ready'",[uploadId,id,actor.id]);
      requireThat(app.voice_sample_consent && app.voice_sample_upload_id===uploadId && rows.length,404,'UPLOAD_NOT_FOUND','Review sample is unavailable.');
      const bytes=await storage.read(uploadId);
      requireThat(bytes.length===rows[0].byte_length && hash(bytes)===rows[0].sha256,503,'REVIEW_UPLOAD_UNAVAILABLE','Review sample is unavailable.');
      return {bytes,contentType:'audio/wav' as const};
    });
  }
  async submit(actor:Actor,id:string,key:unknown){return this.db.tx(async c=>{
    await this.owner(c,actor);const app=await this.row(c,actor,id);
    return this.idempotent(c,actor,'listener.application.submit',key,{id},async()=>{
      if(app.state==='submitted')return this.view(app);this.editable(app);
      const sample=await c.query("SELECT id,sha256,byte_length FROM listener_review_uploads WHERE id=$1 AND application_id=$2 AND user_id=$3 AND state='ready'",[app.voice_sample_upload_id,id,actor.id]);
      requireThat(app.bio.trim().length>0 && app.topics.length>0 && app.languages.length>0 && app.voice_sample_consent && app.consent_version===CONSENT && sample.rows.length,409,'APPLICATION_INCOMPLETE','Add a bio, topics and a consented private review sample.');
      const bytes=await this.storage().read(sample.rows[0].id);
      requireThat(bytes.length===sample.rows[0].byte_length && hash(bytes)===sample.rows[0].sha256,503,'REVIEW_UPLOAD_UNAVAILABLE','Review sample is unavailable.');
      const {rows}=await c.query("UPDATE listener_applications SET state='submitted',submitted_at=COALESCE(submitted_at,now()) WHERE id=$1 RETURNING *",[id]);return this.view(rows[0]);
    });
  });}
  async withdraw(actor:Actor,id:string,key:unknown){
    let remove:string[]=[];const result=await this.db.tx(async c=>{
      await this.owner(c,actor);const app=await this.row(c,actor,id);
      return this.idempotent(c,actor,'listener.application.withdraw',key,{id},async()=>{
        if(app.state==='withdrawn')return this.view(app);
        remove=await this.scrubRows(c,id);if(app.voice_sample_consent)await this.consent(c,actor,id,false);
        // Material consent remains revocable after a decision; retain that outcome.
        const {rows}=await c.query("UPDATE listener_applications SET state=CASE WHEN state IN ('approved','rejected') THEN state ELSE 'withdrawn' END,voice_sample_consent=false WHERE id=$1 RETURNING *",[id]);return this.view(rows[0]);
      });
    });await this.removeFiles([...new Set([...remove,...await this.deletedIds(id)])]);return result;
  }
  /** Internal deletion worker only; never routed with a caller-supplied owner. */
  async erasePrivateMaterials(userId:string){
    uuid(userId);const ids=await this.db.tx(async c=>{
      await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[userId]);
      const applications=await c.query('SELECT id FROM listener_applications WHERE user_id=$1',[userId]);let remove:string[]=[];
      for(const app of applications.rows){remove.push(...await this.scrubRows(c,app.id));}
      await c.query("UPDATE listener_applications SET bio='',topics='{}',languages='{}',voice_sample_consent=false,consent_version=NULL WHERE user_id=$1",[userId]);
      await c.query("DELETE FROM idempotency_keys WHERE actor_id=$1 AND operation LIKE 'listener.application.%'",[userId]);return remove;
    });await this.removeFiles(ids);
  }
  /** Internal bounded recovery; no customer mutation is required to erase abandoned uploads. */
  async sweepExpiredUploads(limit=100){
    requireThat(Number.isSafeInteger(limit) && limit>=1 && limit<=100,400,'INVALID_LIMIT','Use a cleanup limit from 1 to 100.');
    // Claim only upload rows in this short statement and release them before
    // acquiring owners. Rotating attempts keep failed/busy rows from starving
    // later cleanup; another worker may safely repeat a tombstone unlink.
    const candidates=await this.db.pool.query(`WITH candidates AS (
      SELECT id FROM listener_review_uploads
      WHERE (state='deleted' AND purged_at IS NULL) OR (state='pending' AND expires_at<=$1)
      ORDER BY cleanup_attempted_at NULLS FIRST,created_at,id LIMIT $2 FOR UPDATE SKIP LOCKED
    ) UPDATE listener_review_uploads u SET cleanup_attempted_at=clock_timestamp()
      FROM candidates c WHERE u.id=c.id RETURNING u.id,u.user_id`,[new Date(this.clock()),limit]);
    let purged=0,failed=0;
    for(const row of candidates.rows){
      try{
        const cleanup=await this.db.tx(async c=>{
          // Match owner-first upload/deletion locking. Busy owners retry next tick.
          const owner=await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE SKIP LOCKED',[row.user_id]);
          if(!owner.rows.length)return false;
          const updated=await c.query(`UPDATE listener_review_uploads SET state='deleted',token_hash=NULL,request_key_digest=NULL,
            request_fingerprint=NULL,content_type=NULL,byte_length=NULL,sha256=NULL,stored_at=NULL
            WHERE id=$1 AND ((state='deleted' AND purged_at IS NULL) OR (state='pending' AND expires_at<=$2)) RETURNING id`,[row.id,new Date(this.clock())]);
          return updated.rows.length>0;
        });
        if(cleanup){await this.removeFiles([row.id]);purged++;}
      }catch{failed++;} // Durable tombstone retries without leaking private file paths.
    }
    return {purged,failed};
  }
}
