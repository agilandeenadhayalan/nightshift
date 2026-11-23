import { readFile, writeFile } from 'node:fs/promises';
const str={type:'string'}, bool={type:'boolean'}, integer={type:'integer'}, id={type:'string',format:'uuid'};
const date={type:'string',format:'date-time'}, nullableDate={type:['string','null'],format:'date-time'};
const ref=name=>({$ref:`#/components/schemas/${name}`});
const array=items=>({type:'array',items});
const object=(properties,required=Object.keys(properties))=>({type:'object',properties,required,additionalProperties:false});
const avatarCode={type:'string',enum:['moon','star','leaf','wave',...['male','female'].flatMap(prefix=>Array.from({length:30},(_,i)=>`${prefix}_${String(i+1).padStart(2,'0')}`))]};
const mediaType={type:'string',enum:['audio','video']};
const schemas={
  ListenerAvailability:object({online:{...bool,description:'Saved master availability intent; not a presence or provider capability proof.'},audioEnabled:bool,videoEnabled:bool}),
  User:object({id,displayName:str,languages:array({type:'string',enum:['ta','en']}),mode:{type:'string',enum:['customer','listener']},listenerApproved:bool,online:bool}),
  Rate:object({id:{enum:['test-audio-v1','test-video-v1'],type:'string'},coinsPerMinute:integer,microcreditsPerCoin:integer,microcreditsPerSecond:integer,freeThroughSeconds:integer,minimumChargedSeconds:integer,listenerPaisePerHour:integer,testOnly:{const:true,type:'boolean'}}),
  Wallet:object({balanceMicrocredits:integer,heldMicrocredits:integer,availableMicrocredits:integer,testOnly:{const:true,type:'boolean'}}),
  Listener:object({id,displayName:str,languages:array({type:'string',enum:['ta','en']}),online:bool,reachability:{type:'string',enum:['foreground','background_eligible','offline']},available:bool,busy:bool,favorite:bool,testOnly:bool,rate:ref('Rate')}),
  Call:object({id,customerId:id,listenerId:id,customerName:str,listenerName:str,state:{type:'string',enum:['ringing','connecting','connected','reconnecting','ended']},version:integer,
    createdAt:date,expiresAt:date,acceptedAt:nullableDate,endedAt:nullableDate,reason:{type:['string','null']},connectedMs:integer,chargeMicrocredits:integer,earningPaise:integer,rate:ref('Rate'),maxDurationSeconds:integer,testOnly:{const:true,type:'boolean'}}),
  Snapshot:object({user:ref('User'),activeCall:{anyOf:[ref('Call'),{type:'null'}]},listeners:array(ref('Listener')),wallet:ref('Wallet'),serverTime:date}),
  CallPage:object({items:array(ref('Call')),nextCursor:{type:['string','null'],format:'uuid'}}),
  CreateMatchingRequest:object({language:{type:'string',enum:['ta','en']},mediaType:{type:'string',const:'audio'},quoteId:{type:'string',minLength:1,maxLength:128},consent:{type:'boolean',const:true},consentVersion:{type:'string',const:'matching-search-v1'}}),
  CancelMatchingRequest:object({expectedVersion:{type:'integer',minimum:1}}),
  MatchingRequest:object({id,version:{type:'integer',minimum:1},state:{type:'string',enum:['searching','ringing','matched','cancelled','exhausted','expired','failed']},language:{type:'string',enum:['ta','en']},mediaType:{type:'string',const:'audio'},quoteId:{type:'string',minLength:1,maxLength:128},attemptCount:{type:'integer',minimum:0,maximum:3},maxAttempts:{type:'integer',const:3},waitBudgetSeconds:{type:'integer',const:90},invitationSeconds:{type:'integer',const:30},createdAt:date,deadlineAt:date,endedAt:nullableDate,currentCallId:{type:['string','null'],format:'uuid'},terminalReason:{type:['string','null'],enum:['no_supply','all_declined','attempts_exhausted','wait_budget_elapsed','customer_cancelled','source_session_ended','account_restricted','safety_blocked','insufficient_balance','quote_unavailable',null]},selectionReasons:{type:'array',maxItems:3,uniqueItems:true,items:{type:'string',enum:['language_match','currently_available','fair_rotation']}},serverTime:date,testOnly:{type:'boolean',const:true}}),
  CurrentMatchingRequest:object({request:{anyOf:[ref('MatchingRequest'),{type:'null'}]}}),
  PreparePushRegistration:object({targetKind:{type:'string',const:'fcm_token'},token:{type:'string',minLength:1,maxLength:4096,pattern:'^[!-~]+$'},expectedVersion:{type:['integer','null'],minimum:1}}),
  ActivatePushRegistration:object({registrationId:id,expectedVersion:{type:'integer',minimum:1},bindingId:id,notificationPermission:{type:'string',const:'granted'},backgroundInvitations:{type:'boolean',const:true},capabilityVersion:{type:'string',const:'android-audio-invitations-v1'},consentVersion:{type:'string',const:'background-invitations-v1'}}),
  RevokePushRegistration:object({registrationId:id,expectedVersion:{type:'integer',minimum:1}}),
  PushRegistration:object({id,version:{type:'integer',minimum:1},bindingId:id,targetKind:{type:'string',const:'fcm_token'},state:{type:'string',enum:['prepared','active','revoked','expired']},backgroundInvitations:bool,leaseExpiresAt:nullableDate,serverTime:date,testOnly:{type:'boolean',const:true}}),
  CurrentPushRegistration:object({registration:{anyOf:[ref('PushRegistration'),{type:'null'}]}}),
  CallInvitationPush:object({schemaVersion:{type:'string',const:'1'},type:{type:'string',enum:['call.invitation','call.terminal']},callId:id,eventId:id,callVersion:{type:'string',pattern:'^[1-9][0-9]{0,9}$'},expiresAt:date,registrationId:id,registrationVersion:{type:'string',pattern:'^[1-9][0-9]{0,9}$'},bindingId:id}),
  ListenerPage:object({items:array(ref('Listener')),nextCursor:{type:['string','null'],format:'uuid'},viewEpoch:id,expiresAt:date,serverTime:date,truncated:bool}),
  ListenerStatusRequest:object({language:{type:'string',enum:['ta','en']},listenerIds:{type:'array',maxItems:40,uniqueItems:true,items:id}}),
  ListenerStatuses:object({items:array(ref('Listener')),removedIds:array(id),serverTime:date}),
  DirectorySubscription:object({viewEpoch:id,language:{type:'string',enum:['ta','en']},visibleIds:{type:'array',maxItems:40,uniqueItems:true,items:id}}),
  DirectoryUpdate:object({viewEpoch:id,language:{type:'string',enum:['ta','en']},serverTime:date,items:array(ref('Listener')),removedIds:array(id)}),
  DirectoryInvalidated:object({viewEpoch:id,code:str}),
  Login:object({token:str,expiresAt:date,user:ref('User'),testOnly:{const:true,type:'boolean'}}),
  OtpRequest:object({phone:{type:'string',pattern:'^\\+91[6-9][0-9]{9}$'},deviceId:{type:'string',minLength:1,maxLength:128},consentVersion:{type:'string',minLength:1,maxLength:80}}),
  OtpVerifyRequest:object({challengeId:id,phone:{type:'string',pattern:'^\\+91[6-9][0-9]{9}$'},code:{type:'string',pattern:'^[0-9]{6}$'},deviceId:{type:'string',minLength:1,maxLength:128}}),
  FirebaseVerifyRequest:object({idToken:{type:'string',minLength:1,maxLength:16384}}),
  OtpChallenge:object({challengeId:id,state:{type:'string',enum:['sending','sent','verifying','consumed','expired','locked','send_unknown','verify_unknown','superseded']},expiresAt:date,retryAt:date}),
  OtpProof:object({customToken:str,userId:id,needsOnboarding:bool}),
  PhoneIdentity:object({userId:id,needsOnboarding:bool}),
  PhoneSessionRequest:object({idToken:{type:'string',minLength:1,maxLength:16384},deviceId:{type:'string',minLength:1,maxLength:128},attemptId:id},['idToken','deviceId']),
  FirebasePhoneAdmission:object({attemptId:id,expiresAt:date,retryAt:date}),
  PhoneSession:object({token:str,expiresAt:date,user:ref('User'),needsOnboarding:bool,testOnly:{const:true,type:'boolean'}}),
  OnboardingProfile:object({displayName:{type:'string',maxLength:40},avatarCode,interfaceLanguage:{type:'string',enum:['ta','en']},languages:{type:'array',minItems:1,maxItems:2,uniqueItems:true,items:{type:'string',enum:['ta','en']}},dateOfBirth:{type:['string','null'],format:'date'}}),
  OnboardingState:object({required:bool,profile:ref('OnboardingProfile')}),
  CompleteOnboardingRequest:object({displayName:{type:'string',minLength:2,maxLength:40},avatarCode,interfaceLanguage:{type:'string',enum:['ta','en']},languages:{type:'array',minItems:1,maxItems:2,uniqueItems:true,items:{type:'string',enum:['ta','en']}},dateOfBirth:{type:'string',format:'date'},consentVersion:{type:'string',enum:['adult-onboarding-v1']}}),
  ConsentEvent:object({id,purpose:str,noticeVersion:str,granted:bool,createdAt:date}),
  ConsentHistory:object({items:array(ref('ConsentEvent'))}),
  DeletionNotice:object({noticeVersion:{type:'string',const:'account-deletion-test-v1'},text:str,testOnly:{type:'boolean',const:true},retentionReviewRequired:{type:'boolean',const:true}}),
  DeletionRequest:object({noticeVersion:{type:'string',const:'account-deletion-test-v1'},confirm:{type:'boolean',const:true},receiptToken:{type:'string',pattern:'^[a-f0-9]{64}$'}}),
  DeletionReceiptRequest:object({receiptToken:{type:'string',pattern:'^[a-f0-9]{64}$'}}),
  DeletionReceipt:object({requestId:id,status:{type:'string',enum:['pending_hold','review_required']},requestedAt:date,personalDataDeletedAt:nullableDate,holds:array(str),noticeVersion:{type:'string',const:'account-deletion-test-v1'},testOnly:{type:'boolean',const:true},retentionReviewRequired:{type:'boolean',const:true}}),
  ListenerApplicationInput:object({bio:{type:'string',maxLength:1000},topics:{type:'array',maxItems:5,uniqueItems:true,items:{type:'string',enum:['everyday','work','study','hobbies','language-practice']}},languages:{type:'array',minItems:1,maxItems:2,uniqueItems:true,items:{type:'string',enum:['ta','en']}},voiceSampleConsent:bool,consentVersion:{type:'string',const:'listener-review-v1'}}),
  ListenerApplication:object({id,state:{type:'string',enum:['draft','submitted','needs_information','approved','rejected','withdrawn']},bio:str,topics:array({type:'string',enum:['everyday','work','study','hobbies','language-practice']}),languages:array({type:'string',enum:['ta','en']}),voiceSampleConsent:bool,consentVersion:{type:['string','null']},voiceSampleUploadId:{type:['string','null'],format:'uuid'},submittedAt:nullableDate,decidedAt:nullableDate,updatedAt:date}),
  ListenerApplicationState:object({application:{anyOf:[ref('ListenerApplication'),{type:'null'}]}}),
  ReviewLocalizedText:object({en:{type:'string',minLength:1,maxLength:500},ta:{type:'string',minLength:1,maxLength:500}}),
  ReviewMissingCheck:object({id:{type:'string',minLength:1,maxLength:80},label:object({en:{type:'string',minLength:1,maxLength:160},ta:{type:'string',minLength:1,maxLength:160}})}),
  ListenerReviewNotice:object({id,createdAt:date}),
  ListenerReviewOutcome:object({applicationId:id,decisionId:id,outcome:{type:'string',enum:['approved','rejected','needs_information']},reasonCode:{type:'string',minLength:1,maxLength:80},message:ref('ReviewLocalizedText'),missingChecks:{type:'array',maxItems:20,items:ref('ReviewMissingCheck')},recordedAt:date,entitlement:{type:'string',enum:['not_applicable','pending','active','withheld']},notification:{anyOf:[ref('ListenerReviewNotice'),{type:'null'}]}}),
  ListenerReviewState:object({applicationId:{type:['string','null'],format:'uuid'},state:{type:['string','null'],enum:['draft','submitted','needs_information','approved','rejected','withdrawn',null]},review:{anyOf:[ref('ListenerReviewOutcome'),{type:'null'}]}}),
  ReviewUploadRequest:object({contentType:{type:'string',const:'audio/wav'},byteLength:{type:'integer',minimum:44,maximum:2097152},sha256:{type:'string',pattern:'^[a-f0-9]{64}$'}}),
  ReviewUpload:object({uploadId:id,uploadToken:str,expiresAt:date,maxBytes:{type:'integer',const:2097152},contentType:{type:'string',const:'audio/wav'}}),
  RtcToken:object({appId:str,channel:str,uid:{type:'integer',enum:[1,2]},remoteUid:{type:'integer',enum:[1,2]},token:str,expiresAt:date}),
  RtcConfig:object({appId:{type:['string','null']},videoEnabled:bool,testOnly:{const:true,type:'boolean'}}),
  Error:object({error:object({code:str,message:str,retryAfterSeconds:{type:'integer',minimum:1}},['code','message']),requestId:id}),
  Event:object({id,type:{type:'string',enum:['call.invited','call.state_changed']},entityId:id,version:integer,timestamp:date,data:ref('Call')})
};
// Additive optional fields preserve old durable event/idempotency payloads.
schemas.User.properties.avatarCode=avatarCode;
schemas.User.properties.availability=ref('ListenerAvailability');
schemas.Listener.properties.avatarCode=avatarCode;
schemas.Listener.properties.audioAvailable={...bool,description:'Effective audio invitation eligibility, including saved preference, reachability and busy state.'};
schemas.Listener.properties.videoAvailable={...bool,description:'Effective video invitation eligibility, including saved preference, foreground reachability, server capability and busy state.'};
schemas.Call.properties.customerAvatarCode=avatarCode;
schemas.Call.properties.listenerAvatarCode=avatarCode;
schemas.Call.properties.mediaType=mediaType;
schemas.Call.properties.durationLimitReason={type:'string',enum:['test_credit_balance','test_duration_cap'],description:'Reason for the frozen connected-time allowance at reservation. May be absent on legacy events and idempotent responses.'};
schemas.RtcToken.properties.mediaType=mediaType;
schemas.Listener.properties.videoRate={anyOf:[ref('Rate'),{type:'null'}]};
const responses=schema=>({200:{description:'Authoritative response',content:{'application/json':{schema}}},400:{description:'Validation failed',content:{'application/json':{schema:ref('Error')}}},401:{description:'Session is missing, expired or revoked',content:{'application/json':{schema:ref('Error')}}},403:{description:'Role or participant access denied',content:{'application/json':{schema:ref('Error')}}},404:{description:'Resource is missing or not visible to this participant',content:{'application/json':{schema:ref('Error')}}},409:{description:'State, eligibility or idempotency conflict',content:{'application/json':{schema:ref('Error')}}},429:{description:'Request rate limit exceeded',content:{'application/json':{schema:ref('Error')}}},503:{description:'Dependency or RTC configuration unavailable',content:{'application/json':{schema:ref('Error')}}}});
const pathId={name:'id',in:'path',required:true,schema:id};
const idempotency={name:'Idempotency-Key',in:'header',required:true,schema:{type:'string',minLength:1,maxLength:128}};
const json=schema=>({required:true,content:{'application/json':{schema}}});
const identityResponses=schema=>({...responses(schema),410:{description:'OTP challenge expired',content:{'application/json':{schema:ref('Error')}}}});
const reviewResponses=schema=>({...responses(schema),410:{description:'Private upload lease expired',content:{'application/json':{schema:ref('Error')}}},413:{description:'Private sample exceeds the 2 MiB limit',content:{'application/json':{schema:ref('Error')}}}});
const directoryParameters=[{name:'language',in:'query',schema:{type:'string',enum:['ta','en'],default:'ta'}},{name:'availableOnly',in:'query',schema:{type:'boolean',default:false}},{name:'cursor',in:'query',schema:id}];
const directoryResponses={...responses(ref('ListenerPage')),410:{description:'Directory view expired; explicitly refresh without a cursor',content:{'application/json':{schema:ref('Error')}}}};
const paths={
  '/v1/health':{get:{operationId:'health',security:[],responses:responses(object({status:str,service:str,testOnly:bool}))}},
  '/v1/auth/dev':{post:{operationId:'developmentSignIn',security:[],description:'Development/test only. Server refuses production boot.',requestBody:json(object({handle:{type:'string',enum:['customer','customer2','listener']},accessKey:{type:'string',minLength:24},deviceId:str})),responses:responses(ref('Login'))}},
  '/v1/auth/otp/request':{post:{operationId:'requestOtpChallenge',security:[],parameters:[idempotency],description:'Disabled by default. Requires server-configured provider validation. Explicit versioned consent; never an app session.',requestBody:json(ref('OtpRequest')),responses:identityResponses(ref('OtpChallenge'))}},
  '/v1/auth/otp/verify':{post:{operationId:'verifyOtpChallenge',security:[],description:'Consumes one challenge and returns a Firebase custom token, which must be exchanged for an ID token in the Firebase client. No app permissions or adult approval are granted.',requestBody:json(ref('OtpVerifyRequest')),responses:identityResponses(ref('OtpProof'))}},
  '/v1/auth/firebase/verify':{post:{operationId:'verifyPhoneIdentity',security:[],description:'Verifies a Firebase ID token including revocation and its existing MSG91 identity binding. Returns an identity receipt, not an app session; onboarding and session integration remain separate.',requestBody:json(ref('FirebaseVerifyRequest')),responses:identityResponses(ref('PhoneIdentity'))}},
  '/v1/auth/exchange':{post:{operationId:'exchangePhoneSession',security:[],description:'Registers a provider-verified ID token and device. Returns restricted access until adult onboarding completes. Every phone-session request checks Firebase revocation and local authorization. No credits or Listener approval are granted.',requestBody:json(ref('PhoneSessionRequest')),responses:responses(ref('PhoneSession'))}},
  '/v1/auth/firebase/admissions':{post:{operationId:'requestFirebasePhoneAdmission',security:[],parameters:[idempotency],description:'Versioned consent and bounded app-level admission before native Firebase Phone Authentication. Does not send an SMS and cannot hard-limit direct Firebase SDK SMS requests. Enrollment requires matching fresh phone-provider proof within five minutes.',requestBody:json(ref('OtpRequest')),responses:identityResponses(ref('FirebasePhoneAdmission'))}},
  '/v1/me/onboarding':{get:{operationId:'getOnboarding',description:'Owner-only profile and onboarding state. Available to restricted onboarding sessions; date of birth is never public.',responses:responses(ref('OnboardingState'))},put:{operationId:'completeOnboarding',description:'Atomically record an immutable adult date of birth, private proposed nickname, built-in avatar, separate UI/speaking languages, and versioned development consent. Pending nicknames are not published.',requestBody:json(ref('CompleteOnboardingRequest')),responses:responses(ref('OnboardingState'))}},
  '/v1/me/consents':{get:{operationId:'getConsentHistory',description:'Owner-only recorded consent purposes and notice versions, including restricted onboarding accounts.',responses:responses(ref('ConsentHistory'))}},
  '/v1/me/deletion-notice':{get:{operationId:'getDeletionNotice',description:'Development-only deletion effects and explicit retention limits before confirmation.',responses:responses(ref('DeletionNotice'))}},
  '/v1/me/deletion-requests':{post:{operationId:'requestAccountDeletion',description:'Requires provider authentication within five minutes. Withdraws account access and records deletion, retaining financial/dispute evidence for review. Client generates and securely persists a random 32-byte hex receipt capability before submitting.',requestBody:json(ref('DeletionRequest')),responses:responses(ref('DeletionReceipt'))}},
  '/v1/account-deletion/status':{post:{operationId:'getDeletionReceipt',security:[],description:'A private receipt capability reveals only deletion status after account sessions have been revoked. Never include it in URLs or diagnostics.',requestBody:json(ref('DeletionReceiptRequest')),responses:responses(ref('DeletionReceipt'))}},
  '/v1/listener-applications':{post:{operationId:'createListenerApplication',parameters:[idempotency],description:'Owner-only draft with explicit review-sample consent. A voice sample never proves age or gender.',requestBody:json(ref('ListenerApplicationInput')),responses:responses(ref('ListenerApplication'))}},
  '/v1/me/listener-application':{get:{operationId:'getListenerApplication',responses:responses(ref('ListenerApplicationState'))}},
  '/v1/me/listener-application/review':{get:{operationId:'getListenerApplicationReview',description:'Owner-only safe decision result and durable in-app notice. Approval is distinct from active Listener entitlement; no staff notes or evidence are returned.',responses:responses(ref('ListenerReviewState'))}},
  '/v1/listener-applications/{id}':{put:{operationId:'updateListenerApplication',parameters:[pathId],requestBody:json(ref('ListenerApplicationInput')),responses:responses(ref('ListenerApplication'))}},
  '/v1/listener-applications/{id}/uploads':{post:{operationId:'createReviewUpload',parameters:[pathId,idempotency],description:'Five-minute owner-bound upload lease. Private PCM WAV, 2–60 seconds, at most 2 MiB. No public URL.',requestBody:json(ref('ReviewUploadRequest')),responses:reviewResponses(ref('ReviewUpload'))}},
  '/v1/listener-applications/{id}/uploads/{uploadId}':{
    put:{operationId:'uploadListenerSample',parameters:[pathId,{name:'uploadId',in:'path',required:true,schema:id},{name:'X-Upload-Token',in:'header',required:true,schema:str}],requestBody:{required:true,content:{'audio/wav':{schema:{type:'string',format:'binary',maxLength:2097152}}}},responses:reviewResponses(ref('ListenerApplication'))},
    get:{operationId:'readListenerSample',parameters:[pathId,{name:'uploadId',in:'path',required:true,schema:id}],description:'Authenticated applicant-only private sample; never a public capability URL.',responses:{...responses(ref('Error')),200:{description:'Private PCM WAV sample',content:{'audio/wav':{schema:{type:'string',format:'binary'}}}}}}
  },
  '/v1/listener-applications/{id}/submit':{post:{operationId:'submitListenerApplication',parameters:[pathId,idempotency],responses:responses(ref('ListenerApplication'))}},
  '/v1/listener-applications/{id}/withdraw':{post:{operationId:'withdrawListenerApplication',parameters:[pathId,idempotency],responses:responses(ref('ListenerApplication'))}},
  '/v1/auth/logout':{post:{operationId:'signOut',responses:responses(object({signedOut:bool}))}},
  '/v1/me':{get:{operationId:'getMe',responses:responses(ref('User'))}},
  '/v1/snapshot':{get:{operationId:'getSnapshot',parameters:[{name:'language',in:'query',schema:{type:'string',enum:['ta','en'],default:'ta'}}],responses:responses(ref('Snapshot'))}},
  '/v1/me/mode':{put:{operationId:'setMode',requestBody:json(object({mode:{type:'string',enum:['customer','listener']}})),responses:responses(ref('User'))}},
  '/v1/me/availability':{put:{operationId:'setAvailability',requestBody:json(object({online:bool,audioEnabled:bool,videoEnabled:bool},['online'])),responses:responses(ref('User'))}},
  '/v1/me/languages':{put:{operationId:'setLanguages',requestBody:json(object({languages:array({type:'string',enum:['ta','en']})})),responses:responses(ref('User'))}},
  '/v1/presence/heartbeat':{post:{operationId:'heartbeat',responses:responses(object({serverTime:date}))}},
  '/v1/listeners':{get:{operationId:'listListeners',parameters:directoryParameters,description:'Twenty-card pages from a five-minute owner/filter-bound frozen view. Live eligibility is rechecked without reranking; refresh creates a new view. At most four active views per owner and 2000 IDs per view. A truncated view must not be presented as complete or as proof of no language supply.',responses:directoryResponses}},
  '/v1/favorites':{get:{operationId:'listFavorites',parameters:directoryParameters,description:'Private favorite listeners with current eligibility and presence, using the same frozen-view pagination as Discover.',responses:directoryResponses}},
  '/v1/listeners/status':{post:{operationId:'getListenerStatuses',requestBody:json(ref('ListenerStatusRequest')),description:'Current status for at most 40 own favorites, served view members or historical Listener counterparts. Unknown/ineligible IDs are removed without revealing account details. Historical call outcomes are separate.',responses:responses(ref('ListenerStatuses'))}},
  '/v1/calls':{
    get:{operationId:'listCalls',parameters:[{name:'cursor',in:'query',schema:id}],responses:responses(ref('CallPage'))},
    post:{operationId:'createCall',parameters:[idempotency],requestBody:json(object({listenerId:id,quoteId:{type:'string',enum:['test-audio-v1','test-video-v1']},mediaType,videoConsent:bool},['listenerId','quoteId'])),responses:responses(ref('Call'))}
  },
  '/v1/matches':{post:{operationId:'createMatchingRequest',parameters:[idempotency],description:'Explicit audio-only opt-in: at most three sequential invitations within a single 90-second deadline. Search and ringing are uncharged; existing test-credit call tariff applies after connection. Preserve this key and body on uncertain delivery; recover own current request before an explicit retry.',requestBody:json(ref('CreateMatchingRequest')),responses:responses(ref('MatchingRequest'))}},
  '/v1/me/match':{get:{operationId:'getCurrentMatchingRequest',description:'Authoritative owner-only current/latest matching request. Reading never creates a new search or invitation. Poll at most once per second while active; recover after resume.',responses:responses(ref('CurrentMatchingRequest'))}},
  '/v1/me/push/registration':{get:{operationId:'getPushRegistration',responses:responses(ref('CurrentPushRegistration'))},put:{operationId:'preparePushRegistration',parameters:[idempotency],description:'Prepare a current verified-device registration. Token is write-only; install the native binding durably before explicit activation. Unknown outcomes require a read before explicit retry.',requestBody:json(ref('PreparePushRegistration')),responses:responses(ref('PushRegistration'))},delete:{operationId:'revokePushRegistration',parameters:[idempotency],requestBody:json(ref('RevokePushRegistration')),responses:responses(ref('PushRegistration'))}},
  '/v1/me/push/registration/activate':{post:{operationId:'activatePushRegistration',parameters:[idempotency],description:'Explicit bounded audio-invitation opt-in after native binding installation. Does not enable ongoing background audio or prove notification delivery. Same-key replay never renews a lease.',requestBody:json(ref('ActivatePushRegistration')),responses:responses(ref('PushRegistration'))}},
  '/v1/matches/{id}':{get:{operationId:'getMatchingRequest',parameters:[pathId],responses:responses(ref('MatchingRequest'))}},
  '/v1/matches/{id}/cancel':{post:{operationId:'cancelMatchingRequest',parameters:[pathId,idempotency],description:'Cancel only this search. An acceptance winning the race returns matched and must not be translated into ending the accepted call.',requestBody:json(ref('CancelMatchingRequest')),responses:responses(ref('MatchingRequest'))}},
  '/v1/calls/{id}':{get:{operationId:'getCall',parameters:[pathId],responses:responses(ref('Call'))}},
  '/v1/calls/{id}/media':{post:{operationId:'reportMediaReady',parameters:[pathId],description:'Report only local/remote RTC readiness. Video calls require videoReady and both audio and video readiness. No client duration or price. Heartbeat every two seconds; not provider proof.',requestBody:json(object({ready:bool,videoReady:bool},['ready'])),responses:responses(ref('Call'))}},
  '/v1/calls/{id}/rtc-token':{post:{operationId:'getRtcToken',parameters:[pathId],responses:responses(ref('RtcToken'))}},
  '/v1/rtc/config':{get:{operationId:'getRtcConfig',description:'Authenticated private-video preview configuration. Contains a public app ID only when video is enabled; never a certificate or channel token.',responses:responses(ref('RtcConfig'))}},
  '/v1/rates':{get:{operationId:'getRates',responses:responses(object({items:array(ref('Rate'))}))}},
  '/v1/wallet':{get:{operationId:'getWallet',responses:responses(ref('Wallet'))}},
  '/v1/me/earnings':{get:{operationId:'getTestEarnings',responses:responses(object({illustrativePaise:integer,availablePaise:integer,paidPaise:integer,testOnly:bool,listenerPaisePerHour:integer}))}},
  '/v1/reports':{post:{operationId:'createReport',parameters:[idempotency],requestBody:json(object({callId:id,reason:{type:'string',minLength:1,maxLength:1000}})),responses:responses(object({id,status:str}))}},
  '/v1/blocks/{id}':{put:{operationId:'blockUser',parameters:[pathId],responses:responses(object({blocked:bool}))}},
  '/v1/events':{get:{operationId:'getEvents',parameters:[{name:'cursor',in:'query',schema:id}],responses:responses(object({items:array(ref('Event')),nextCursor:{type:['string','null'],format:'uuid'}}))}}
};
for(const action of ['accept','decline','cancel','end'])paths[`/v1/calls/{id}/${action}`]={post:{operationId:`${action}Call`,parameters:[pathId,idempotency],requestBody:json(object(action==='accept'?{expectedVersion:integer,videoConsent:bool}:{expectedVersion:integer},['expectedVersion'])),responses:responses(ref('Call'))}};
paths['/v1/favorites/{id}']={put:{operationId:'favoriteListener',parameters:[pathId],responses:responses(object({favorite:bool}))},delete:{operationId:'unfavoriteListener',parameters:[pathId],responses:responses(object({favorite:bool}))}};
// Nest defaults POST to 201. Describe actual statuses so generated clients accept the response.
for(const route of Object.values(paths))for(const [method,operation] of Object.entries(route))if(method==='post'&&operation.responses[200]){operation.responses[201]=operation.responses[200];delete operation.responses[200];}
const contract={openapi:'3.1.0',info:{title:'NightShift Android test milestone',version:'0.1.0',description:'One shared backend; fictional test credits only. Real-money and production identity adapters are disabled.'},servers:[{url:'http://localhost:3000'}],security:[{bearerAuth:[]}],paths,components:{securitySchemes:{bearerAuth:{type:'http',scheme:'bearer'}},schemas}};
const event={$schema:'https://json-schema.org/draft/2020-12/schema',$defs:JSON.parse(JSON.stringify(schemas).replaceAll('#/components/schemas/','#/$defs/')),$ref:'#/$defs/Event',
  'x-socket-events':{'directory.subscribe':{schema:'#/$defs/DirectorySubscription',description:'Authenticated websocket auth.token; replaces the slice. null or empty visibleIds unsubscribes. ACK {ok:true,viewEpoch} or {ok:false,code}. Only served members of this owner/language epoch are accepted.'},
    'directory.updated':{schema:'#/$defs/DirectoryUpdate',description:'Only the subscribed visible IDs. Live status changes immediately; preserve order until explicit refresh. Changed payloads checked each second; freshness at least every 15 seconds while healthy.'},
    'directory.invalidated':{schema:'#/$defs/DirectoryInvalidated',description:'Expired, denied or unavailable subscription; mark stale and refresh explicitly.'}}};
for(const [file,value] of [['openapi.json',contract],['events.schema.json',event]]){
  const url=new URL(file,import.meta.url),content=JSON.stringify(value,null,2)+'\n';
  if(process.argv.includes('--check')){if(await readFile(url,'utf8')!==content)throw new Error(`${file} needs regeneration`);}
  else await writeFile(url,content);
}
// Staff remains a separate cookie-authenticated contract and is deliberately
// excluded from the Customer/Listener Dart client generation input.
await import('./build-staff-contract.mjs');
