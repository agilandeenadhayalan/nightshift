// External synthetic upstream for browser tests. Never imported by runtime code.
import {createServer} from 'node:http';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
if (process.argv[2] !== '--test-fixtures') throw Error('Explicit test harness required');
const require = createRequire(import.meta.url);
const Ajv2020 = require('ajv/dist/2020.js').default;
const contract = require('@nightshift/contracts/staff.openapi.json');
const ajv = new Ajv2020({strict: true}); require('ajv-formats')(ajv);
const validators = Object.fromEntries(Object.entries(contract.components.schemas).map(([name, schema]) => [name, ajv.compile(schema)]));
const token = 'a'.repeat(64), csrf = 'b'.repeat(64);
let mode = 'unavailable', sessionReads = 0, mutations = 0;
const session = () => ({staff: {id: 'c874c564-4701-445c-a090-cceab31ba9c9'}, permissions: ['listener.review.read'],
  expiresAt: new Date(Date.now() + (mode === 'expiring' ? 1200 : 600000)).toISOString(), csrfToken: csrf});
const upstream = createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-store');
  const send = (data, code = 200) => {
    if (req.url?.startsWith('/v1/admin/')) {
      const name = code >= 400 ? 'StaffError' : req.url.endsWith('/status') ? 'StaffAuthStatus' : req.url.endsWith('/session') ? 'StaffSession' : 'StaffLogout';
      if (!validators[name](data)) throw Error('Synthetic response does not match the public staff contract');
    }
    res.statusCode = code; res.end(JSON.stringify(data));
  };
  const failure = (code, status) => send({error: {code, message: 'Synthetic staff access is unavailable.'}, requestId: randomUUID()}, status);
  if (req.url === '/__fixture/control' && req.method === 'POST') {
    const chunks = []; for await (const chunk of req) chunks.push(chunk);
    mode = JSON.parse(Buffer.concat(chunks).toString()).mode; sessionReads = mutations = 0; return send({ok: true});
  }
  if (req.url === '/__fixture/counts') return send({sessionReads, mutations});
  if (req.url === '/v1/admin/auth/status') return send(mode === 'unavailable' ? {configured: false, available: false, reasonCode: 'STAFF_AUTH_UNAVAILABLE'} : {configured: true, available: true, reasonCode: null});
  if (req.url === '/v1/admin/session') {
    sessionReads++;
    if (mode === 'revoked' || !req.headers.cookie?.includes(`__Host-nightshift_staff=${token}`)) return failure('STAFF_UNAUTHENTICATED', 401);
    if (mode === 'held-session') {setTimeout(() => send(session()), 300); return;}
    return send(session());
  }
  if (req.url === '/v1/admin/auth/logout') {
    mutations++;
    if (req.headers.origin !== 'http://127.0.0.1:4773') return failure('STAFF_ORIGIN_DENIED', 403);
    if (req.headers['x-csrf-token'] !== csrf) return failure('STAFF_CSRF_INVALID', 403);
    if (mode === 'logout-uncertain') return failure('STAFF_AUTH_UNAVAILABLE', 503);
    mode = 'revoked';
    res.setHeader('Set-Cookie', ['__Host-nightshift_staff=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0', '__Host-nightshift_staff_challenge=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0']);
    return send({signedOut: true});
  }
  return failure('STAFF_AUTH_UNAVAILABLE', 503);
});
await new Promise(resolve => upstream.listen(4774, '127.0.0.1', resolve));
const env = Object.fromEntries(['PATH','SystemRoot','WINDIR','TEMP','TMP','LOCALAPPDATA','HOME','USERPROFILE'].filter(key => process.env[key]).map(key => [key, process.env[key]]));
const next = spawn(process.execPath, [require.resolve('next/dist/bin/next'), 'start', '--hostname', '127.0.0.1', '--port', '4773'], {
  windowsHide: true, stdio: 'inherit', env: {...env, NODE_ENV: 'production', NEXT_TELEMETRY_DISABLED: '1',
    STAFF_API_BASE_URL: 'http://127.0.0.1:4774', STAFF_CONSOLE_ORIGIN: 'http://127.0.0.1:4773'},
});
const stop = () => {next.kill(); upstream.closeAllConnections(); upstream.close();};
process.on('SIGTERM', stop); process.on('SIGINT', stop);
next.on('exit', code => {upstream.closeAllConnections(); upstream.close(); process.exitCode = code ?? 0;});
