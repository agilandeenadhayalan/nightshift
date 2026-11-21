// External synthetic upstream for browser tests. Never imported by runtime code.
import {createServer} from 'node:http';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
import {applicationId, detail, nextCursor, page, second, secondId, third, materialVersion, sampleBytes} from './review-fixtures.ts';
import {policy, receipt} from './decision-fixtures.ts';
if (process.argv[2] !== '--test-fixtures') throw Error('Explicit test harness required');
const require = createRequire(import.meta.url);
const Ajv2020 = require('ajv/dist/2020.js').default;
const contract = require('@nightshift/contracts/staff.openapi.json');
const ajv = new Ajv2020({strict: true}); require('ajv-formats')(ajv);
const validators = Object.fromEntries(Object.entries(contract.components.schemas).map(([name, schema]) => [name, ajv.compile(schema)]));
const token = 'a'.repeat(64), csrf = 'b'.repeat(64);
let mode = 'unavailable', sessionReads = 0, mutations = 0, probes = 0;
let queueReads = 0, detailReads = 0, sampleReads = 0;
let decisionPosts = 0, receiptReads = 0, decisionKeys = [], decisionBodies = [], savedReceipts = new Map();
const decisionMode = () => mode.startsWith('decision-');
const session = () => ({staff: {id: 'c874c564-4701-445c-a090-cceab31ba9c9'}, permissions: decisionMode() ? ['listener.review.read', 'listener.review.evidence.read', ...(mode === 'decision-no-permission' ? [] : ['listener.review.decide'])] : mode === 'review-no-read' ? [] : mode.startsWith('review-') && mode !== 'review-no-evidence' ? ['listener.review.read', 'listener.review.evidence.read'] : ['listener.review.read'],
  expiresAt: new Date(Date.now() + (mode === 'expiring' ? 1200 : 600000)).toISOString(), csrfToken: csrf});
