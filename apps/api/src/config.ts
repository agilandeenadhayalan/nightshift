export interface Config {
  databaseUrl: string; redisUrl: string; port: number; devAccessKey: string;
  agoraAppId?: string; agoraAppCertificate?: string;
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
  return { databaseUrl: env.DATABASE_URL, redisUrl: env.REDIS_URL, port,
    devAccessKey: env.DEV_ACCESS_KEY!, agoraAppId: env.AGORA_APP_ID,
    agoraAppCertificate: env.AGORA_APP_CERTIFICATE };
}
