import { readFile, writeFile } from 'node:fs/promises';

const object = (properties, required = Object.keys(properties)) => ({type:'object', properties, required, additionalProperties:false});
const ref = name => ({$ref:`#/components/schemas/${name}`});
const timestamp = {type:'string',format:'date-time'};
const csrf = {type:'string',pattern:'^[0-9a-f]{64}$'};
const permission = {type:'string',enum:['listener.review.read','listener.review.evidence.read','listener.review.decide']};
const schemas = {
  StaffAuthStatus: object({configured:{type:'boolean'},available:{type:'boolean'},reasonCode:{type:['string','null'],enum:['STAFF_AUTH_UNAVAILABLE',null]}}),
  StaffChallenge: object({csrfToken:csrf,expiresAt:timestamp}),
  StaffExchange: object({proof:{type:'string',minLength:1,maxLength:16384}}),
  StaffSession: object({staff:object({id:{type:'string',format:'uuid'}}),permissions:{type:'array',items:permission,maxItems:3,uniqueItems:true},expiresAt:timestamp,csrfToken:csrf}),
  StaffLogout: object({signedOut:{type:'boolean',const:true}}),
  StaffEmptyBody: object({}),
  StaffError: object({error:object({code:{type:'string'},message:{type:'string'},retryAfterSeconds:{type:'integer',minimum:1}},['code','message']),requestId:{type:'string',format:'uuid'}}),
};
const json = schema => ({'application/json':{schema}});
const origin = {name:'Origin',in:'header',required:true,schema:{type:'string',format:'uri'},description:'Must exactly match the configured staff origin.'};
const csrfHeader = {name:'X-CSRF-Token',in:'header',required:true,schema:csrf};
const noStore = {'Cache-Control':{schema:{type:'string',const:'no-store'}}};
const responses = schema => ({
  200:{description:'Staff response; never grants ordinary application modes.',headers:noStore,content:json(schema)},
  ...Object.fromEntries(Object.entries({400:'Invalid request',401:'Staff session is missing, expired or revoked',403:'Staff permission, origin or CSRF denied',429:'Staff request rate limit',503:'Staff authentication is unavailable'})
    .map(([status,description]) => [status,{description,headers:noStore,content:json(ref('StaffError'))}]))
});
const body = schema => ({required:true,content:json(schema)});
const contract = {
  openapi:'3.1.0',
  info:{title:'NightShift separate staff authority',version:'0.1.0',description:'Owner-selected single-factor SMS OTP with explicit staff grants. Customer and Listener remain the only application modes. Staff pages are intended for the in-app browser; live access is unavailable until a real verifier and approved principal are configured. No provider proof, cookie or CSRF token belongs in a URL or browser storage.'},
  servers:[{url:'/'}],
  security:[{staffSession:[]}],
  paths:{
    '/v1/admin/auth/status':{get:{operationId:'getStaffAuthStatus',security:[],responses:responses(ref('StaffAuthStatus'))}},
    '/v1/admin/auth/challenge':{post:{operationId:'createStaffChallenge',security:[],parameters:[origin],requestBody:body(ref('StaffEmptyBody')),responses:responses(ref('StaffChallenge')),description:'Issues a short-lived Secure HttpOnly host-only challenge cookie. The response CSRF token stays in memory and is required for exchange.'}},
    '/v1/admin/auth/exchange':{post:{operationId:'exchangeStaffProof',security:[{staffChallenge:[]}],parameters:[origin,csrfHeader],requestBody:body(ref('StaffExchange')),responses:responses(ref('StaffSession')),description:'Consumes the challenge, verifies current provider phone authentication and an explicitly provisioned staff principal, and issues the separate opaque staff session cookie. Provider/customer role claims do not grant permissions.'}},
    '/v1/admin/session':{get:{operationId:'getStaffSession',responses:responses(ref('StaffSession')),description:'Revalidates the provider identity and local principal/session/grants. Returns minimal staff authority plus a session-bound CSRF token.'}},
    '/v1/admin/auth/logout':{post:{operationId:'logoutStaffSession',parameters:[origin,csrfHeader],requestBody:body(ref('StaffEmptyBody')),responses:responses(ref('StaffLogout')),description:'Revokes every session for this staff principal and clears the presented cookie. Customer authentication and modes remain separate.'}},
  },
  components:{securitySchemes:{
    staffSession:{type:'apiKey',in:'cookie',name:'__Host-nightshift_staff',description:'Random opaque credential; Secure, HttpOnly, SameSite=Strict, Path=/, no Domain.'},
    staffChallenge:{type:'apiKey',in:'cookie',name:'__Host-nightshift_staff_challenge',description:'Short-lived opaque challenge; Secure, HttpOnly, SameSite=Strict, Path=/, no Domain.'},
  },schemas},
};
const url = new URL('staff.openapi.json',import.meta.url);
const content = JSON.stringify(contract,null,2)+'\n';
if(process.argv.includes('--check')) {
  if(await readFile(url,'utf8')!==content) throw new Error('staff.openapi.json needs regeneration');
} else await writeFile(url,content);
