import { randomUUID } from 'node:crypto';
import { PoolClient } from 'pg';
import { TEST_RATE, TEST_VIDEO_RATE } from '@nightshift/backend-domain';
import { Actor } from './auth';
import { Database } from './db';
import { Presence } from './presence';
import { fields, object, requireThat, uuid } from './errors';

type Query = Pick<PoolClient,'query'>;
type Row = Record<string,any>;
export interface DirectoryFilter { language?:unknown; availableOnly?:unknown; cursor?:unknown; }
export interface DirectorySubscription { viewEpoch:string; language:string; visibleIds:string[]; }
export const DIRECTORY_LIMITS={members:2000,views:4,page:20,visible:40,lifetimeMs:300000} as const;

/** Frozen ID/rank membership; every response independently rechecks current
 * eligibility. Redis supplies liveness only, never pair authorization. */
export class Directory {
  constructor(private readonly db:Database,private readonly presence:Presence,
    private readonly videoAvailable:()=>boolean,private readonly clock:()=>number,
    private readonly liveOwner:(c:PoolClient,actor:Actor)=>Promise<unknown>,
    private readonly reachability?:(c:Query,ids:string[])=>Promise<Map<string,'foreground'|'background_eligible'>>){}

  private language(raw:unknown='ta'):string {
    requireThat(raw==='ta'||raw==='en',400,'INVALID_LANGUAGE','Select Tamil or English');return raw;
  }
  private ids(raw:unknown):string[] {
    requireThat(Array.isArray(raw)&&raw.length<=DIRECTORY_LIMITS.visible,400,'INVALID_DIRECTORY_SLICE','Choose at most 40 visible listeners');
    const ids=raw.map(uuid);requireThat(new Set(ids).size===ids.length,400,'INVALID_DIRECTORY_SLICE','Listener IDs must be unique');return ids;
  }
  private async cards(c:Query,owner:string,language:string,ids?:string[],favorites=false) {
    const sql=`SELECT u.id,u.display_name,p.avatar_code,u.languages,u.desired_online,u.mode,u.presence_version,
      EXISTS(SELECT 1 FROM active_participant_claims a WHERE a.user_id=u.id) busy,
      EXISTS(SELECT 1 FROM favorites f WHERE f.actor_id=$1 AND f.target_id=u.id) favorite,
      EXISTS(SELECT 1 FROM auth_sessions s LEFT JOIN devices d ON d.id=s.device_record_id
        WHERE s.user_id=u.id AND s.revoked_at IS NULL AND s.expires_at>$5
        AND (s.auth_kind='development' OR (d.active AND d.revoked_at IS NULL AND d.last_token_hash=s.token_hash))) live_session
      FROM users u LEFT JOIN profiles p ON p.user_id=u.id WHERE u.id<>$1 AND u.listener_approved AND u.adult_confirmed AND NOT u.suspended
      AND u.mode='listener' AND $2=ANY(u.languages) AND ($3::uuid[] IS NULL OR u.id=ANY($3))
      AND (NOT $4 OR EXISTS(SELECT 1 FROM favorites f WHERE f.actor_id=$1 AND f.target_id=u.id))
      AND NOT EXISTS(SELECT 1 FROM blocks b WHERE (b.actor_id=$1 AND b.target_id=u.id) OR (b.target_id=$1 AND b.actor_id=u.id))
      ORDER BY u.id LIMIT 2001`;
    const values=[owner,language,ids??null,favorites,new Date(this.clock())];
    const {rows}=await c.query(sql,values);
    const reachable=rows.filter(r=>r.desired_online&&r.live_session);
    const channels=this.reachability?await this.reachability(c,reachable.map(r=>r.id)):
      new Map((await this.presence.online(reachable.map(r=>r.id),new Map(reachable.map(r=>[r.id,String(r.presence_version)])))).map(id=>[id,'foreground' as const]));
    const online=new Set([...channels].filter(([,kind])=>kind==='foreground').map(([id])=>id));
    // Redis can be slow. Do not return names/eligibility or a green dot captured
    // before a concurrent deletion, approval withdrawal or new presence intent.
    const current=(await c.query(sql,[owner,language,ids??null,favorites,new Date(this.clock())])).rows;
    const versions=new Map(reachable.map(r=>[r.id,String(r.presence_version)]));
    for(const r of current)if(!r.desired_online||!r.live_session||versions.get(r.id)!==String(r.presence_version)){online.delete(r.id);channels.delete(r.id);}
    return current.map(r=>({id:r.id as string,displayName:r.display_name as string,languages:r.languages as string[],
      ...(r.avatar_code?{avatarCode:r.avatar_code as string}:{}),
      online:online.has(r.id),reachability:channels.get(r.id)??'offline' as const,available:channels.has(r.id)&&!r.busy,busy:!!r.busy,favorite:!!r.favorite,
      testOnly:true,rate:TEST_RATE,videoRate:this.videoAvailable()?TEST_VIDEO_RATE:null}));
  }
  async preview(owner:string,language='ta') {
    const rows=await this.cards(this.db.pool,owner,this.language(language));
    rows.sort((a,b)=>(a.available?0:a.busy?1:2)-(b.available?0:b.busy?1:2)||a.id.localeCompare(b.id));
    return {items:rows.slice(0,DIRECTORY_LIMITS.page),nextCursor:null};
  }
  private async view(c:Query,actor:Actor,id:string,language:string) {
    const view=(await c.query('SELECT * FROM directory_views WHERE id=$1 AND owner_id=$2 AND language=$3',[id,actor.id,language])).rows[0];
    requireThat(view,404,'DIRECTORY_VIEW_NOT_FOUND','Refresh the directory');
    requireThat(new Date(view.expires_at).getTime()>this.clock(),410,'DIRECTORY_VIEW_EXPIRED','Refresh the directory');return view;
  }
  async page(actor:Actor,raw:DirectoryFilter={},favorites=false) {
    const language=this.language(raw.language??'ta');
    const available=raw.availableOnly??false;
    requireThat(typeof available==='boolean',400,'INVALID_FIELD','availableOnly must be a boolean');
    return this.db.tx(async c=>{
      await this.liveOwner(c,actor);
      let view:Row,after=0;
      if(raw.cursor!==undefined){
        const cursor=uuid(raw.cursor);
        const record=(await c.query(`SELECT p.* FROM directory_cursors p JOIN directory_views v ON v.id=p.view_id
          WHERE p.id=$1 AND v.owner_id=$2 AND v.language=$3 AND v.available_only=$4 AND v.favorites_only=$5`,
        [cursor,actor.id,language,available,favorites])).rows[0];
        requireThat(record,404,'DIRECTORY_VIEW_NOT_FOUND','Refresh the directory');
        view=await this.view(c,actor,record.view_id,language);after=record.after_rank;
      }else{
        // Serialize creation on the owner; bounded refreshes cannot accumulate
        // unlimited rows, even from simultaneous requests/devices.
        await c.query('DELETE FROM directory_views WHERE owner_id=$1 AND expires_at<=$2',[actor.id,new Date(this.clock())]);
        const old=(await c.query('SELECT id FROM directory_views WHERE owner_id=$1 ORDER BY sequence DESC OFFSET 3',[actor.id])).rows;
        if(old.length)await c.query('DELETE FROM directory_views WHERE id=ANY($1::uuid[])',[old.map(r=>r.id)]);
        const candidates=await this.cards(c,actor.id,language,undefined,favorites);
        const truncated=candidates.length>DIRECTORY_LIMITS.members;
        const members=candidates.slice(0,DIRECTORY_LIMITS.members).filter(r=>!available||r.available);
        members.sort((a,b)=>(a.available?0:a.busy?1:2)-(b.available?0:b.busy?1:2)||a.id.localeCompare(b.id));
        const id=randomUUID(),now=new Date(this.clock()),expires=new Date(this.clock()+DIRECTORY_LIMITS.lifetimeMs);
        view=(await c.query(`INSERT INTO directory_views(id,owner_id,language,available_only,favorites_only,truncated,created_at,expires_at)
          VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,[id,actor.id,language,available,favorites,truncated,now,expires])).rows[0];
        if(members.length)await c.query(`INSERT INTO directory_members(view_id,listener_id,rank)
          SELECT $1,id,ordinality FROM unnest($2::uuid[]) WITH ORDINALITY AS m(id,ordinality)`,[id,members.map(r=>r.id)]);
      }
      const members=(await c.query('SELECT listener_id,rank FROM directory_members WHERE view_id=$1 AND rank>$2 ORDER BY rank',[view.id,after])).rows;
      const current=await this.cards(c,actor.id,language,members.map(r=>r.listener_id),favorites);
      const byId=new Map(current.map(r=>[r.id,r]));
      const items:typeof current=[];let scanned=after;
      for(const member of members){scanned=member.rank;const card=byId.get(member.listener_id);
        if(card&&(!available||card.available))items.push(card);
        if(items.length===DIRECTORY_LIMITS.page)break;
      }
      if(items.length)await c.query('UPDATE directory_members SET served=true WHERE view_id=$1 AND listener_id=ANY($2::uuid[])',[view.id,items.map(r=>r.id)]);
      let nextCursor:string|null=null;
      if(members.some(r=>r.rank>scanned))nextCursor=(await c.query(`INSERT INTO directory_cursors(id,view_id,after_rank) VALUES($1,$2,$3)
        ON CONFLICT(view_id,after_rank) DO UPDATE SET after_rank=EXCLUDED.after_rank RETURNING id`,[randomUUID(),view.id,scanned])).rows[0].id;
      return {items,nextCursor,viewEpoch:view.id as string,expiresAt:new Date(view.expires_at).toISOString(),serverTime:new Date(this.clock()).toISOString(),truncated:!!view.truncated};
    });
  }
  async statuses(actor:Actor,raw:unknown) {
    const body=object(raw);fields(body,['language','listenerIds']);const language=this.language(body.language),ids=this.ids(body.listenerIds);
    return this.db.tx(async c=>{
      await this.liveOwner(c,actor);
      // Arbitrary account-ID probing is not a directory/detail endpoint.
      const allowed=(await c.query(`SELECT u.id FROM users u WHERE u.id=ANY($2::uuid[]) AND (
        EXISTS(SELECT 1 FROM favorites f WHERE f.actor_id=$1 AND f.target_id=u.id)
        OR EXISTS(SELECT 1 FROM call_sessions s WHERE s.customer_id=$1 AND s.listener_id=u.id)
        OR EXISTS(SELECT 1 FROM directory_members m JOIN directory_views v ON v.id=m.view_id
          WHERE v.owner_id=$1 AND v.language=$3 AND v.expires_at>$4 AND m.served AND m.listener_id=u.id))`,
      [actor.id,ids,language,new Date(this.clock())])).rows.map(r=>r.id);
      const items=await this.cards(c,actor.id,language,allowed);const present=new Set(items.map(r=>r.id));
      return {items,removedIds:ids.filter(id=>!present.has(id)),serverTime:new Date(this.clock()).toISOString()};
    });
  }
  async subscribe(actor:Actor,raw:unknown):Promise<DirectorySubscription|null> {
    if(raw===null)return null;
    const body=object(raw);fields(body,['viewEpoch','language','visibleIds']);const ids=this.ids(body.visibleIds);
    if(!ids.length)return null;
    const viewEpoch=uuid(body.viewEpoch),language=this.language(body.language);
    await this.db.tx(async c=>{
      await this.liveOwner(c,actor);await this.view(c,actor,viewEpoch,language);
      const members=await c.query('SELECT listener_id FROM directory_members WHERE view_id=$1 AND served AND listener_id=ANY($2::uuid[])',[viewEpoch,ids]);
      requireThat(members.rows.length===ids.length,404,'DIRECTORY_VIEW_NOT_FOUND','Refresh the visible directory');
    });return {viewEpoch,language,visibleIds:ids};
  }
  async updates(actor:Actor,subscription:DirectorySubscription) {
    return this.db.tx(async c=>{
      await this.liveOwner(c,actor);const view=await this.view(c,actor,subscription.viewEpoch,subscription.language);
      // Recheck served membership: deletion may have erased it after subscribe.
      const members=(await c.query('SELECT listener_id FROM directory_members WHERE view_id=$1 AND served AND listener_id=ANY($2::uuid[])',
        [view.id,subscription.visibleIds])).rows.map(r=>r.listener_id);
      const items=await this.cards(c,actor.id,subscription.language,members,view.favorites_only);
      const present=new Set(items.map(r=>r.id));
      return {viewEpoch:subscription.viewEpoch,language:subscription.language,serverTime:new Date(this.clock()).toISOString(),
        items,removedIds:subscription.visibleIds.filter(id=>!present.has(id))};
    });
  }
  async cleanupExpired(limit=100) {
    requireThat(Number.isSafeInteger(limit)&&limit>0&&limit<=100,400,'INVALID_FIELD','Invalid cleanup limit');
    await this.db.pool.query(`DELETE FROM directory_views WHERE id IN (SELECT id FROM directory_views WHERE expires_at<=$1
      ORDER BY expires_at LIMIT $2 FOR UPDATE SKIP LOCKED)`,[new Date(this.clock()),limit]);
  }
}
