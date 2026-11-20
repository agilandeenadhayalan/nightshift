import { readFile, writeFile } from 'node:fs/promises';

const object = (properties, required = Object.keys(properties)) => ({type:'object', properties, required, additionalProperties:false});
const ref = name => ({$ref:`#/components/schemas/${name}`});
const timestamp = {type:'string',format:'date-time'};
const csrf = {type:'string',pattern:'^[0-9a-f]{64}$'};
const permission = {type:'string',enum:['listener.review.read','listener.review.evidence.read','listener.review.decide','staff.access.manage']};
const schemas = {
  StaffAuthStatus: object({configured:{type:'boolean'},available:{type:'boolean'},reasonCode:{type:['string','null'],enum:['STAFF_AUTH_UNAVAILABLE',null]}}),
  StaffChallenge: object({csrfToken:csrf,expiresAt:timestamp}),
  StaffExchange: object({proof:{type:'string',minLength:1,maxLength:16384}}),
  StaffSession: object({staff:object({id:{type:'string',format:'uuid'}}),permissions:{type:'array',items:permission,maxItems:4,uniqueItems:true},expiresAt:timestamp,csrfToken:csrf}),
  StaffAccessRequest: object({requestId:{type:'string',format:'uuid'},accountReference:{type:'string',format:'uuid'},status:{type:'string',enum:['pending','provisioned']},expiresAt:timestamp}),
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
  ...Object.fromEntries(Object.entries({400:'Invalid request',401:'Staff or app session is missing, expired or revoked',403:'Staff permission, origin, freshness or CSRF denied',404:'Current access request does not exist',429:'Staff request rate limit',503:'Staff authentication is unavailable'})
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
    '/v1/admin/auth/challenge':{post:{operationId:'createStaffChallenge',security:[{nativeAppSession:[]}],parameters:[origin],requestBody:body(ref('StaffEmptyBody')),responses:responses(ref('StaffChallenge')),description:'Native HTTP only. Requires a registered current phone app session and binds its device/authentication lineage to a120-second Secure HttpOnly challenge cookie. CSRF remains in native memory.'}},
    '/v1/admin/auth/exchange':{post:{operationId:'exchangeStaffProof',security:[{staffChallenge:[],nativeAppSession:[]}],parameters:[origin,csrfHeader],requestBody:body(ref('StaffExchange')),responses:responses(ref('StaffSession')),description:'Native HTTP only. Proof must equal the current app bearer. Consumes the challenge and checks the exact linked staff principal and grants. Returns an opaque staff cookie with at most1800seconds lifetime; only that cookie enters the fixed-origin browser. Provider/customer role claims never grant permissions.'}},
    '/v1/admin/access-requests':{post:{operationId:'createStaffAccessRequest',security:[{nativeAppSession:[]}],parameters:[origin],requestBody:body(ref('StaffEmptyBody')),responses:responses(ref('StaffAccessRequest')),description:'Creates a pending verified account reference for explicit offline owner provisioning. No client identity, role or target ID is accepted. Does not grant access.'}},
    '/v1/admin/access-requests/current':{get:{operationId:'getCurrentStaffAccessRequest',security:[{nativeAppSession:[]}],parameters:[origin],responses:responses(ref('StaffAccessRequest')),description:'Returns only the current account/device authentication-lineage request. Missing or expired requests return404 STAFF_ACCESS_REQUEST_NOT_FOUND.'}},
    '/v1/admin/session':{get:{operationId:'getStaffSession',responses:responses(ref('StaffSession')),description:'Revalidates the provider identity and local principal/session/grants. Returns minimal staff authority plus a session-bound CSRF token.'}},
    '/v1/admin/auth/logout':{post:{operationId:'logoutStaffSession',parameters:[origin,csrfHeader],requestBody:body(ref('StaffEmptyBody')),responses:responses(ref('StaffLogout')),description:'Revokes every session for this staff principal and clears the presented cookie. Customer authentication and modes remain separate.'}},
  },
  components:{securitySchemes:{
    nativeAppSession:{type:'http',scheme:'bearer',description:'Current registered Firebase phone app session. Native HTTP only; never supplied to the embedded browser.'},
    staffSession:{type:'apiKey',in:'cookie',name:'__Host-nightshift_staff',description:'Random opaque credential; Secure, HttpOnly, SameSite=Strict, Path=/, no Domain.'},
    staffChallenge:{type:'apiKey',in:'cookie',name:'__Host-nightshift_staff_challenge',description:'Short-lived opaque challenge; Secure, HttpOnly, SameSite=Strict, Path=/, no Domain.'},
  },schemas},
};
const url = new URL('staff.openapi.json',import.meta.url);
const content = JSON.stringify(contract,null,2)+'\n';
if(process.argv.includes('--check')) {
  if(await readFile(url,'utf8')!==content) throw new Error('staff.openapi.json needs regeneration');
} else await writeFile(url,content);
