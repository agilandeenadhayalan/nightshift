import 'reflect-metadata';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {TEST_RATE} from '@nightshift/backend-domain';
import {Actor,Auth,tokenHash} from '../src/auth';
import {Config} from '../src/config';
import {Database} from '../src/db';
import {migrate} from '../src/migrate';
import {Presence} from '../src/presence';
import {NightShiftService} from '../src/service';
import {PhoneAuthentication,PhoneAuthDependencies} from '../src/identity/phone-auth';
import {VerifiedFirebaseIdentity} from '../src/identity/firebase';
import {createApplication} from '../src/http';

export type MatchingParticipant=Actor&{token:string;uid:string;mobile:string;device:string};
export const matchBody=(language:'ta'|'en'='ta')=>({language,mediaType:'audio',quoteId:TEST_RATE.id,consent:true,consentVersion:'matching-search-v1'});
export const deferred=()=>{let release!:()=>void;const promise=new Promise<void>(resolve=>{release=resolve;});return{promise,release};};
export async function bounded<T>(promise:Promise<T>,message='Deterministic race gate did not complete'):Promise<T>{
  let timer:ReturnType<typeof setTimeout>|undefined;
  try{return await Promise.race([promise,new Promise<never>((_,reject)=>{timer=setTimeout(()=>reject(Error(message)),5000);})]);}
  finally{if(timer)clearTimeout(timer);}
}

/** All identities, credits and leases are synthetic and scoped to one schema.
 * This uses the real native enrollment/session path with an injected verifier;
 * no provider, SMS, live account or RTC operation is performed. */
