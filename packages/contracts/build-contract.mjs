import { readFile, writeFile } from 'node:fs/promises';
const str={type:'string'}, bool={type:'boolean'}, integer={type:'integer'}, id={type:'string',format:'uuid'};
const date={type:'string',format:'date-time'}, nullableDate={type:['string','null'],format:'date-time'};
const ref=name=>({$ref:`#/components/schemas/${name}`});
const array=items=>({type:'array',items});
const object=(properties,required=Object.keys(properties))=>({type:'object',properties,required,additionalProperties:false});
const schemas={
  User:object({id,displayName:str,languages:array({type:'string',enum:['ta','en']}),mode:{type:'string',enum:['customer','listener']},listenerApproved:bool,online:bool}),
  Rate:object({id:{const:'test-audio-v1',type:'string'},coinsPerMinute:integer,microcreditsPerCoin:integer,microcreditsPerSecond:integer,freeThroughSeconds:integer,minimumChargedSeconds:integer,listenerPaisePerHour:integer,testOnly:{const:true,type:'boolean'}}),
  Wallet:object({balanceMicrocredits:integer,heldMicrocredits:integer,availableMicrocredits:integer,testOnly:{const:true,type:'boolean'}}),
  Listener:object({id,displayName:str,languages:array({type:'string',enum:['ta','en']}),online:bool,available:bool,busy:bool,favorite:bool,testOnly:bool,rate:ref('Rate')}),
  Call:object({id,customerId:id,listenerId:id,customerName:str,listenerName:str,state:{type:'string',enum:['ringing','connecting','connected','reconnecting','ended']},version:integer,
    createdAt:date,expiresAt:date,acceptedAt:nullableDate,endedAt:nullableDate,reason:{type:['string','null']},connectedMs:integer,chargeMicrocredits:integer,earningPaise:integer,rate:ref('Rate'),maxDurationSeconds:integer,testOnly:{const:true,type:'boolean'}}),
  Snapshot:object({user:ref('User'),activeCall:{anyOf:[ref('Call'),{type:'null'}]},listeners:array(ref('Listener')),wallet:ref('Wallet'),serverTime:date}),
  CallPage:object({items:array(ref('Call')),nextCursor:{type:['string','null'],format:'uuid'}}),
  ListenerPage:object({items:array(ref('Listener')),nextCursor:{type:['string','null'],format:'uuid'}}),
  Login:object({token:str,expiresAt:date,user:ref('User'),testOnly:{const:true,type:'boolean'}}),
  RtcToken:object({appId:str,channel:str,uid:{type:'integer',enum:[1,2]},remoteUid:{type:'integer',enum:[1,2]},token:str,expiresAt:date}),
  Error:object({error:object({code:str,message:str}),requestId:id}),
  Event:object({id,type:{type:'string',enum:['call.invited','call.state_changed']},entityId:id,version:integer,timestamp:date,data:ref('Call')})
};
const responses=schema=>({200:{description:'Authoritative response',content:{'application/json':{schema}}},400:{description:'Validation failed',content:{'application/json':{schema:ref('Error')}}},401:{description:'Session is missing, expired or revoked',content:{'application/json':{schema:ref('Error')}}},409:{description:'State, eligibility or idempotency conflict',content:{'application/json':{schema:ref('Error')}}},503:{description:'Dependency or RTC configuration unavailable',content:{'application/json':{schema:ref('Error')}}}});
const pathId={name:'id',in:'path',required:true,schema:id};
const idempotency={name:'Idempotency-Key',in:'header',required:true,schema:{type:'string',minLength:1,maxLength:128}};
const json=schema=>({required:true,content:{'application/json':{schema}}});
const paths={
  '/v1/health':{get:{operationId:'health',security:[],responses:responses(object({status:str,service:str,testOnly:bool}))}},
  '/v1/auth/dev':{post:{operationId:'developmentSignIn',security:[],description:'Development/test only. Server refuses production boot.',requestBody:json(object({handle:{type:'string',enum:['customer','customer2','listener']},accessKey:{type:'string',minLength:24},deviceId:str})),responses:{201:responses(ref('Login'))[200]}}},
  '/v1/auth/logout':{post:{operationId:'signOut',responses:responses(object({signedOut:bool}))}},
  '/v1/me':{get:{operationId:'getMe',responses:responses(ref('User'))}},
  '/v1/snapshot':{get:{operationId:'getSnapshot',parameters:[{name:'language',in:'query',schema:{type:'string',enum:['ta','en'],default:'ta'}}],responses:responses(ref('Snapshot'))}},
  '/v1/me/mode':{put:{operationId:'setMode',requestBody:json(object({mode:{type:'string',enum:['customer','listener']}})),responses:responses(ref('User'))}},
  '/v1/me/availability':{put:{operationId:'setAvailability',requestBody:json(object({online:bool})),responses:responses(ref('User'))}},
  '/v1/me/languages':{put:{operationId:'setLanguages',requestBody:json(object({languages:array({type:'string',enum:['ta','en']})})),responses:responses(ref('User'))}},
  '/v1/presence/heartbeat':{post:{operationId:'heartbeat',responses:responses(object({serverTime:date}))}},
  '/v1/listeners':{get:{operationId:'listListeners',parameters:[{name:'language',in:'query',schema:{type:'string',enum:['ta','en']}},{name:'cursor',in:'query',schema:id}],responses:responses(ref('ListenerPage'))}},
  '/v1/calls':{
    get:{operationId:'listCalls',parameters:[{name:'cursor',in:'query',schema:id}],responses:responses(ref('CallPage'))},
    post:{operationId:'createCall',parameters:[idempotency],requestBody:json(object({listenerId:id,quoteId:{type:'string',const:'test-audio-v1'}})),responses:{201:responses(ref('Call'))[200]}}
  },
  '/v1/calls/{id}':{get:{operationId:'getCall',parameters:[pathId],responses:responses(ref('Call'))}},
  '/v1/calls/{id}/media':{post:{operationId:'reportMediaReady',parameters:[pathId],description:'Report only local/remote RTC readiness. No client duration or price. Heartbeat every two seconds; not provider proof.',requestBody:json(object({ready:bool})),responses:responses(ref('Call'))}},
  '/v1/calls/{id}/rtc-token':{post:{operationId:'getRtcToken',parameters:[pathId],responses:responses(ref('RtcToken'))}},
  '/v1/rates':{get:{operationId:'getRates',responses:responses(object({items:array(ref('Rate'))}))}},
  '/v1/wallet':{get:{operationId:'getWallet',responses:responses(ref('Wallet'))}},
  '/v1/me/earnings':{get:{operationId:'getTestEarnings',responses:responses(object({illustrativePaise:integer,availablePaise:integer,paidPaise:integer,testOnly:bool,listenerPaisePerHour:integer}))}},
  '/v1/reports':{post:{operationId:'createReport',parameters:[idempotency],requestBody:json(object({callId:id,reason:{type:'string',minLength:1,maxLength:1000}})),responses:responses(object({id,status:str}))}},
  '/v1/blocks/{id}':{put:{operationId:'blockUser',parameters:[pathId],responses:responses(object({blocked:bool}))}},
  '/v1/events':{get:{operationId:'getEvents',parameters:[{name:'cursor',in:'query',schema:id}],responses:responses(object({items:array(ref('Event')),nextCursor:{type:['string','null'],format:'uuid'}}))}}
};
for(const action of ['accept','decline','cancel','end'])paths[`/v1/calls/{id}/${action}`]={post:{operationId:`${action}Call`,parameters:[pathId,idempotency],requestBody:json(object({expectedVersion:integer})),responses:responses(ref('Call'))}};
paths['/v1/favorites/{id}']={put:{operationId:'favoriteListener',parameters:[pathId],responses:responses(object({favorite:bool}))},delete:{operationId:'unfavoriteListener',parameters:[pathId],responses:responses(object({favorite:bool}))}};
// Nest defaults POST to 201. Describe actual statuses so generated clients accept the response.
for(const route of Object.values(paths))for(const [method,operation] of Object.entries(route))if(method==='post'&&operation.responses[200]){operation.responses[201]=operation.responses[200];delete operation.responses[200];}
const contract={openapi:'3.1.0',info:{title:'NightShift Android test milestone',version:'0.1.0',description:'One shared backend; fictional test credits only. Real-money and production identity adapters are disabled.'},servers:[{url:'http://localhost:3000'}],security:[{bearerAuth:[]}],paths,components:{securitySchemes:{bearerAuth:{type:'http',scheme:'bearer'}},schemas}};
const event={$schema:'https://json-schema.org/draft/2020-12/schema',$defs:JSON.parse(JSON.stringify(schemas).replaceAll('#/components/schemas/','#/$defs/')),$ref:'#/$defs/Event'};
for(const [file,value] of [['openapi.json',contract],['events.schema.json',event]]){
  const url=new URL(file,import.meta.url),content=JSON.stringify(value,null,2)+'\n';
  if(process.argv.includes('--check')){if(await readFile(url,'utf8')!==content)throw new Error(`${file} needs regeneration`);}
  else await writeFile(url,content);
}
