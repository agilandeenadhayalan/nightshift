import {after,before,test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {copyFile,mkdtemp,readFile,readdir,rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import {TEST_RATE} from '@nightshift/backend-domain';
import {Database} from '../src/db';
import {migrate} from '../src/migrate';
import {Onboarding} from '../src/identity/onboarding';
import {MatchingFixture,MatchingParticipant} from './matching-fixture';

const h=new MatchingFixture();
const body=(avatarCode:unknown)=>({dateOfBirth:'1990-01-02',displayName:'Private Nickname',avatarCode,
  interfaceLanguage:'en',languages:['ta'],consentVersion:'adult-onboarding-v1'});
let onboarding:Onboarding;
before(async()=>{await h.open();onboarding=new Onboarding(h.db,h.clock);});
after(()=>h.close());
async function setAvatar(actor:MatchingParticipant,code:string){return onboarding.complete(actor,body(code));}
async function validate(name:string,value:unknown){
  const schema=JSON.parse(await readFile(path.resolve(__dirname,'../../../../packages/contracts/openapi.json'),'utf8'));
  const defs=JSON.parse(JSON.stringify(schema.components.schemas).replaceAll('#/components/schemas/','#/$defs/'));
  const ajv=new Ajv({strict:false});addFormats(ajv);const check=ajv.compile({$defs:defs,$ref:`#/$defs/${name}`});
  assert.equal(check(value),true,JSON.stringify(check.errors));
}

test('all sixty portraits and four legacy avatars persist through the real onboarding boundary',async()=>{
  const actor=await h.participant();
  for(const code of ['moon','star','leaf','wave',...['male','female'].flatMap(prefix=>Array.from({length:30},(_,i)=>`${prefix}_${String(i+1).padStart(2,'0')}`))]){
    const result=await setAvatar(actor,code);assert.equal(result.profile.avatarCode,code);
    assert.equal((await h.db.pool.query('SELECT avatar_code FROM profiles WHERE user_id=$1',[actor.id])).rows[0].avatar_code,code);
    await validate('OnboardingState',result);
  }
  const user=(await h.db.pool.query('SELECT mode,listener_approved FROM users WHERE id=$1',[actor.id])).rows[0];
  assert.deepEqual(user,{mode:'customer',listener_approved:false});
});

test('unknown codes, URLs, paths and malformed values fail without changing the saved selection',async()=>{
  const actor=await h.participant();await setAvatar(actor,'star');
  for(const invalid of ['male_00','female_31','male_1','Male_01','female_01 ','https://example.com/avatar.png','../male_01',null,['moon'],{},42]){
    await assert.rejects(onboarding.complete(actor,body(invalid)),{code:'INVALID_AVATAR'});
    assert.equal((await onboarding.get(actor)).profile.avatarCode,'star');
  }
  for(const invalid of ['male_00','female_31','https://example.com/avatar.png']){
    await assert.rejects(h.db.pool.query('UPDATE profiles SET avatar_code=$2 WHERE user_id=$1',[actor.id,invalid]),{code:'23514'});
  }
});

test('current owner and directory HTTP projections use saved portraits without private profile fields',async()=>{
  const customer=await h.participant(),listener=await h.participant(true);
  await setAvatar(customer,'female_30');await setAvatar(listener,'male_01');
  const me=await h.request('me',customer);assert.equal(me.status,200);assert.equal(me.body.avatarCode,'female_30');await validate('User',me.body);
  const page=await h.request('listeners?language=ta',customer);assert.equal(page.status,200);
  const card=page.body.items.find((x:any)=>x.id===listener.id);assert.equal(card.avatarCode,'male_01');await validate('ListenerPage',page.body);
  const status=await h.request('listeners/status',customer,'POST',{language:'ta',listenerIds:[listener.id]});
  assert.equal(status.body.items[0].avatarCode,'male_01');
  await h.service.favorite(customer,listener.id,true);
  const favorites=await h.request('favorites?language=ta',customer);assert.equal(favorites.body.items[0].avatarCode,'male_01');
  for(const value of [me.body,card,status.body.items[0],favorites.body.items[0]]){
    const json=JSON.stringify(value);assert.ok(!json.includes('1990-01-02'));assert.ok(!json.includes('Private Nickname'));assert.ok(!json.includes(customer.mobile));
  }
  const denied=await h.request('me/onboarding',undefined,'PUT',body('female_01'));assert.equal(denied.status,401);
});

test('call participants, history and durable events publish their selected portraits, never mode-based gender',async()=>{
  const customer=await h.participant(),listener=await h.participant(true),outsider=await h.participant();
  await setAvatar(customer,'male_30');await setAvatar(listener,'female_01');
  const call=await h.service.createCall(customer,{listenerId:listener.id,quoteId:TEST_RATE.id},randomUUID());
  assert.equal((call as any).customerAvatarCode,'male_30');assert.equal((call as any).listenerAvatarCode,'female_01');
  const current=await h.request(`calls/${call.id}`,listener);await validate('Call',current.body);
  assert.equal(current.body.customerAvatarCode,'male_30');assert.equal(current.body.listenerAvatarCode,'female_01');
  const event=(await h.db.pool.query('SELECT payload FROM call_events WHERE call_id=$1 ORDER BY sequence LIMIT 1',[call.id])).rows[0].payload;
  assert.equal(event.customerAvatarCode,'male_30');assert.equal(event.listenerAvatarCode,'female_01');
  await h.service.action(customer,call.id,'cancel',{expectedVersion:call.version},randomUUID());
  const history=await h.request('calls',customer);assert.equal(history.status,200);await validate('CallPage',history.body);
  assert.equal(history.body.items.find((x:any)=>x.id===call.id).listenerAvatarCode,'female_01');
  assert.equal((await h.request(`calls/${call.id}`,outsider)).status,404);
});

test('legacy missing profiles and saved receipts remain field-absent after later avatar selection',async()=>{
  const customer=await h.participant(),listener=await h.participant(true),key=randomUUID();
  const request={listenerId:listener.id,quoteId:TEST_RATE.id};
  const call=await h.service.createCall(customer,request,key);assert.ok(!('customerAvatarCode' in call));assert.ok(!('listenerAvatarCode' in call));
  assert.ok(!('avatarCode' in await h.service.user(customer.id)));
  await h.service.action(customer,call.id,'cancel',{expectedVersion:call.version},randomUUID());
  await setAvatar(customer,'male_02');await setAvatar(listener,'female_02');
  const replay=await h.service.createCall(customer,request,key);assert.ok(!('customerAvatarCode' in replay));assert.ok(!('listenerAvatarCode' in replay));await validate('Call',replay);
  const events=(await h.db.pool.query('SELECT payload FROM call_events WHERE call_id=$1',[call.id])).rows;
  assert.ok(events.every(r=>!('customerAvatarCode' in r.payload)&&!('listenerAvatarCode' in r.payload)));
  assert.equal((await h.service.call(customer.id,call.id) as any).customerAvatarCode,'male_02');
});

test('forward avatar migration preserves legacy profiles and all previous migration checksums',async()=>{
  const schema=`avatar_upgrade_${randomUUID().replaceAll('-','')}`,directory=path.resolve(__dirname,'../../../../db/migrations');
  const temp=await mkdtemp(path.join(os.tmpdir(),'nightshift-avatar-upgrade-'));let db:Database|undefined;
  await h.admin.pool.query(`CREATE SCHEMA ${schema}`);
  try{
    for(const name of(await readdir(directory)).filter(name=>/^\d{3}_.+\.sql$/.test(name)&&Number(name.slice(0,3))<=19))await copyFile(path.join(directory,name),path.join(temp,name));
    const url=new URL(process.env.TEST_DATABASE_URL!);url.searchParams.set('options',`-csearch_path=${schema}`);db=new Database(url.toString());await migrate(db,temp);
    const id=randomUUID();await db.pool.query("INSERT INTO users(id,display_name) VALUES($1,'Legacy profile')",[id]);
    await db.pool.query("INSERT INTO age_declarations(user_id,date_of_birth) VALUES($1,'1990-01-02')",[id]);
    await db.pool.query("INSERT INTO profiles(user_id,date_of_birth,submitted_display_name,avatar_code,interface_language) VALUES($1,'1990-01-02','Private legacy','wave','en')",[id]);
    const before=(await db.pool.query('SELECT to_jsonb(p) value FROM profiles p')).rows;
    const checksums=(await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name')).rows;assert.equal(checksums.length,19);
    await migrate(db);await migrate(db);assert.deepEqual((await db.pool.query('SELECT to_jsonb(p) value FROM profiles p')).rows,before);
    assert.deepEqual((await db.pool.query('SELECT name,checksum FROM schema_migrations ORDER BY name LIMIT 19')).rows,checksums);
    await db.pool.query("UPDATE profiles SET avatar_code='female_30' WHERE user_id=$1",[id]);
    await assert.rejects(db.pool.query("UPDATE profiles SET avatar_code='female_31' WHERE user_id=$1",[id]),{code:'23514'});
  }finally{await db?.close();await h.admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await rm(temp,{recursive:true,force:true});}
});
