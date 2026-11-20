// Opt-in integration evidence: owns only its random schema and Redis container.
// Build first; supply a dedicated TEST_DATABASE_URL whose name ends in _test.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const path = require('node:path');
const { createServer } = require('node:net');
const run = promisify(execFile);
const runtime = process.env.PRESENCE_TEST_RUNTIME_ROOT || path.resolve(__dirname, '..');
const { Database } = require(path.join(runtime, 'apps/api/dist/src/db'));
const { migrate } = require(path.join(runtime, 'apps/api/dist/src/migrate'));
const { seed } = require(path.join(runtime, 'apps/api/dist/src/seed'));
const { Presence } = require(path.join(runtime, 'apps/api/dist/src/presence'));
const { Auth } = require(path.join(runtime, 'apps/api/dist/src/auth'));
const { NightShiftService } = require(path.join(runtime, 'apps/api/dist/src/service'));
const schema = `restart_${randomUUID().replaceAll('-', '')}`;
const container = `nightshift-presence-restart-${randomUUID()}`;
let admin, db, presence, creationAttempted = false, stage = 'setup';
const docker = (...args) => run('docker', args, { windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024 });
async function until(check, timeout = 10000) {
  const deadline = Date.now() + timeout;
  do { try { if (await check()) return; } catch {} await new Promise(resolve => setTimeout(resolve, 100)); } while (Date.now() < deadline);
  throw new Error('Redis did not recover within deadline');
}
async function main() {
  assert.ok(process.env.TEST_DATABASE_URL, 'Set explicit TEST_DATABASE_URL');
  const url = new URL(process.env.TEST_DATABASE_URL);
  assert.match(decodeURIComponent(url.pathname.slice(1)), /^[a-z0-9_]+_test$/);
  assert.ok(['127.0.0.1', 'localhost'].includes(url.hostname), 'This probe requires local PostgreSQL');
  const reservation = createServer();
  await new Promise((resolve, reject) => { reservation.once('error', reject); reservation.listen(0, '127.0.0.1', resolve); });
  const reservedPort = reservation.address().port;
  await new Promise((resolve, reject) => reservation.close(error => error ? reject(error) : resolve()));
  // Request an explicit free host port so Docker keeps the endpoint on restart.
  creationAttempted = true;
  await docker('run', '--detach', '--name', container, '--label', 'nightshift.test=presence-restart',
    '--tmpfs', '/data:rw,size=16m', '--publish', `127.0.0.1:${reservedPort}:6379`,
    'redis:7.4.7-alpine', 'redis-server', '--save', '', '--appendonly', 'no');
  const { stdout } = await docker('port', container, '6379/tcp');
  const port = /^127\.0\.0\.1:(\d+)\s*$/.exec(stdout)?.[1];
  assert.ok(port, 'Expected a private loopback Redis port');
  await until(async () => (await docker('exec', container, 'redis-cli', 'ping')).stdout.trim() === 'PONG');
  admin = new Database(url.href);
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  db = new Database(url.href);
  await migrate(db); await seed(db);
  const config = { databaseUrl: url.href, redisUrl: `redis://127.0.0.1:${port}/0`, port: 0,
    devAccessKey: randomUUID() + randomUUID() };
  presence = new Presence(config.redisUrl); await presence.connect();
  const auth = new Auth(db, presence, config), service = new NightShiftService(db, presence, config);
  const login = async handle => auth.authenticate((await auth.login({ handle, accessKey: config.devAccessKey,
    deviceId: randomUUID() }, schema + handle)).token);
  const customer = await login('customer'), other = await login('customer2'), listener = await login('listener');
  stage = 'prepare-connected-call';
  await service.availability(listener, { online: true });
  assert.equal((await service.user(listener.id)).online, true);
  const invite = await service.createCall(customer, { listenerId: listener.id, quoteId: 'test-audio-v1' }, randomUUID());
  await service.action(listener, invite.id, 'accept', { expectedVersion: invite.version }, randomUUID());
  await service.media(customer, invite.id, { ready: true }); await service.media(listener, invite.id, { ready: true });
  assert.equal((await service.call(customer.id, invite.id)).state, 'connected');
  const started = Date.now();
  stage = 'restart-redis-process';
  // A real OS process/container restart with persistence disabled loses all leases.
  await docker('restart', '--time', '1', container);
  await until(() => presence.healthy());
  const recoveredAfterMs = Date.now() - started;
  stage = 'verify-lost-lease-and-preserved-call';
  assert.equal(await presence.isOnline(listener.id), false, 'Restart must actually remove the lease');
  assert.equal((await service.user(listener.id)).online, false);
  await service.heartbeat(listener);
  assert.equal((await service.user(listener.id)).online, true, 'Current session can restore its lease');
  const card = (await service.listeners(other.id)).items.find(item => item.id === listener.id);
  assert.equal(card?.busy, true); assert.equal(card?.available, false);
  await assert.rejects(service.createCall(other, { listenerId: listener.id, quoteId: 'test-audio-v1' }, randomUUID()),
    { code: 'LISTENER_BUSY' });
  const claims = await db.pool.query('SELECT call_id FROM active_participant_claims WHERE call_id=$1', [invite.id]);
  assert.equal(claims.rowCount, 2, 'Both database-owned claims survive the Redis restart');
  assert.ok(claims.rows.every(row => row.call_id === invite.id));
  assert.equal((await service.call(customer.id, invite.id)).state, 'connected');
  stage = 'settle-once';
  const current = await service.call(customer.id, invite.id);
  await service.action(customer, invite.id, 'end', { expectedVersion: current.version }, randomUUID());
  assert.equal((await db.pool.query('SELECT count(*) FROM active_participant_claims WHERE call_id=$1', [invite.id])).rows[0].count, '0');
  assert.equal((await db.pool.query("SELECT count(*) FROM call_events WHERE call_id=$1 AND payload->>'state'='ended'", [invite.id])).rows[0].count, '1');
  console.log(JSON.stringify({ result: 'pass', realRedisProcessRestart: true, recoveredAfterMs,
    leasesLost: true, existingClientReconnected: true, activeCallPreserved: true, participantClaimsPreserved: 2,
    secondReservation: 'LISTENER_BUSY', terminalEvents: 1, physicalMedia: false }));
}
main().catch(error => {
  // Do not print URLs or database error detail; assertion codes are sufficient.
  console.error(JSON.stringify({ result: 'failed', stage, kind: error instanceof assert.AssertionError ? 'assertion' : 'setup-or-runtime',
    code: typeof error?.code === 'string' && /^[A-Z0-9_]+$/.test(error.code) ? error.code : undefined }));
  process.exitCode = 1;
}).finally(async () => {
  try { if (presence) await presence.close(); } finally {
    try { if (db) await db.close(); } finally {
      try { if (admin) { await admin.pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.close(); } }
      finally {
        if (creationAttempted) {
          // A timed-out run can still have created a container. Remove only our
          // exact random name with its ownership label, including this case.
          const owned = await docker('ps', '--all', '--filter', 'label=nightshift.test=presence-restart', '--format', '{{.Names}}');
          if (owned.stdout.split(/\r?\n/).includes(container)) await docker('rm', '--force', '--volumes', container);
        }
      }
    }
  }
});
