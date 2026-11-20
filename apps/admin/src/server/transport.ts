import {accessRequestValue, exactKeys, hex64, object, sessionValue, statusValue, utcTime} from '../lib/staff-contract.ts';
import {randomUUID} from 'node:crypto';

export type Operation = 'status' | 'challenge' | 'exchange' | 'session' | 'logout';
export type NativeOperation = 'challenge' | 'exchange' | 'access-request' | 'access-request-current';
export type Configuration = {apiOrigin: string; consoleOrigin: string};
const paths: Record<Operation | NativeOperation, string> = {
  status: '/v1/admin/auth/status', challenge: '/v1/admin/auth/challenge', exchange: '/v1/admin/auth/exchange',
  session: '/v1/admin/session', logout: '/v1/admin/auth/logout',
  'access-request': '/v1/admin/access-requests', 'access-request-current': '/v1/admin/access-requests/current',
};
const cookieNames = ['__Host-nightshift_staff', '__Host-nightshift_staff_challenge'];
const baseHeaders = {'Cache-Control': 'no-store, private', 'Pragma': 'no-cache', 'Vary': 'Cookie', 'Content-Type': 'application/json; charset=utf-8'};
function response(body: unknown, status = 200): Response {return new Response(JSON.stringify(body), {status, headers: baseHeaders});}
function fail(code: string, status: number): Response {return response({error: {code, message: 'Staff access could not be completed.'}, requestId: randomUUID()}, status);}
export function configuration(api: string | undefined, console: string | undefined): Configuration | null {
  if (!api || !console) return null;
  const valid = (value: string) => {
    const url = new URL(value);
    if (url.origin !== value || url.username || url.password ||
        !(url.protocol === 'https:' || (url.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)))) throw Error('Invalid origin');
    return url.origin;
  };
  try {return {apiOrigin: valid(api), consoleOrigin: valid(console)};} catch {return null;}
}
async function boundedJson(body: ReadableStream<Uint8Array> | null, limit: number, signal: AbortSignal): Promise<unknown> {
  if (!body) throw Error('Missing body');
  const reader = body.getReader();
  const abort = () => {void reader.cancel().catch(() => {});};
  signal.addEventListener('abort', abort, {once: true});
  let total = 0; const chunks: Uint8Array[] = [];
  try {
    while (true) {
      signal.throwIfAborted();
      const part = await reader.read();
      signal.throwIfAborted();
      if (part.done) break;
      total += part.value.byteLength;
      if (total > limit) throw Error('Body too large');
      chunks.push(part.value);
    }
    const data = new Uint8Array(total); let offset = 0;
    for (const chunk of chunks) {data.set(chunk, offset); offset += chunk.length;}
    return JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(data));
  } finally {signal.removeEventListener('abort', abort); void reader.cancel().catch(() => {});}
}
function requestCookies(value: string | null): string {
  const selected = new Map<string, string>();
  for (const part of (value ?? '').split(';')) {
    const [name, ...rest] = part.trim().split('=');
    if (!cookieNames.includes(name)) continue;
    const token = rest.join('=');
    if (selected.has(name) || !hex64.test(token)) throw Error('Invalid staff cookie');
    selected.set(name, token);
  }
  return [...selected].map(([name, value]) => `${name}=${value}`).join('; ');
}
function responseCookies(headers: Headers): string[] {
  const result = headers.getSetCookie();
  if (result.length > 2) throw Error('Unexpected cookies');
  const names = new Set<string>();
  for (const cookie of result) {
    const [pair, ...attributes] = cookie.split(';').map(value => value.trim());
    const [name, token] = pair.split('=');
    const values = attributes.map(value => value.toLowerCase());
    if (!cookieNames.includes(name) || names.has(name) || !(hex64.test(token) || token === '') ||
        !['secure', 'httponly', 'samesite=strict', 'path=/'].every(value => values.includes(value)) ||
        values.some(value => !['secure', 'httponly', 'samesite=strict', 'path=/'].includes(value) &&
          !/^max-age=-?\d+$/.test(value) && !value.startsWith('expires='))) throw Error('Unsafe cookie');
    names.add(name);
  }
  return result;
}
export async function proxyStaff(request: Request, operation: Operation, config: Configuration | null,
    options: {fetch?: typeof fetch; timeoutMs?: number} = {}): Promise<Response> {
  return dispatch(request, operation, config, false, options);
}
/** App bearer credentials are accepted only on this native-only route allowlist.
 * Browser session routes remain cookie-only. Native callers disable redirects. */