const upstream = createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-store');
  const send = (data, code = 200) => {
    if (req.url?.startsWith('/v1/admin/')) {
      const path = new URL(req.url, 'http://fixture.test').pathname;
      const name = code >= 400 ? 'StaffError' : path === '/v1/admin/listener-review-policy' ? 'StaffReviewPolicy' : path.endsWith('/decisions') || path.endsWith('/decision-receipt') ? 'StaffReviewReceipt' : path === '/v1/admin/listener-applications' ? 'StaffReviewQueue' : path.startsWith('/v1/admin/listener-applications/') ? 'StaffReviewDetail' : req.url.endsWith('/status') ? 'StaffAuthStatus' : req.url.endsWith('/session') ? 'StaffSession' : 'StaffLogout';
      if (!validators[name](data)) throw Error('Synthetic response does not match the public staff contract');
    }
    res.statusCode = code; res.end(JSON.stringify(data));
  };
  const failure = (code, status) => send({error: {code, message: 'Synthetic staff access is unavailable.'}, requestId: randomUUID()}, status);
  if (req.url === '/__fixture/control' && req.method === 'POST') {
    const chunks = []; for await (const chunk of req) chunks.push(chunk);
    mode = JSON.parse(Buffer.concat(chunks).toString()).mode; sessionReads = mutations = probes = queueReads = detailReads = sampleReads = 0; return send({ok: true});
  }
  if (req.url === '/__fixture/counts') return send({sessionReads, mutations, probes});
  if (req.url === '/__fixture/review-counts') return send({queueReads, detailReads, sampleReads});
  if (req.url === '/__fixture/decision-counts') return send({decisionPosts, receiptReads, decisionKeys, decisionBodies});
  if (req.url === '/__fixture/reset-decisions' && req.method === 'POST') {decisionPosts = receiptReads = 0; decisionKeys = []; decisionBodies = []; savedReceipts = new Map(); return send({ok: true});}
  if (req.url?.startsWith('/__fixture/probe')) {probes++; return send({received: true});}
  if (req.url === '/v1/admin/auth/status') return send(mode === 'unavailable' ? {configured: false, available: false, reasonCode: 'STAFF_AUTH_UNAVAILABLE'} : {configured: true, available: true, reasonCode: null});
  if (req.url === '/v1/admin/session') {
    sessionReads++;
    if (mode === 'revoked' || !req.headers.cookie?.includes(`__Host-nightshift_staff=${token}`)) return failure('STAFF_UNAUTHENTICATED', 401);
    if (mode === 'held-session') {setTimeout(() => send(session()), 300); return;}
    return send(session());
  }
  if (req.url === '/v1/admin/listener-review-policy') return send(decisionMode() && mode !== 'decision-off' ? policy : {enabled: false, reasonCode: 'REVIEW_POLICY_UNAVAILABLE'});
  if (req.url?.endsWith('/decisions') || req.url?.endsWith('/decision-receipt')) {
    if (mode === 'revoked' || !req.headers.cookie?.includes(`__Host-nightshift_staff=${token}`)) return failure('STAFF_UNAUTHENTICATED', 401);
    if (mode === 'decision-no-permission') return failure('STAFF_FORBIDDEN', 403);
    const key = req.headers['idempotency-key'];
    if (!key || req.headers.authorization) return failure('INVALID_REVIEW_DECISION', 400);
    if (req.url.endsWith('/decision-receipt')) {receiptReads++; return savedReceipts.has(key) ? send(savedReceipts.get(key)) : failure('REVIEW_DECISION_NOT_FOUND', 404);}
    if (req.method !== 'POST' || req.headers.origin !== 'http://127.0.0.1:4773' || req.headers['x-csrf-token'] !== csrf) return failure('STAFF_CSRF_INVALID', 403);
    decisionPosts++; const chunks = []; for await (const chunk of req) chunks.push(chunk); const input = JSON.parse(Buffer.concat(chunks).toString());
    if (!validators.StaffReviewDecision(input)) throw Error('Invalid synthetic decision request');
    decisionKeys.push(key); decisionBodies.push(input);
    if (mode === 'decision-off') return failure('REVIEW_POLICY_UNAVAILABLE', 503);
    if (mode === 'decision-stale') return failure('REVIEW_MATERIAL_CHANGED', 409);
    if (mode === 'decision-policy-changed') return failure('REVIEW_POLICY_CHANGED', 409);
    if (mode === 'decision-failed' && decisionPosts === 1) return failure('STAFF_REQUEST_TIMEOUT', 503);
    const result = savedReceipts.get(key) ?? receipt(input); savedReceipts.set(key, result);
    if (mode === 'decision-lost' && decisionPosts === 1) return failure('STAFF_REQUEST_TIMEOUT', 503);
    if (mode === 'decision-held') {setTimeout(() => send(result), 600); return;}
    return send(result);
  }
  if (req.url?.startsWith('/v1/admin/listener-applications')) {
    if (req.method !== 'GET') return failure('STAFF_FORBIDDEN', 403);
    if (mode === 'revoked' || !req.headers.cookie?.includes(`__Host-nightshift_staff=${token}`)) return failure('STAFF_UNAUTHENTICATED', 401);
    if (req.headers.authorization || req.headers.range) throw Error('Unexpected credential or range in synthetic review request');
    if (mode === 'review-no-read') return failure('STAFF_FORBIDDEN', 403);
    const url = new URL(req.url, 'http://fixture.test');
    if (url.pathname === '/v1/admin/listener-applications') {
      queueReads++;
      if (mode === 'review-error') return failure('STAFF_AUTH_UNAVAILABLE', 503);
      if (mode === 'review-empty') return send({...page, items: [], nextCursor: null});
      if (url.searchParams.has('cursor')) {
        if (mode === 'review-expired') return failure('REVIEW_CURSOR_EXPIRED', 410);
        if (url.searchParams.get('cursor') !== nextCursor) return failure('INVALID_REVIEW_CURSOR', 400);
        return send({...page, items: [third], nextCursor: null});
      }
      if (mode === 'review-short-page') return send({...page, items: []});
      const language = url.searchParams.get('language');
      if (language) return send({...page, items: page.items.filter(item => item.languages.includes(language)), nextCursor: null});
      return send(page);
    }
    if (mode === 'review-no-evidence') return failure('STAFF_FORBIDDEN', 403);
    const id = url.pathname.split('/')[4];
    if (![applicationId, secondId].includes(id) || mode === 'review-withdrawn') return failure('REVIEW_NOT_AVAILABLE', 404);
    if (url.pathname.endsWith('/voice-sample')) {
      sampleReads++;
      if (mode === 'review-changed' || url.searchParams.get('version') !== materialVersion) return failure('REVIEW_MATERIAL_CHANGED', 409);
      const bytes = sampleBytes();
      res.writeHead(200, {'Content-Type': 'audio/wav', 'Content-Length': bytes.length, 'X-Review-Material-Version': materialVersion, 'Content-Disposition': 'inline; filename="review-sample.wav"'});
      return res.end(bytes);
    }
    detailReads++;
    const base = {...detail, decisionsEnabled: decisionMode() && mode !== 'decision-off'};
    const body = id === secondId ? {...base, application: {...detail.application, id: secondId, alias: second.alias, languages: ['ta'], bio: 'அன்றாட உரையாடல்களையும் மொழிப் பயிற்சியையும் விரும்புகிறேன். '.repeat(5)}} : base;
    if (mode === 'review-held-detail' && id === applicationId) {setTimeout(() => send(body), 500); return;}
    return send(body);
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
