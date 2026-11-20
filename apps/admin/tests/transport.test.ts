import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer, type Server} from 'node:http';
import {once} from 'node:events';
import {configuration, proxyStaff, type Configuration, type Operation} from '../src/server/transport.ts';

const origin = 'https://staff.example.test';
const config: Configuration = {apiOrigin: 'https://api.example.test', consoleOrigin: origin};
const csrf = 'b'.repeat(64), cookie = 'a'.repeat(64);
const session = {staff: {id: 'c874c564-4701-445c-a090-cceab31ba9c9'}, permissions: ['listener.review.read'], expiresAt: '2030-01-01T00:00:00.000Z', csrfToken: csrf};
const disabled = {configured: false, available: false, reasonCode: 'STAFF_AUTH_UNAVAILABLE'};
const request = (operation: Operation, options: {origin?: string | null; body?: unknown; cookie?: string; csrf?: string} = {}) => {
  const post = !['status', 'session'].includes(operation);
  const headers = new Headers();
  if (post) headers.set('Content-Type', 'application/json');
  if (options.origin !== null) headers.set('Origin', options.origin ?? origin);
  if (options.cookie) headers.set('Cookie', options.cookie);
  if (options.csrf) headers.set('X-CSRF-Token', options.csrf);
  return new Request(`${origin}/api/staff/${operation}`, {method: post ? 'POST' : 'GET', headers,
    ...(post ? {body: JSON.stringify(options.body ?? {})} : {})});
};
const json = (body: unknown, status = 200, headers = {}) => new Response(JSON.stringify(body), {status, headers});
test('unconfigured staff gate never contacts any upstream', async () => {
  const fetcher: typeof fetch = async () => {throw Error('No network allowed');};
  assert.deepEqual(await (await proxyStaff(request('status'), 'status', null, {fetch: fetcher})).json(), disabled);
  assert.equal((await proxyStaff(request('exchange', {body: {proof: 'synthetic'}}), 'exchange', null, {fetch: fetcher})).status, 503);
});
test('configuration only permits fixed HTTPS or loopback origins', () => {
  assert.deepEqual(configuration(config.apiOrigin, origin), config);
  assert.ok(configuration('http://127.0.0.1:4210', 'http://localhost:3100'));
  for (const invalid of ['http://192.168.0.3', 'https://api.example.test/path', 'https://u:p@api.example.test', 'https://api.example.test?x=1', 'https://api.example.test/#x']) {
    assert.equal(configuration(invalid, origin), null);
    assert.equal(configuration(config.apiOrigin, invalid), null);
  }
});
test('unsafe requests reject missing/wrong origin and CSRF before dispatch', async () => {
  let calls = 0;
  const fetcher: typeof fetch = async () => {calls++; return json({signedOut: true});};
  for (const wrong of [null, 'https://untrusted.example.test']) {
    assert.equal((await proxyStaff(request('logout', {origin: wrong, csrf}), 'logout', config, {fetch: fetcher})).status, 403);
  }
  assert.equal((await proxyStaff(request('logout'), 'logout', config, {fetch: fetcher})).status, 403);
  assert.equal(calls, 0);
});
test('Next internal URL cannot replace the configured browser host or origin', async () => {
  const incoming = (host: string) => new Request('http://localhost:3100/api/staff/auth/logout', {method: 'POST', headers: {
    host, origin, 'Content-Type': 'application/json', 'X-CSRF-Token': csrf, 'X-Forwarded-Host': 'staff.example.test',
  }, body: '{}'});
  let calls = 0;
  const fetcher: typeof fetch = async () => {calls++; return json({signedOut: true});};
  assert.equal((await proxyStaff(incoming('staff.example.test'), 'logout', config, {fetch: fetcher})).status, 200);
  assert.equal((await proxyStaff(incoming('untrusted.example.test'), 'logout', config, {fetch: fetcher})).status, 403);
  assert.equal(calls, 1);
});
test('proxy forwards only staff cookies and original exact origin', async () => {
  const req = request('logout', {csrf, cookie: `customer=private; __Host-nightshift_staff=${cookie}`});
  req.headers.set('Authorization', 'Bearer customer-synthetic-token');
  req.headers.set('X-Forwarded-Host', 'untrusted.example.test');
  const result = await proxyStaff(req, 'logout', config, {fetch: async (url, options) => {
    assert.equal(url, 'https://api.example.test/v1/admin/auth/logout');
    const headers = new Headers(options?.headers);
    assert.equal(headers.get('cookie'), `__Host-nightshift_staff=${cookie}`);
    assert.equal(headers.get('authorization'), null);
    assert.equal(headers.get('x-forwarded-host'), null);
    assert.equal(headers.get('origin'), origin);
    assert.equal(headers.get('x-csrf-token'), csrf);
    assert.equal(options?.redirect, 'manual');
    assert.equal(options?.cache, 'no-store');
    return json({signedOut: true});
  }});
  assert.equal(result.status, 200);
  assert.equal(result.headers.get('cache-control'), 'no-store, private');
});
test('duplicate staff cookies and malformed bodies never dispatch', async () => {
  let calls = 0;
  const fetcher: typeof fetch = async () => {calls++; return json(session);};
  assert.notEqual((await proxyStaff(request('session', {cookie: `__Host-nightshift_staff=${cookie}; __Host-nightshift_staff=${cookie}`}), 'session', config, {fetch: fetcher})).status, 200);
  for (const body of [{proof: 'x', role: 'admin'}, {proof: ' x'}, {proof: 'x'.repeat(16385)}, {proof: ''}]) {
    assert.equal((await proxyStaff(request('exchange', {csrf, body}), 'exchange', config, {fetch: fetcher})).status, 400);
  }
  assert.equal(calls, 0);
});
test('valid session is minimal; unknown permissions and private fields fail closed', async () => {
  assert.deepEqual(await (await proxyStaff(request('session'), 'session', config, {fetch: async () => json(session)})).json(), session);
  for (const body of [{...session, phone: 'synthetic-private'}, {...session, permissions: ['finance.write']}, {...session, permissions: ['listener.review.read', 'listener.review.read']}, {...session, csrfToken: 'invalid'}]) {
    const response = await proxyStaff(request('session'), 'session', config, {fetch: async () => json(body)});
    assert.equal(response.status, 502);
    assert.doesNotMatch(await response.text(), /synthetic-private|finance.write/);
  }
});
test('session exchange preserves only hardened host cookies', async () => {
  const safe = `__Host-nightshift_staff=${cookie}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=900`;
  const req = () => request('exchange', {csrf, body: {proof: 'synthetic-proof'}});
  const good = await proxyStaff(req(), 'exchange', config, {fetch: async () => json(session, 200, {'Set-Cookie': safe})});
  assert.deepEqual(good.headers.getSetCookie(), [safe]);
  for (const bad of [safe.replace('; Secure', ''), safe+'; Domain=example.test', safe.replace('SameSite=Strict', 'SameSite=None'), safe.replace('__Host-nightshift_staff=', 'customer=')]) {
    const rejected = await proxyStaff(req(), 'exchange', config, {fetch: async () => json(session, 200, {'Set-Cookie': bad})});
    assert.equal(rejected.status, 503);
    assert.equal(rejected.headers.get('set-cookie'), null);
  }
});
test('upstream error never reflects private provider payload', async () => {
  const result = await proxyStaff(request('session'), 'session', config, {fetch: async () => json({error: {code: 'STAFF_UNAUTHENTICATED', message: 'private-synthetic-detail'}, proof: 'synthetic-proof'}, 401)});
  assert.equal(result.status, 401);
  assert.doesNotMatch(await result.text(), /private-synthetic-detail|synthetic-proof/);
});
async function listen(server: Server): Promise<string> {
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const address = server.address(); if (!address || typeof address === 'string') throw Error('No port');
  return `http://127.0.0.1:${address.port}`;
}
test('actual cross-origin redirect cannot receive a staff session', async context => {
  let leaked = false;
  const destination = createServer((_, res) => {leaked = true; res.end('{}');});
  const destinationUrl = await listen(destination);
  const source = createServer((_, res) => {res.writeHead(307, {Location: destinationUrl}); res.end();});
  const sourceUrl = await listen(source);
  context.after(() => {source.closeAllConnections(); destination.closeAllConnections(); source.close(); destination.close();});
  const result = await proxyStaff(request('session', {cookie: `__Host-nightshift_staff=${cookie}`}), 'session', {...config, apiOrigin: sourceUrl});
  assert.equal(result.status, 502);
  assert.equal(leaked, false);
});
test('full upstream deadline aborts a held response and closes its connection', async context => {
  let closed = false;
  const server = createServer((req) => {req.on('close', () => {closed = true;});});
  const url = await listen(server);
  context.after(() => {server.closeAllConnections(); server.close();});
  const result = await proxyStaff(request('session'), 'session', {...config, apiOrigin: url}, {timeoutMs: 50});
  assert.equal(result.status, 503);
  assert.equal((await result.json()).error.code, 'STAFF_REQUEST_TIMEOUT');
  for (let n = 0; n < 20 && !closed; n++) await new Promise(resolve => setTimeout(resolve, 10));
  assert.equal(closed, true);
});
test('bounded response body and body streaming timeout fail closed', async context => {
  const server = createServer((req, res) => {
    res.writeHead(200, {'Content-Type': 'application/json'});
    if (req.url?.includes('session')) {res.write('{'); return;}
    res.end(JSON.stringify({padding: 'x'.repeat(65536)}));
  });
  const url = await listen(server);
  context.after(() => {server.closeAllConnections(); server.close();});
  for (const operation of ['session', 'status'] as const) {
    const result = await proxyStaff(request(operation), operation, {...config, apiOrigin: url}, {timeoutMs: 50});
    assert.equal(result.status, 503);
  }
});
