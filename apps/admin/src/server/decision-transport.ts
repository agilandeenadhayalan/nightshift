import {decisionValue, policyValue, receiptValue, type DecisionInput} from '../lib/decision-contract.ts';
import {reviewId} from '../lib/review-contract.ts';
import {hex64, object} from '../lib/staff-contract.ts';
import {boundedJson, fail, requestCookies, type Configuration} from './transport.ts';
export type DecisionOperation = {kind: 'policy'} | {kind: 'decision' | 'receipt'; id: string};
export async function proxyDecision(request: Request, operation: DecisionOperation, config: Configuration | null,
    options: {fetch?: typeof fetch; timeoutMs?: number} = {}): Promise<Response> {
  const mutation = operation.kind === 'decision';
  if (request.method !== (mutation ? 'POST' : 'GET') || new URL(request.url).search || operation.kind !== 'policy' && !reviewId.test(operation.id)) return fail('INVALID_REQUEST', 400);
  if (!config) return fail('STAFF_AUTH_UNAVAILABLE', 503);
  const origin = request.headers.get('origin'), site = request.headers.get('sec-fetch-site');
  const host = request.headers.get('host') ?? new URL(request.url).host;
  if (host !== new URL(config.consoleOrigin).host || origin !== null && origin !== config.consoleOrigin || mutation && origin !== config.consoleOrigin || site !== null && !['same-origin', 'none'].includes(site)) return fail('STAFF_ORIGIN_REJECTED', 403);
  let cookie: string;
  try {cookie = requestCookies(request.headers.get('cookie')).split('; ').filter(part => part.startsWith('__Host-nightshift_staff=')).join('; ');} catch {return fail('STAFF_UNAUTHENTICATED', 401);}
  if (!cookie) return fail('STAFF_UNAUTHENTICATED', 401);
  const key = request.headers.get('idempotency-key'), csrf = request.headers.get('x-csrf-token');
  if (operation.kind !== 'policy' && (!key || key.length > 128 || /[\x00-\x1f\x7f]/.test(key))) return fail('INVALID_REVIEW_DECISION', 400);
  if (mutation && (!csrf || !hex64.test(csrf))) return fail('STAFF_CSRF_INVALID', 403);
  if (mutation && request.headers.get('content-type')?.split(';')[0].trim() !== 'application/json') return fail('INVALID_REQUEST', 400);
  const controller = new AbortController(), abort = () => controller.abort();
  request.signal.addEventListener('abort', abort, {once: true}); if (request.signal.aborted) controller.abort();
  const timer = setTimeout(abort, options.timeoutMs ?? 15000);
  try {
    controller.signal.throwIfAborted();
    let input: DecisionInput | undefined;
    if (mutation) {const value = await boundedJson(request.body, 20000, controller.signal); if (!decisionValue(value)) return fail('INVALID_REVIEW_DECISION', 400); input = value;}
    const headers = new Headers({Cookie: cookie, Accept: 'application/json', 'Accept-Encoding': 'identity'});
    if (origin) headers.set('Origin', origin);
    if (operation.kind !== 'policy') headers.set('Idempotency-Key', key!);
    if (mutation) {headers.set('X-CSRF-Token', csrf!); headers.set('Content-Type', 'application/json');}
    const path = operation.kind === 'policy' ? '/v1/admin/listener-review-policy' : `/v1/admin/listener-applications/${operation.id}/${mutation ? 'decisions' : 'decision-receipt'}`;
    const upstream = await (options.fetch ?? fetch)(`${config.apiOrigin}${path}`, {method: request.method, headers, ...(input ? {body: JSON.stringify(input)} : {}), redirect: 'manual', cache: 'no-store', signal: controller.signal});
    if (upstream.status >= 300 && upstream.status < 400) {await upstream.body?.cancel(); return fail('STAFF_SERVICE_UNAVAILABLE', 502);}
    // Up to20 checks and60 reasons with two160-code-point labels each.
    // Four-byte Unicode labels plus JSON framing fit within256KiB.
    const value = await boundedJson(upstream.body, operation.kind === 'policy' ? 262144 : 65536, controller.signal);
    if (!upstream.ok) {
      const code = object(value) && object(value.error) && typeof value.error.code === 'string' && /^[A-Z_]{1,64}$/.test(value.error.code) ? value.error.code : 'STAFF_SERVICE_UNAVAILABLE';
      return fail(code, [400, 401, 403, 404, 409, 429, 503].includes(upstream.status) ? upstream.status : 502);
    }
    if (upstream.status !== 200 || upstream.headers.has('set-cookie') || !(operation.kind === 'policy' ? policyValue(value) : receiptValue(value) && value.applicationId === operation.id &&
      (!input || value.materialVersion === input.expectedMaterialVersion && value.policyVersion === input.policyVersion && value.outcome === input.outcome && value.reasonCode === input.reasonCode))) return fail('STAFF_SERVICE_UNAVAILABLE', 502);
    return new Response(JSON.stringify(value), {headers: {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store, private', Vary: 'Cookie', Pragma: 'no-cache', 'X-Content-Type-Options': 'nosniff'}});
  } catch {return fail(controller.signal.aborted ? 'STAFF_REQUEST_TIMEOUT' : 'STAFF_SERVICE_UNAVAILABLE', 503);}
  finally {clearTimeout(timer); request.signal.removeEventListener('abort', abort);}
}
