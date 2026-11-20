// Real generated-Dart HTTP journey against an isolated schema and synthetic
// identity verifier. No SMS, cloud authentication, live accounts or real audio.
require('reflect-metadata');
const { randomBytes, randomUUID } = require('node:crypto');
const { spawn } = require('node:child_process');
const { mkdtemp, readdir, unlink, rmdir } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { Database } = require('../apps/api/dist/src/db');
const { migrate } = require('../apps/api/dist/src/migrate');
const { seed } = require('../apps/api/dist/src/seed');
const { createApplication } = require('../apps/api/dist/src/http');
const { ApiError } = require('../apps/api/dist/src/errors');

const root = path.resolve(__dirname, '..');
const schema = `account_client_${randomUUID().replaceAll('-', '')}`;
const issuer = 'isolated-account-client-fixture';
const token = `synthetic-${randomBytes(32).toString('hex')}`;
const userId = randomUUID();
const tempRoot = path.resolve(os.tmpdir());
let admin, setup, runtime, storage;

function fail(code) { throw Object.assign(new Error(), { code }); }
function runDart(base) {
  const dart = process.env.DART_BIN || (process.platform === 'win32'
    ? path.join(process.env.LOCALAPPDATA, 'flutter', 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe') : 'dart');
  return new Promise(resolve => {
    const child = spawn(dart, ['run', 'tool/smoke_account_client.dart'], {
      cwd: path.join(root, 'apps/mobile'), stdio: 'inherit', windowsHide: true,
      env: { ...process.env, API_BASE_URL: base, ACCOUNT_SMOKE_ISOLATED: 'true', ACCOUNT_SMOKE_TOKEN: token,
        DATABASE_URL: '', TEST_DATABASE_URL: '', POSTGRES_PASSWORD: '', DEV_ACCESS_KEY: '',
        GOOGLE_APPLICATION_CREDENTIALS: '', MSG91_AUTH_KEY: '', AGORA_APP_CERTIFICATE: '' },
    });
    let settled = false;
    const finish = code => { if (!settled) { settled = true; clearTimeout(timer); resolve(code); } };
    const timer = setTimeout(() => { child.kill(); finish(1); }, 90000);
    child.on('error', () => finish(1));
    child.on('exit', code => finish(code ?? 1));
  });
}

(async () => {
  if (process.env.NODE_ENV !== 'test' || !process.env.TEST_DATABASE_URL || !process.env.REDIS_URL) fail('ISOLATED_TEST_CONFIG_REQUIRED');
  const url = new URL(process.env.TEST_DATABASE_URL);
  const database = decodeURIComponent(url.pathname.slice(1));
  if (!/^[a-z0-9_]+_test$/.test(database)) fail('DEDICATED_TEST_DATABASE_REQUIRED');
  admin = new Database(url.toString());
  const selected = await admin.pool.query('SELECT current_database() name');
  if (selected.rows[0]?.name !== database) fail('DEDICATED_TEST_DATABASE_REQUIRED');
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  storage = await mkdtemp(path.join(tempRoot, 'nightshift-account-client-'));
  const config = { databaseUrl: url.toString(), redisUrl: process.env.REDIS_URL, port: 0,
    devAccessKey: 'isolated-account-client-key-only', privateReviewDirectory: storage,
    phoneAuth: { projectId: issuer, digestKey: randomBytes(32).toString('hex'),
      consentVersion: 'phone-signin-v1', msg91WidgetId: 'fixture', msg91AuthKey: 'fixture', dailySendLimit: 1 } };
  setup = new Database(config.databaseUrl);
  await migrate(setup); await seed(setup);
  await setup.tx(async c => {
    await c.query("INSERT INTO users(id,display_name,adult_confirmed) VALUES($1,'New customer',false)", [userId]);
    const identity = randomUUID();
    await c.query("INSERT INTO auth_identities(id,user_id,provider,issuer,subject_digest) VALUES($1,$2,'phone:msg91',$3,$4)",
      [identity, userId, issuer, randomBytes(32).toString('hex')]);
    await c.query("UPDATE auth_identities SET state='verified',verified_at=now() WHERE id=$1", [identity]);
  });
  await setup.close(); setup = undefined;
  const issued = Math.floor(Date.now() / 1000);
  runtime = await createApplication(config, Date.now, { otp: {
    async request() { fail('NO_SMS_IN_SMOKE'); }, async verify() { fail('NO_SMS_IN_SMOKE'); },
  }, firebase: { async verifyIdToken(raw) {
    if (raw !== token) throw new ApiError(401, 'INVALID_ID_TOKEN', 'Sign in again.');
    return { uid: userId, issuer: `https://securetoken.google.com/${issuer}`, audience: issuer,
      authTime: issued, issuedAt: issued, expiresAt: issued + 3600 };
  } } });
  await runtime.app.listen(0, '127.0.0.1');
  const status = await runDart(await runtime.app.getUrl());
  if (status) fail('GENERATED_ACCOUNT_CLIENT_FAILED');
  if ((await readdir(storage)).length) fail('PRIVATE_FILES_REMAIN_AFTER_DELETION');
  const remaining = await runtime.db.pool.query(`SELECT
    (SELECT count(*) FROM profiles WHERE user_id=$1)::int profiles,
    (SELECT count(*) FROM devices WHERE user_id=$1)::int devices,
    (SELECT count(*) FROM auth_sessions WHERE user_id=$1)::int sessions`, [userId]);
  if (Object.values(remaining.rows[0]).some(value => value !== 0)) fail('PRIVATE_RECORDS_REMAIN_AFTER_DELETION');
  console.log(JSON.stringify({ accountPrivateCleanup: 'passed' }));
})().catch(error => {
  console.error(JSON.stringify({ errorCode: /^[A-Z0-9_]{1,80}$/.test(error.code || '') ? error.code : 'ISOLATED_ACCOUNT_SMOKE_FAILED' }));
  process.exitCode = 1;
}).finally(async () => {
  let failed = false;
  try { if (runtime) await runtime.close(); } catch { failed = true; }
  try { if (setup) await setup.close(); } catch { failed = true; }
  if (admin) {
    try { await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); } catch { failed = true; }
    try { await admin.close(); } catch { failed = true; }
  }
  if (storage) {
    try {
      // Only individual files in the directory this process created. No recursive
      // deletion and no path derived from a customer or untrusted filename.
      if (path.dirname(path.resolve(storage)) !== tempRoot || !path.basename(storage).startsWith('nightshift-account-client-')) fail('UNSAFE_TEMP_DIRECTORY');
      for (const name of await readdir(storage)) {
        const file = path.resolve(storage, name);
        if (path.dirname(file) !== path.resolve(storage)) fail('UNSAFE_TEMP_FILE');
        await unlink(file);
      }
      await rmdir(storage);
    } catch { failed = true; }
  }
  console.log(JSON.stringify({ accountSmokeCleanup: failed ? 'failed' : 'passed' }));
  if (failed) process.exitCode = 1;
});
