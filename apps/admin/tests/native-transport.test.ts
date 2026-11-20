import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {proxyNativeStaff, type NativeOperation} from '../src/server/transport.ts';

const origin = 'https://staff.example.test';
const config = {apiOrigin: 'https://api.example.test', consoleOrigin: origin};
const proof = 'syntheticHeader.syntheticPayload.syntheticSignature';
const csrf = 'b'.repeat(64), token = 'a'.repeat(64);
const receipt = {requestId: 'c874c564-4701-445c-a090-cceab31ba9c9', accountReference: 'a874c564-4701-445c-a090-cceab31ba9c9', status: 'pending', expiresAt: '2030-01-01T00:00:00.000Z'};
function incoming(operation: NativeOperation, overrides: Record<string, string> = {}, body: unknown = {}) {
  const method = operation === 'access-request-current' ? 'GET' : 'POST';
  return new Request(`${origin}/api/staff/native/${operation}`, {method, headers: {origin, authorization: `Bearer ${proof}`, 'Content-Type': 'application/json', ...overrides}, ...(method === 'POST' ? {body: JSON.stringify(body)} : {})});
}
const json = (value: unknown, status = 200, headers: Record<string, string> = {}) => new Response(JSON.stringify(value), {status, headers});

test('native receipt forwards only exact app bearer and fixed origin; ignores browser cookies and proxy headers', async () => {
  const response = await proxyNativeStaff(incoming('access-request', {cookie: `customer=secret; __Host-nightshift_staff=${token}`, 'X-Forwarded-Host': 'untrusted.test'}), 'access-request', config, {fetch: async (url, options) => {
    assert.equal(url, `${config.apiOrigin}/v1/admin/access-requests`);
    const headers = new Headers(options?.headers);
    assert.equal(headers.get('authorization'), `Bearer ${proof}`);
    assert.equal(headers.get('origin'), origin);
    assert.equal(headers.get('cookie'), null);
    assert.equal(headers.get('x-forwarded-host'), null);
    assert.equal(options?.redirect, 'manual');
    assert.equal(options?.cache, 'no-store');
    return json(receipt);
  }});
  assert.deepEqual(await response.json(), receipt);
  assert.equal(response.headers.get('set-cookie'), null);
});
test('native requests require HTTPS, exact origin, current bearer syntax and exact request fields', async () => {
  let dispatched = 0;
  const options = {fetch: async () => {dispatched++; return json(receipt);}};
  const invalidHeaders: Record<string, string>[] = [{authorization: ''}, {authorization: 'Bearer role-admin'}, {origin: 'https://untrusted.test'}, {host: 'untrusted.test'}, {'sec-fetch-site': 'cross-site'}];
  for (const headers of invalidHeaders) {
    assert.notEqual((await proxyNativeStaff(incoming('access-request', headers), 'access-request', config, options)).status, 200);
  }
  assert.equal((await proxyNativeStaff(incoming('access-request', {}, {role: 'admin'}), 'access-request', config, options)).status, 400);
  assert.equal((await proxyNativeStaff(incoming('access-request'), 'access-request', {...config, consoleOrigin: 'http://127.0.0.1:3443'}, options)).status, 503);
  assert.equal(dispatched, 0);
});
test('native exchange carries only its challenge cookie and rejects duplicate or browser session cookies', async () => {
  let dispatched = 0;
  const options = {fetch: async (_url: string | URL | Request, init?: RequestInit) => {
    dispatched++;
    const headers = new Headers(init?.headers);
    assert.equal(headers.get('cookie'), `__Host-nightshift_staff_challenge=${token}`);
    assert.equal(headers.get('x-csrf-token'), csrf);
    assert.equal(headers.get('authorization'), `Bearer ${proof}`);
    return json({staff: {id: receipt.requestId}, permissions: ['staff.access.manage'], expiresAt: receipt.expiresAt, csrfToken: csrf}, 200,
      {'Set-Cookie': `__Host-nightshift_staff=${token}; Secure; HttpOnly; SameSite=Strict; Path=/; Max-Age=1800`});
  }};
  const headers = {'x-csrf-token': csrf, cookie: `__Host-nightshift_staff_challenge=${token}`};
  const valid = await proxyNativeStaff(incoming('exchange', headers, {proof}), 'exchange', config, options);
  assert.equal(valid.status, 200); assert.equal(valid.headers.getSetCookie().length, 1);
  for (const cookie of [`${headers.cookie}; __Host-nightshift_staff=${token}`, `${headers.cookie}; ${headers.cookie}`]) {
    assert.notEqual((await proxyNativeStaff(incoming('exchange', {...headers, cookie}, {proof}), 'exchange', config, options)).status, 200);
  }
  assert.equal(dispatched, 1);
});
test('native receipt schema rejects private provider details, unexpected grants and any cookie', async () => {
  for (const value of [{...receipt, providerSubject: 'private'}, {...receipt, status: 'admin'}, {...receipt, accountReference: 'private'}, {...receipt, permissions: ['staff.access.manage']}]) {
    const result = await proxyNativeStaff(incoming('access-request'), 'access-request', config, {fetch: async () => json(value)});
    assert.equal(result.status, 502); assert.doesNotMatch(await result.text(), /private|admin/);
  }
  const result = await proxyNativeStaff(incoming('access-request'), 'access-request', config, {fetch: async () => json(receipt, 200,
    {'Set-Cookie': `__Host-nightshift_staff=${token}; Secure; HttpOnly; SameSite=Strict; Path=/; Max-Age=1800`})});
  assert.equal(result.status, 502); assert.equal(result.headers.get('set-cookie'), null);
});
test('missing native request preserves safe 404 without reflecting provider payload', async () => {
  const result = await proxyNativeStaff(incoming('access-request-current'), 'access-request-current', config, {fetch: async () => json({error: {code: 'STAFF_ACCESS_REQUEST_NOT_FOUND', message: proof}}, 404)});
  assert.equal(result.status, 404); assert.doesNotMatch(await result.text(), /syntheticPayload/);
});
test('actual redirect never forwards native bearer to a second origin', async context => {
  let destinationCalls = 0;
  const destination = createServer((_req, res) => {destinationCalls++; res.end('{}');});
  destination.listen(0, '127.0.0.1'); await once(destination, 'listening');
  const target = destination.address(); assert.ok(target && typeof target !== 'string');
  const source = createServer((req, res) => {assert.equal(req.headers.authorization, `Bearer ${proof}`); res.writeHead(307, {Location: `http://127.0.0.1:${target.port}`}); res.end();});
  source.listen(0, '127.0.0.1'); await once(source, 'listening');
  const sourceAddress = source.address(); assert.ok(sourceAddress && typeof sourceAddress !== 'string');
  context.after(() => {for (const server of [source, destination]) {server.closeAllConnections(); server.close();}});
  const result = await proxyNativeStaff(incoming('access-request'), 'access-request', {...config, apiOrigin: `http://127.0.0.1:${sourceAddress.port}`});
  assert.equal(result.status, 502); assert.equal(destinationCalls, 0);
});