export async function proxyNativeStaff(request: Request, operation: NativeOperation, config: Configuration | null,
    options: {fetch?: typeof fetch; timeoutMs?: number} = {}): Promise<Response> {
  return dispatch(request, operation, config, true, {timeoutMs: 15000, ...options});
}
async function dispatch(request: Request, operation: Operation | NativeOperation, config: Configuration | null,
    native: boolean, options: {fetch?: typeof fetch; timeoutMs?: number}): Promise<Response> {
  const method = ['status', 'session', 'access-request-current'].includes(operation) ? 'GET' : 'POST';
  if (request.method !== method || new URL(request.url).search) return fail('INVALID_REQUEST', 400);
  if (!config) return operation === 'status' ? response({configured: false, available: false, reasonCode: 'STAFF_AUTH_UNAVAILABLE'}) : fail('STAFF_AUTH_UNAVAILABLE', 503);
  if (native && !config.consoleOrigin.startsWith('https:')) return fail('STAFF_AUTH_UNAVAILABLE', 503);
  const origin = request.headers.get('origin');
  // Next's internal Request URL can use localhost behind a listener/proxy. Check
  // the actual Host; never accept a caller-supplied forwarded-host override.
  const host = request.headers.get('host') ?? new URL(request.url).host;
  if (host !== new URL(config.consoleOrigin).host || (origin !== null && origin !== config.consoleOrigin) ||
      ((method === 'POST' || native) && origin !== config.consoleOrigin) || request.headers.get('sec-fetch-site') === 'cross-site') return fail('STAFF_ORIGIN_REJECTED', 403);
  const authorization = request.headers.get('authorization');
  if (native && (!authorization || authorization.length > 16391 || !/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(authorization))) return fail('STAFF_UNAUTHENTICATED', 401);
  const controller = new AbortController();
  const abort = () => controller.abort();
  request.signal.addEventListener('abort', abort, {once: true});
  if (request.signal.aborted) controller.abort();
  const timer = setTimeout(abort, options.timeoutMs ?? 8000);
  try {
    const headers = new Headers({Accept: 'application/json'});
    if (native) headers.set('Authorization', authorization!);
    const cookies = native && operation !== 'exchange' ? '' : requestCookies(request.headers.get('cookie'));
    if (native && cookies.split('; ').some(cookie => cookie && !cookie.startsWith('__Host-nightshift_staff_challenge='))) return fail('INVALID_REQUEST', 400);
    if (cookies) headers.set('Cookie', cookies);
    if (origin) headers.set('Origin', origin);
    let body: string | undefined;
    if (method === 'POST') {
      if (request.headers.get('content-type')?.split(';')[0].trim() !== 'application/json') return fail('INVALID_REQUEST', 400);
      const value = await boundedJson(request.body, 20000, controller.signal);
      if (!object(value) || (operation === 'exchange'
        ? !exactKeys(value, ['proof']) || typeof value.proof !== 'string' || !value.proof.length || value.proof.length > 16384 || value.proof.trim() !== value.proof
        : !exactKeys(value, []))) return fail('INVALID_REQUEST', 400);
      if (operation === 'exchange' || operation === 'logout') {
        const csrf = request.headers.get('x-csrf-token');
        if (!csrf || !hex64.test(csrf)) return fail('STAFF_CSRF_REJECTED', 403);
        headers.set('X-CSRF-Token', csrf);
      }
      headers.set('Content-Type', 'application/json');
      body = JSON.stringify(value);
    }
    const upstream = await (options.fetch ?? fetch)(`${config.apiOrigin}${paths[operation]}`, {
      method, headers, body, redirect: 'manual', cache: 'no-store', signal: controller.signal,
    });
    if (upstream.status >= 300 && upstream.status < 400) {await upstream.body?.cancel(); return fail('STAFF_SERVICE_UNAVAILABLE', 502);}
    const value = await boundedJson(upstream.body, 65536, controller.signal);
    if (!upstream.ok) {
      const code = object(value) && object(value.error) && typeof value.error.code === 'string' && /^[A-Z_]{1,64}$/.test(value.error.code) ? value.error.code : 'STAFF_SERVICE_UNAVAILABLE';
      return fail(code, [400, 401, 403, 404, 409, 429, 503].includes(upstream.status) ? upstream.status : 502);
    }
    const valid = operation.startsWith('access-request') ? accessRequestValue(value) : operation === 'status' ? statusValue(value) : ['session', 'exchange'].includes(operation) ? sessionValue(value) : operation === 'logout'
      ? object(value) && exactKeys(value, ['signedOut']) && value.signedOut === true
      : object(value) && exactKeys(value, ['csrfToken', 'expiresAt']) && typeof value.csrfToken === 'string' && hex64.test(value.csrfToken) && utcTime(value.expiresAt);
    if (!valid) return fail('STAFF_SERVICE_UNAVAILABLE', 502);
    const result = response(value);
    const receivedCookies = responseCookies(upstream.headers);
    if (operation.startsWith('access-request') && receivedCookies.length) return fail('STAFF_SERVICE_UNAVAILABLE', 502);
    for (const cookie of receivedCookies) result.headers.append('Set-Cookie', cookie);
    return result;
  } catch {return fail(controller.signal.aborted ? 'STAFF_REQUEST_TIMEOUT' : 'STAFF_SERVICE_UNAVAILABLE', 503);}
  finally {clearTimeout(timer); request.signal.removeEventListener('abort', abort);}
}
