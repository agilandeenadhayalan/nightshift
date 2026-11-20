import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer, type Server} from 'node:http';
import {once} from 'node:events';
import {proxyReview, type ReviewOperation} from '../src/server/review-transport.ts';
import {applicationId, detail, materialVersion, nextCursor, page, sampleBytes} from './review-fixtures.ts';

const config = {apiOrigin: 'https://api.example.test', consoleOrigin: 'https://staff.example.test'};
const token = 'a'.repeat(64);
const queue = {kind: 'queue'} as const, item = {kind: 'detail', id: applicationId} as const, sample = {kind: 'sample', id: applicationId} as const;
function request(operation: ReviewOperation = queue, query?: string, headers: HeadersInit = {}, signal?: AbortSignal) {
  const suffix = operation.kind === 'queue' ? '' : `/${operation.id}${operation.kind === 'sample' ? '/voice-sample' : ''}`;
  return new Request(`${config.consoleOrigin}/api/staff/listener-applications${suffix}${query ?? (operation.kind === 'sample' ? `?version=${materialVersion}` : '')}`,
    {headers: {Cookie: `__Host-nightshift_staff=${token}`, ...headers}, signal});
}
const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), {status, headers: {'Content-Type': 'application/json'}});
const wave = (headers: Record<string, string> = {}, bytes: Uint8Array<ArrayBuffer> = sampleBytes()) => new Response(bytes, {headers: {
  'Content-Type': 'audio/wav', 'Content-Length': String(bytes.byteLength), 'X-Review-Material-Version': materialVersion, ...headers,
}});
test('review transport is a fixed cookie-only GET allowlist with strict query shapes', async () => {
  let calls = 0;
  const fetcher: typeof fetch = async (url, options) => {
    calls++;
    assert.equal(url, `${config.apiOrigin}/v1/admin/listener-applications?language=ta&cursor=${nextCursor}`);
    const headers = new Headers(options?.headers);
    assert.equal(headers.get('cookie'), `__Host-nightshift_staff=${token}`);
    for (const name of ['authorization', 'range', 'x-forwarded-host', 'x-csrf-token']) assert.equal(headers.get(name), null);
    assert.equal(options?.redirect, 'manual'); assert.equal(options?.cache, 'no-store');
    return json(page);
  };
  const result = await proxyReview(request(queue, `?language=ta&cursor=${nextCursor}`, {Cookie: `customer=private; __Host-nightshift_staff=${token}; __Host-nightshift_staff_challenge=${'b'.repeat(64)}`,
    Authorization: 'Bearer private-synthetic', Range: 'bytes=0-2'}), queue, config, {fetch: fetcher});
  assert.equal(result.status, 200); assert.equal(result.headers.get('cache-control'), 'no-store, private');
  for (const query of ['?language=fr', '?language=ta&language=en', '?cursor=bad', '?phone=private', '?url=https://wrong.test']) {
    assert.equal((await proxyReview(request(queue, query), queue, config, {fetch: fetcher})).status, 400);
  }
  for (const query of ['?version=bad', `?version=${materialVersion}&version=${materialVersion}`, `?version=${materialVersion}&extra=1`]) {
    assert.equal((await proxyReview(request(sample, query), sample, config, {fetch: fetcher})).status, 400);
  }
  assert.equal((await proxyReview(request(item, '?version=bad'), item, config, {fetch: fetcher})).status, 400);
  assert.equal((await proxyReview(request({kind: 'detail', id: '../session'}), {kind: 'detail', id: '../session'}, config, {fetch: fetcher})).status, 400);
  assert.equal(calls, 1);
});
test('missing, duplicate, foreign-host and cross-site credentials fail before dispatch', async () => {
  let calls = 0; const fetcher: typeof fetch = async () => {calls++; return json(page);};
  const invalidHeaders: Record<string, string>[] = [
    {Cookie: '', Authorization: 'Bearer synthetic'}, {Cookie: `__Host-nightshift_staff=${token}; __Host-nightshift_staff=${token}`},
    {Host: 'foreign.example.test', 'X-Forwarded-Host': 'staff.example.test'}, {Origin: 'https://foreign.example.test'}, {'Sec-Fetch-Site': 'same-site'},
  ];
  for (const headers of invalidHeaders) assert.ok((await proxyReview(request(queue, '', headers), queue, config, {fetch: fetcher})).status >= 400);
  const post = new Request(request(), {method: 'POST', body: '{}'});
  assert.equal((await proxyReview(post, queue, config, {fetch: fetcher})).status, 400);
  assert.equal(calls, 0);
});
test('private or non-submitted fields fail strict JSON validation without reflection', async () => {
  for (const value of [{...detail, application: {...detail.application, phone: 'private-synthetic'}}, {...detail, application: {...detail.application, state: 'needs_information'}},
    {...detail, application: {...detail.application, adultStatus: 'verified'}}, {...detail, decisionsEnabled: true}, {...detail, application: {...detail.application, id: '2a1eec02-9d54-4c93-8806-5b9a763785d2'}}]) {
    const result = await proxyReview(request(item), item, config, {fetch: async () => json(value)});
    assert.equal(result.status, 502); assert.doesNotMatch(await result.text(), /private-synthetic|needs_information|verified/);
  }
  assert.deepEqual(await (await proxyReview(request(item), item, config, {fetch: async () => json(detail)})).json(), detail);
});
test('full WAV is private, bounded, fingerprint-bound and does not forward upstream headers', async () => {
  const bytes = sampleBytes();
  const result = await proxyReview(request(sample, undefined, {Range: 'bytes=100-200'}), sample, config, {fetch: async (_url, options) => {
    assert.equal(new Headers(options?.headers).get('range'), null);
    return wave({'Content-Disposition': 'attachment; filename="private-original-name.wav"', 'X-Private': 'private-synthetic'});
  }});
  assert.equal(result.status, 200); assert.equal(result.headers.get('content-type'), 'audio/wav');
  assert.equal(result.headers.get('content-disposition'), 'inline; filename="review-sample.wav"');
  assert.equal(result.headers.get('x-private'), null); assert.equal(result.headers.get('x-content-type-options'), 'nosniff');
  assert.deepEqual(new Uint8Array(await result.arrayBuffer()), new Uint8Array(bytes));
  const invalidHeaders: Record<string, string>[] = [{'Content-Type': 'text/html'}, {'Content-Length': '2097153'}, {'Content-Length': '0'}, {'Content-Length': '32045'},
    {'X-Review-Material-Version': 'e'.repeat(64)}, {'Set-Cookie': 'other=private'}, {'Content-Encoding': 'gzip'}];
  for (const headers of invalidHeaders) {
    assert.equal((await proxyReview(request(sample), sample, config, {fetch: async () => wave(headers)})).status, 502);
  }
  const malformed = sampleBytes(); malformed.write('HTML', 0);
  assert.equal((await proxyReview(request(sample), sample, config, {fetch: async () => wave({}, malformed)})).status, 502);
  assert.equal((await proxyReview(request(sample), sample, config, {fetch: async () => wave({'Content-Length': '32044'}, Buffer.alloc(2097153))})).status, 503);
});
test('permission, withdrawn material and expired cursor errors preserve status but sanitize bodies', async () => {
  for (const [code, status] of [['STAFF_FORBIDDEN', 403], ['REVIEW_NOT_AVAILABLE', 404], ['REVIEW_MATERIAL_CHANGED', 409], ['REVIEW_CURSOR_EXPIRED', 410]] as const) {
    const result = await proxyReview(request(sample), sample, config, {fetch: async () => json({error: {code, message: 'private-synthetic'}, private: 'private-synthetic'}, status)});
    assert.equal(result.status, status); assert.equal((await result.clone().json()).error.code, code);
    assert.doesNotMatch(await result.text(), /private-synthetic/);
  }
});
async function listen(server: Server) {server.listen(0, '127.0.0.1'); await once(server, 'listening'); const address = server.address(); if (!address || typeof address === 'string') throw Error('No port'); return `http://127.0.0.1:${address.port}`;}
test('actual binary redirect never receives the staff cookie', async context => {
  let destinationCalls = 0;
  const destination = createServer((_req, res) => {destinationCalls++; res.end();}); const other = await listen(destination);
  const source = createServer((_req, res) => {res.writeHead(307, {Location: `${other}/sample`}); res.end();}); const apiOrigin = await listen(source);
  context.after(() => {source.closeAllConnections(); destination.closeAllConnections(); source.close(); destination.close();});
  assert.equal((await proxyReview(request(sample), sample, {...config, apiOrigin})).status, 502);
  assert.equal(destinationCalls, 0);
});
test('binary body deadline and caller cancellation close pending upstream reads', async context => {
  let closed = 0;
  const server = createServer((req, res) => {req.on('close', () => closed++); res.writeHead(200, {'Content-Type': 'audio/wav', 'Content-Length': 32044, 'X-Review-Material-Version': materialVersion}); res.write(sampleBytes().subarray(0, 44));});
  const apiOrigin = await listen(server); context.after(() => {server.closeAllConnections(); server.close();});
  assert.equal((await proxyReview(request(sample), sample, {...config, apiOrigin}, {timeoutMs: 75})).status, 503);
  const controller = new AbortController();
  const pending = proxyReview(request(sample, undefined, {}, controller.signal), sample, {...config, apiOrigin});
  setTimeout(() => controller.abort(), 75);
  assert.equal((await pending).status, 503);
  for (let n = 0; n < 30 && closed < 2; n++) await new Promise(resolve => setTimeout(resolve, 10));
  assert.equal(closed, 2);
});
