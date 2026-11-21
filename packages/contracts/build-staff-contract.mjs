import { readFile, writeFile } from 'node:fs/promises';

const object = (properties, required = Object.keys(properties)) => ({type:'object', properties, required, additionalProperties:false});
const ref = name => ({$ref:`#/components/schemas/${name}`});
const timestamp = {type:'string',format:'date-time'};
const csrf = {type:'string',pattern:'^[0-9a-f]{64}$'};
const permission = {type:'string',enum:['listener.review.read','listener.review.evidence.read','listener.review.decide','staff.access.manage']};
const reviewCursor = {type:'string',pattern:'^[A-Za-z0-9_-]+\\.[a-f0-9]{64}$',maxLength:2048};
const languages = {type:'array',items:{type:'string',enum:['ta','en']},minItems:1,maxItems:2,uniqueItems:true};
const reviewCard = {id:{type:'string',format:'uuid'},alias:{type:'string',minLength:1,maxLength:80},state:{type:'string',const:'submitted'},languages,submittedAt:timestamp};
const slug={type:'string',pattern:'^[a-z][a-z0-9_]{0,63}$'};
const boundedText=max=>({type:'string',minLength:1,maxLength:max,pattern:'^[^\\u0000-\\u001f\\u007f]+$'});
const label=object({en:boundedText(160),ta:boundedText(160)});
const evidence={type:'array',items:{type:'string',enum:['application','voice_sample','self_declaration']},maxItems:3,uniqueItems:true};
const outcome={type:'string',enum:['approved','rejected','needs_information']};
const reasonList={type:'array',minItems:1,maxItems:20,items:object({code:slug,label})};
const finding=object({id:slug,result:{type:'string',enum:['pass','fail','not_checked']},evidenceKinds:evidence});
const schemas = {
  StaffAuthStatus: object({configured:{type:'boolean'},available:{type:'boolean'},reasonCode:{type:['string','null'],enum:['STAFF_AUTH_UNAVAILABLE',null]}}),
  StaffChallenge: object({csrfToken:csrf,expiresAt:timestamp}),
  StaffExchange: object({proof:{type:'string',minLength:1,maxLength:16384}}),
  StaffSession: object({staff:object({id:{type:'string',format:'uuid'}}),permissions:{type:'array',items:permission,maxItems:4,uniqueItems:true},expiresAt:timestamp,csrfToken:csrf}),
  StaffAccessRequest: object({requestId:{type:'string',format:'uuid'},accountReference:{type:'string',format:'uuid'},status:{type:'string',enum:['pending','provisioned']},expiresAt:timestamp}),
  StaffLogout: object({signedOut:{type:'boolean',const:true}}),
  StaffEmptyBody: object({}),
  StaffReviewQueue: object({items:{type:'array',maxItems:20,items:object({...reviewCard,voiceSampleAvailable:{type:'boolean'}})},nextCursor:{anyOf:[reviewCursor,{type:'null'}]},decisionsEnabled:{type:'boolean'}}),
  StaffReviewDetail: object({application:object({...reviewCard,bio:{type:'string',maxLength:1000},topics:{type:'array',items:{type:'string',enum:['everyday','work','study','hobbies','language-practice']},maxItems:5,uniqueItems:true},
    materialVersion:csrf,adultStatus:{type:'string',const:'self_declared'},voiceSample:{anyOf:[object({contentType:{type:'string',const:'audio/wav'},byteLength:{type:'integer',minimum:44,maximum:2097152}}),{type:'null'}]}}),decisionsEnabled:{type:'boolean'}}),
  StaffReviewPolicy:{oneOf:[object({enabled:{type:'boolean',const:false},reasonCode:{type:'string',const:'REVIEW_POLICY_UNAVAILABLE'}}),
    object({enabled:{type:'boolean',const:true},reasonCode:{type:'null'},version:boundedText(80),digest:csrf,checks:{type:'array',minItems:1,maxItems:20,items:object({id:slug,label,requiredForApproval:{type:'boolean'},evidenceKinds:{...evidence,minItems:1}})},reasons:object({approved:reasonList,rejected:reasonList,needs_information:reasonList})})]},
  StaffReviewDecision:object({expectedMaterialVersion:csrf,policyVersion:boundedText(80),policyDigest:csrf,outcome,checks:{type:'array',minItems:1,maxItems:20,items:finding},reasonCode:slug}),
  StaffReviewReceipt:object({decisionId:{type:'string',format:'uuid'},applicationId:{type:'string',format:'uuid'},outcome,policyVersion:boundedText(80),materialVersion:csrf,reasonCode:slug,recordedAt:timestamp,
    effects:object({entitlement:{type:'string',enum:['not_applicable','pending','active','withheld']},notification:{type:'string',enum:['pending','available','suppressed']}})}),
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
const reviewHeaders = {'Cache-Control':{schema:{type:'string',const:'no-store, private'}},Vary:{schema:{type:'string',const:'Cookie'}},'X-Content-Type-Options':{schema:{type:'string',const:'nosniff'}}};
const reviewResponses = schema => ({
  200:{description:'Submitted material only. No decisions or entitlements are changed.',headers:reviewHeaders,content:json(schema)},
  ...Object.fromEntries(Object.entries({400:'Invalid fields or owner/filter-bound cursor',401:'Staff or source app authority is revoked or expired',403:'Required read/evidence permission denied',404:'Application or sample is unavailable, restricted or known self',409:'Review material changed; reload detail',410:'Queue cursor expired; refresh queue',503:'Staff provider or private sample storage is unavailable or busy'})
    .map(([status,description])=>[status,{description,headers:noStore,content:json(ref('StaffError'))}]))
});
const applicationId = {name:'id',in:'path',required:true,schema:{type:'string',format:'uuid'}};
const decisionKey={name:'Idempotency-Key',in:'header',required:true,schema:{type:'string',minLength:1,maxLength:128,pattern:'^[^\\u0000-\\u001f\\u007f]+$'},description:'Stable key for one immutable command, scoped to the current staff principal and application. Never an authorization credential.'};
const sampleResponses = reviewResponses(ref('StaffError'));
sampleResponses[200] = {description:'Complete WAV at most2MiB. Range is ignored; no partial responses. Material version is a consistency value, never an authorization credential.',
  headers:{...reviewHeaders,'Content-Length':{schema:{type:'integer',minimum:44,maximum:2097152}},'Content-Disposition':{schema:{type:'string',const:'inline; filename="review-sample.wav"'}},'X-Review-Material-Version':{schema:csrf}},
  content:{'audio/wav':{schema:{type:'string',format:'binary'}}}};
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
    '/v1/admin/listener-applications':{get:{operationId:'getStaffReviewQueue',parameters:[{name:'language',in:'query',schema:{type:'string',enum:['ta','en']}},{name:'cursor',in:'query',schema:reviewCursor}],responses:reviewResponses(ref('StaffReviewQueue')),description:'Requires listener.review.read. Twenty submitted applications ordered by exact submitted timestamp and ID. Signed cursor binds staff session, language and five-minute cutoff; later removal may produce short pages. Known self and editable needs_information applications are excluded.'}},
    '/v1/admin/listener-applications/{id}':{get:{operationId:'getStaffReviewDetail',parameters:[applicationId],responses:reviewResponses(ref('StaffReviewDetail')),description:'Requires both listener.review.read and listener.review.evidence.read. No query fields accepted. Only current submitted private material and self-declared adult status; no DOB, phone, provider identity or financial fields.'}},
    '/v1/admin/listener-applications/{id}/voice-sample':{get:{operationId:'getStaffReviewSample',parameters:[applicationId,{name:'version',in:'query',required:true,schema:csrf}],responses:sampleResponses,description:'Requires both listener.review.read and listener.review.evidence.read. Reads private storage outside locks, then rechecks provider identity, local staff/app authority, applicant state/consent and byte integrity. One targeted access event records successful authorized access.'}},
    '/v1/admin/listener-review-policy':{get:{operationId:'getStaffReviewPolicy',responses:reviewResponses(ref('StaffReviewPolicy')),description:'Requires listener.review.read. Missing approved configuration returns enabled:false. No real checklist is bundled. Policy metadata is not permission to decide.'}},
    '/v1/admin/listener-applications/{id}/decisions':{post:{operationId:'recordStaffReviewDecision',parameters:[applicationId,origin,csrfHeader,decisionKey],requestBody:body(ref('StaffReviewDecision')),responses:reviewResponses(ref('StaffReviewReceipt')),description:'Requires read, evidence.read and decide permissions, current policy/material, explicit findings and policy-approved reason. All policy check IDs occur exactly once; pass/fail need permitted evidence, not_checked has none. Approval requires every mandatory check pass; rejection requires a failed check; needs_information requires a failed or unchecked check. Atomically records an immutable decision and durable effects; does not assert verified age/identity or turn availability on.'}},
    '/v1/admin/listener-applications/{id}/decision-receipt':{get:{operationId:'getStaffReviewDecisionReceipt',parameters:[applicationId,decisionKey],responses:reviewResponses(ref('StaffReviewReceipt')),description:'Requires current read, evidence.read and decide permissions. Recovers the current principal/application/key result after uncertain delivery, including after terminal application state or policy disabled. Missing receipt returns404 REVIEW_DECISION_NOT_FOUND. Never retries the mutation.'}},
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
