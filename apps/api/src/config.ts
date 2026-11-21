import { isAbsolute } from 'node:path';

export interface Config {
  databaseUrl: string; redisUrl: string; port: number; devAccessKey: string;
  agoraAppId?: string; agoraAppCertificate?: string;
  videoCallsEnabled?: boolean;
  privateReviewDirectory?: string;
  staffReviewPolicyFile?: string;
  staffAuth?: {origin:string;digestKey:string;policyVersion:string;sessionSeconds:number};
  phoneAuth?: {
    provider?: 'msg91'|'firebase';
    projectId: string; digestKey: string; consentVersion: string;
    msg91WidgetId?: string; msg91AuthKey?: string; dailySendLimit?: number; dailyAdmissionLimit?: number;
  };
}

export function loadConfig(env = process.env): Config {
  // The current milestone has deliberately no production authentication/payments adapter.
  // Refuse the whole server, rather than accidentally expose fictional login in production.
  if (!['development', 'test'].includes(env.NODE_ENV ?? 'development')) {
    throw new Error('PRODUCTION_NOT_READY: this build is restricted to development and test');
  }
  if (env.DEV_AUTH_ENABLED !== 'true' || (env.DEV_ACCESS_KEY?.length ?? 0) < 24) {
    throw new Error('Set DEV_AUTH_ENABLED=true and a private DEV_ACCESS_KEY of at least 24 characters');
  }
  if (!env.DATABASE_URL || !env.REDIS_URL) throw new Error('DATABASE_URL and REDIS_URL are required');
  const port = Number(env.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw new Error('Invalid PORT');
  if (env.VIDEO_CALLS_ENABLED !== undefined && !['true', 'false'].includes(env.VIDEO_CALLS_ENABLED)) {
    throw new Error('VIDEO_CALLS_ENABLED must be true or false');
  }
  let phoneAuth: Config['phoneAuth'];
  const privateReviewDirectory=env.PRIVATE_REVIEW_STORAGE_DIR || undefined;
  if(privateReviewDirectory && !isAbsolute(privateReviewDirectory))throw new Error('PRIVATE_REVIEW_STORAGE_DIR must be an absolute private directory');
  if (env.PHONE_AUTH_ENABLED !== undefined && !['true', 'false'].includes(env.PHONE_AUTH_ENABLED)) {
    throw new Error('PHONE_AUTH_ENABLED must be true or false');
  }
  if (env.PHONE_AUTH_ENABLED === 'true') {
    if (env.FIREBASE_AUTH_EMULATOR_HOST !== undefined) throw new Error('Phone identity validation cannot use the Firebase emulator');
    const provider=env.PHONE_AUTH_PROVIDER??'msg91';
    if(!['msg91','firebase'].includes(provider))throw new Error('PHONE_AUTH_PROVIDER must be firebase or msg91');
    const dailySendLimit = Number(provider==='firebase'?env.PHONE_AUTH_DAILY_ADMISSION_LIMIT:env.PHONE_AUTH_DAILY_SEND_LIMIT);
    if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(env.FIREBASE_PROJECT_ID ?? '') ||
        (env.PHONE_AUTH_DIGEST_KEY?.length ?? 0) < 32 ||
        (env.PHONE_AUTH_DIGEST_KEY?.length ?? 0) > 256 ||
        !/^[A-Za-z0-9._-]{1,80}$/.test(env.PHONE_AUTH_CONSENT_VERSION ?? '') ||
        !Number.isSafeInteger(dailySendLimit) || dailySendLimit < 1 || dailySendLimit > 1000) {
      throw new Error('Phone identity validation requires valid project, stable digest key, consent version and explicit daily admission/send limit');
    }
    if(provider==='msg91' && (!/^[A-Za-z0-9_-]{8,128}$/.test(env.MSG91_WIDGET_ID??'') || !/^[!-~]{16,512}$/.test(env.MSG91_AUTH_KEY??'')))throw new Error('Legacy MSG91 requires valid MSG91_WIDGET_ID and MSG91_AUTH_KEY');
    phoneAuth = { projectId: env.FIREBASE_PROJECT_ID!, digestKey: env.PHONE_AUTH_DIGEST_KEY!,
      consentVersion: env.PHONE_AUTH_CONSENT_VERSION!, provider:provider as 'firebase'|'msg91',
      ...(provider==='firebase'?{dailyAdmissionLimit:dailySendLimit}:{msg91WidgetId:env.MSG91_WIDGET_ID!,msg91AuthKey:env.MSG91_AUTH_KEY!,dailySendLimit}) };
  }
  let staffAuth:Config['staffAuth'];
  if(env.STAFF_AUTH_ENABLED!==undefined&&!['true','false'].includes(env.STAFF_AUTH_ENABLED))throw new Error('STAFF_AUTH_ENABLED must be true or false');
  if(env.STAFF_AUTH_ENABLED==='true'){
    let origin:URL;try{origin=new URL(env.STAFF_CONSOLE_ORIGIN??'');}catch{throw new Error('Staff access requires an explicit HTTPS console origin');}
    const sessionSeconds=Number(env.STAFF_SESSION_SECONDS??1800);
    if(phoneAuth?.provider!=='firebase'||origin.protocol!=='https:'||origin.origin!==env.STAFF_CONSOLE_ORIGIN
      ||origin.username||origin.password||(env.STAFF_AUTH_DIGEST_KEY?.length??0)<32||(env.STAFF_AUTH_DIGEST_KEY?.length??0)>256
      ||!Number.isSafeInteger(sessionSeconds)||sessionSeconds<60||sessionSeconds>1800
      ||!/^[A-Za-z0-9._-]{1,80}$/.test(env.STAFF_AUTH_POLICY_VERSION??''))throw new Error('Staff access requires native Firebase, a stable private digest key, explicit policy version and bounded session configuration');
    staffAuth={origin:origin.origin,digestKey:env.STAFF_AUTH_DIGEST_KEY!,policyVersion:env.STAFF_AUTH_POLICY_VERSION!,sessionSeconds};
  }
  const staffReviewPolicyFile=env.STAFF_REVIEW_POLICY_FILE||undefined;
  if(staffReviewPolicyFile&&(!staffAuth||!isAbsolute(staffReviewPolicyFile)))throw new Error('STAFF_REVIEW_POLICY_FILE requires configured staff access and an absolute approved policy file');
  return { databaseUrl: env.DATABASE_URL, redisUrl: env.REDIS_URL, port,
    devAccessKey: env.DEV_ACCESS_KEY!, agoraAppId: env.AGORA_APP_ID,
    agoraAppCertificate: env.AGORA_APP_CERTIFICATE, videoCallsEnabled: env.VIDEO_CALLS_ENABLED === 'true', phoneAuth,privateReviewDirectory,staffAuth,staffReviewPolicyFile };
}
