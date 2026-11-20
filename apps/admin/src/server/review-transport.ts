import {hex64, object} from '../lib/staff-contract.ts';
import {reviewCursor, reviewDetailValue, reviewId, reviewPageValue} from '../lib/review-contract.ts';
import {boundedBytes, boundedJson, fail, requestCookies, type Configuration} from './transport.ts';

export type ReviewOperation = {kind: 'queue'} | {kind: 'detail' | 'sample'; id: string};
const privateHeaders = {'Cache-Control': 'no-store, private', Pragma: 'no-cache', Vary: 'Cookie', 'X-Content-Type-Options': 'nosniff', 'Cross-Origin-Resource-Policy': 'same-origin'};
function upstreamPath(request: Request, operation: ReviewOperation): string | null {
  if (request.method !== 'GET') return null;
  const query = new URL(request.url).searchParams;
  const path = '/v1/admin/listener-applications';
  if (operation.kind === 'queue') {
    if ([...query.keys()].some(key => !['language', 'cursor'].includes(key)) || query.getAll('language').length > 1 || query.getAll('cursor').length > 1) return null;
    const language = query.get('language'), cursor = query.get('cursor');
    if (language !== null && !['ta', 'en'].includes(language) || cursor !== null && (cursor.length > 2048 || !reviewCursor.test(cursor))) return null;
    return `${path}${query.size ? `?${query.toString()}` : ''}`;
  }
  if (!reviewId.test(operation.id)) return null;
  if (operation.kind === 'detail') return query.size === 0 ? `${path}/${operation.id}` : null;
  const version = query.get('version');
  return query.size === 1 && version !== null && hex64.test(version) ? `${path}/${operation.id}/voice-sample?version=${version}` : null;
}
/** A separate, read-only cookie transport. Never forwards caller URLs, bearer
 * credentials, range requests, arbitrary upstream headers or Set-Cookie. */
export async function proxyReview(request: Request, operation: ReviewOperation, config: Configuration | null,
    options: {fetch?: typeof fetch; timeoutMs?: number} = {}): Promise<Response> {
  const path = upstreamPath(request, operation);
  if (!path) return fail('INVALID_REQUEST', 400);
  if (!config) return fail('STAFF_AUTH_UNAVAILABLE', 503);
  const origin = request.headers.get('origin'), site = request.headers.get('sec-fetch-site');
  const host = request.headers.get('host') ?? new URL(request.url).host;
  if (host !== new URL(config.consoleOrigin).host || origin !== null && origin !== config.consoleOrigin || site !== null && !['same-origin', 'none'].includes(site)) return fail('STAFF_ORIGIN_REJECTED', 403);
  let cookie: string;
  try {cookie = requestCookies(request.headers.get('cookie')).split('; ').filter(part => part.startsWith('__Host-nightshift_staff=')).join('; ');}
  catch {return fail('STAFF_UNAUTHENTICATED', 401);}
  if (!cookie) return fail('STAFF_UNAUTHENTICATED', 401);
  const controller = new AbortController(), abort = () => controller.abort();
  request.signal.addEventListener('abort', abort, {once: true});
  if (request.signal.aborted) controller.abort();
  const timer = setTimeout(abort, options.timeoutMs ?? 8000);
  try {
    controller.signal.throwIfAborted();
    const headers = new Headers({Cookie: cookie, Accept: operation.kind === 'sample' ? 'audio/wav' : 'application/json', 'Accept-Encoding': 'identity'});
    if (origin) headers.set('Origin', origin);
    const upstream = await (options.fetch ?? fetch)(`${config.apiOrigin}${path}`, {headers, redirect: 'manual', cache: 'no-store', signal: controller.signal});
    if (upstream.status >= 300 && upstream.status < 400) {await upstream.body?.cancel(); return fail('STAFF_SERVICE_UNAVAILABLE', 502);}
    if (!upstream.ok) {
      const value = await boundedJson(upstream.body, 65536, controller.signal);
      const code = object(value) && object(value.error) && typeof value.error.code === 'string' && /^[A-Z_]{1,64}$/.test(value.error.code) ? value.error.code : 'STAFF_SERVICE_UNAVAILABLE';
      return fail(code, [400, 401, 403, 404, 409, 410, 429, 503].includes(upstream.status) ? upstream.status : 502);
    }
    if (upstream.status !== 200 || upstream.headers.has('set-cookie') || upstream.headers.has('content-encoding')) {await upstream.body?.cancel(); return fail('STAFF_SERVICE_UNAVAILABLE', 502);}
    if (operation.kind === 'sample') {
      const length = upstream.headers.get('content-length'), version = new URL(request.url).searchParams.get('version')!;
      if (upstream.headers.get('content-type') !== 'audio/wav' || !length || !/^[1-9]\d{1,6}$/.test(length) || Number(length) < 44 || Number(length) > 2097152 ||
          upstream.headers.get('x-review-material-version') !== version) {await upstream.body?.cancel(); return fail('STAFF_SERVICE_UNAVAILABLE', 502);}
      const bytes = await boundedBytes(upstream.body, 2097152, controller.signal);
      const view = new DataView(bytes.buffer);
      if (bytes.byteLength !== Number(length) || new TextDecoder().decode(bytes.slice(0, 4)) !== 'RIFF' || new TextDecoder().decode(bytes.slice(8, 12)) !== 'WAVE' ||
          view.getUint32(4, true) + 8 !== bytes.byteLength) return fail('STAFF_SERVICE_UNAVAILABLE', 502);
      return new Response(bytes, {headers: {...privateHeaders, 'Content-Type': 'audio/wav', 'Content-Length': String(bytes.byteLength),
        'Content-Disposition': 'inline; filename="review-sample.wav"', 'X-Review-Material-Version': version, 'Accept-Ranges': 'none'}});
    }
    const value = await boundedJson(upstream.body, 65536, controller.signal);
    if (!(operation.kind === 'queue' ? reviewPageValue(value) : reviewDetailValue(value)) || operation.kind === 'detail' && reviewDetailValue(value) && value.application.id !== operation.id) return fail('STAFF_SERVICE_UNAVAILABLE', 502);
    return new Response(JSON.stringify(value), {headers: {...privateHeaders, 'Content-Type': 'application/json; charset=utf-8'}});
  } catch {return fail(controller.signal.aborted ? 'STAFF_REQUEST_TIMEOUT' : 'STAFF_SERVICE_UNAVAILABLE', 503);}
  finally {clearTimeout(timer); request.signal.removeEventListener('abort', abort);}
}