export class MatchingFixture {
  readonly schema=`matching_${randomUUID().replaceAll('-','')}`;
  readonly ids=new Set<string>();
  readonly identities=new Map<string,VerifiedFirebaseIdentity>();
  readonly project='isolated-matching-fixture';
  now=Date.now();
  admin!:Database;db!:Database;presence!:Presence;auth!:Auth;phone!:PhoneAuthentication;service!:NightShiftService;config!:Config;
  private sequence=0;
  private httpRuntime?:Awaited<ReturnType<typeof createApplication>>;
  private readonly dependencies:PhoneAuthDependencies={firebase:{verifyIdToken:async token=>{
    const identity=this.identities.get(String(token));assert.ok(identity,'Only an explicit synthetic identity is accepted');return identity;
  }}};
  readonly clock=()=>this.now;
  async open(){
    assert.equal(process.env.NODE_ENV,'test');assert.ok(process.env.TEST_DATABASE_URL);assert.ok(process.env.REDIS_URL);
    const url=new URL(process.env.TEST_DATABASE_URL!);
    assert.ok(['localhost','127.0.0.1','::1'].includes(url.hostname));assert.match(decodeURIComponent(url.pathname.slice(1)),/^[a-z0-9_]+_test$/);
    const redis=new URL(process.env.REDIS_URL!);
    assert.ok(['localhost','127.0.0.1','::1'].includes(redis.hostname));assert.notEqual(redis.pathname,'/13','Never use the live device Redis database');
    // CI's fresh Redis service defaults to DB0; this suite always chooses14/15.
    if(!['/14','/15'].includes(redis.pathname))redis.pathname='/14';
    this.admin=new Database(url.toString());await this.admin.pool.query(`CREATE SCHEMA ${this.schema}`);
    url.searchParams.set('options',`-csearch_path=${this.schema}`);this.db=new Database(url.toString());await migrate(this.db);
    await this.db.pool.query('INSERT INTO rate_versions(id,policy,test_only) VALUES($1,$2,true)',[TEST_RATE.id,TEST_RATE]);
    await this.db.pool.query("INSERT INTO wallet_accounts(id,unit,kind) VALUES('platform:test','TEST_MICROCREDIT','platform_test'),('subsidy:test','TEST_PAISE','subsidy_test')");
    this.config={databaseUrl:url.toString(),redisUrl:redis.toString(),port:0,devAccessKey:'isolated-matching-test-key',
      phoneAuth:{provider:'firebase',projectId:this.project,digestKey:randomBytes(32).toString('hex'),consentVersion:'phone-signin-v1',dailyAdmissionLimit:1000}};
    this.presence=new Presence(this.config.redisUrl);await this.presence.connect();
    this.phone=new PhoneAuthentication(this.db,this.presence,this.config.phoneAuth,this.dependencies,this.clock);
    this.auth=new Auth(this.db,this.presence,this.config,this.phone,this.clock);
    this.service=new NightShiftService(this.db,this.presence,this.config,this.clock);
  }
  advance(ms:number){this.now+=ms;}
  private proof(uid:string,mobile:string,authTime=Math.floor(this.now/1000)){
    const token=randomBytes(32).toString('hex'),issuedAt=Math.floor(this.now/1000);
    this.identities.set(token,{uid,issuer:`https://securetoken.google.com/${this.project}`,audience:this.project,authTime,issuedAt,expiresAt:issuedAt+3600,signInProvider:'phone',phoneNumber:mobile});
    return token;
  }
  async participant(listener=false,languages=['ta']):Promise<MatchingParticipant>{
    const uid=`matching-${randomUUID()}`,mobile=`+919${String(++this.sequence).padStart(9,'0')}`,device=randomUUID(),token=this.proof(uid,mobile);
    const admission=await this.phone.admit({phone:mobile,deviceId:device,consentVersion:'phone-signin-v1'},`${this.schema}:${randomUUID()}`,randomUUID());
    const signed=await this.auth.exchange({idToken:token,deviceId:device,attemptId:admission.attemptId},`${this.schema}:${randomUUID()}`);
    this.ids.add(signed.userId);
    await this.db.tx(async c=>{
      await c.query('UPDATE users SET display_name=$2,adult_confirmed=true,listener_approved=$3,mode=$4,languages=$5 WHERE id=$1',[signed.userId,'Synthetic matching participant',listener,listener?'listener':'customer',languages]);
      await c.query("INSERT INTO wallet_accounts(id,user_id,unit,kind) VALUES($1,$2,'TEST_MICROCREDIT','customer_test'),($3,$2,'TEST_PAISE','listener_test')",[`customer:${signed.userId}`,signed.userId,`listener:${signed.userId}`]);
      await c.query("INSERT INTO journal_batches(id,kind) VALUES($1,'fictional_test_grant')",[`matching:${signed.userId}`]);
      await c.query("INSERT INTO journal_lines(batch_id,account_id,amount) VALUES($1,$2,10000000000),($1,'platform:test',-10000000000)",[`matching:${signed.userId}`,`customer:${signed.userId}`]);
    });
    const actor={...await this.auth.authenticate(token),token,uid,mobile,device};
    if(listener)await this.service.availability(actor,{online:true});return actor;
  }
  async refresh(actor:MatchingParticipant,fresh=false,device=actor.device){
    this.advance(1000);const token=this.proof(actor.uid,actor.mobile,fresh?Math.floor(this.now/1000):actor.identityAuthTime);
    await this.auth.exchange({idToken:token,deviceId:device},`${this.schema}:${randomUUID()}`);
    return{...actor,...await this.auth.authenticate(token),token,device};
  }
  /** Bulk synthetic development listeners make the >2,000-row shortlist test
   * practical without pretending to enroll thousands of provider identities. */
  async developmentListeners(ids:string[]){
    const tokens=ids.map(()=>randomBytes(32).toString('hex'));
    await this.db.tx(async c=>{
      await c.query("INSERT INTO users(id,test_handle,display_name,listener_approved,mode,languages) SELECT id,id::text,'Synthetic fairness participant',true,'listener',ARRAY['ta'] FROM unnest($1::uuid[]) id",[ids]);
      await c.query("INSERT INTO auth_sessions(token_hash,user_id,device_id,expires_at) SELECT token,id,'synthetic-fairness-device',$3 FROM unnest($1::uuid[],$2::text[]) AS value(id,token)",[ids,tokens.map(tokenHash),new Date(this.now+3_600_000)]);
      await c.query('UPDATE users SET desired_online=true WHERE id=ANY($1::uuid[])',[ids]);
    });
    const versions=(await this.db.pool.query('SELECT id,presence_version FROM users WHERE id=ANY($1::uuid[])',[ids])).rows;
    for(const row of versions){this.ids.add(row.id);await this.presence.heartbeat(row.id,String(row.presence_version));}
    return ids.map((id,i)=>({id,sessionHash:tokenHash(tokens[i]!),token:tokens[i]!}));
  }
  async request(path:string,actor?:MatchingParticipant,method='GET',body?:unknown,key?:string){
    if(!this.httpRuntime){this.httpRuntime=await createApplication(this.config,this.clock,this.dependencies);await this.httpRuntime.app.listen(0,'127.0.0.1');}
    const base=await this.httpRuntime.app.getUrl();
    const response=await fetch(`${base}/v1/${path}`,{method,headers:{...(actor?{Authorization:`Bearer ${actor.token}`}:{}) ,...(body===undefined?{}:{'Content-Type':'application/json'}),...(key?{'Idempotency-Key':key}:{})},body:body===undefined?undefined:JSON.stringify(body)});
    return{status:response.status,body:await response.json() as any};
  }
  async close(){
    if(this.httpRuntime)await this.httpRuntime.close();
    if(this.presence){for(const id of this.ids)await this.presence.clear(id);await this.presence.close();}
    if(this.db)await this.db.close();
    if(this.admin){await this.admin.pool.query(`DROP SCHEMA IF EXISTS ${this.schema} CASCADE`);await this.admin.close();}
  }
}
