import { test } from 'node:test';
import assert from 'node:assert/strict';
import { inspect } from 'node:util';
import { Msg91OtpProvider } from '../src/identity/msg91';
import { ApiError } from '../src/errors';

const phone = '+919999999999';
const reference = '35686b674f75313534303531';
const accessToken = 'fixtureHeader.fixturePayload.fixtureSignature';
const config = { authKey: 'fixture-auth-key-not-a-credential', widgetId: 'fixture-widget' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

function provider(responses: (Response | Error)[]) {
  const calls: { url: string; init: RequestInit }[] = [];
  const transport: typeof fetch = async (input, init) => {
    calls.push({ url: String(input), init: init! });
    const next = responses.shift();
    if (next instanceof Error) throw next;
    assert.ok(next, 'Unexpected provider request');
    return next;
  };
  return { instance: new Msg91OtpProvider(config, transport), calls };
}

function isUnavailable(error: unknown): boolean {
  assert.ok(error instanceof ApiError);
  assert.equal(error.status, 503);
  assert.equal(error.code, 'OTP_PROVIDER_UNAVAILABLE');
  const diagnostic = inspect(error);
  for (const secret of [phone, phone.slice(1), config.authKey, accessToken, '123456', 'sensitive-provider-response']) {
    assert.equal(diagnostic.includes(secret), false);
  }
  assert.equal('cause' in error, false);
  return true;
}

test('MSG91 send uses fixed POST endpoint and keeps identifier/authentication out of URLs', async () => {
  const { instance, calls } = provider([json({ type: 'success', message: reference })]);
  assert.deepEqual(await instance.send(phone), { reference });
  const call = calls[0]!;
  assert.equal(call.url, 'https://api.msg91.com/api/v5/widget/sendOtp');
  assert.equal(call.init.method, 'POST');
  assert.equal(call.init.redirect, 'error');
  assert.equal(call.init.cache, 'no-store');
  assert.equal((call.init.headers as Record<string, string>).authkey, config.authKey);
  assert.deepEqual(JSON.parse(call.init.body as string), { widgetId: config.widgetId, identifier: phone.slice(1) });
  assert.equal(inspect(instance).includes(config.authKey), false);
  assert.equal(JSON.stringify(instance).includes(config.authKey), false);
});

test('verification binds reqId and consumes token proof before accepting the exact phone', async () => {
  const { instance, calls } = provider([
    json({ type: 'success', message: accessToken }),
    json({ type: 'success', message: phone.slice(1) }),
  ]);
  assert.equal(await instance.verify(phone, '123456', reference), 'valid');
  assert.equal(calls.length, 2);
  assert.equal(calls[0]!.url, 'https://api.msg91.com/api/v5/widget/verifyOtp');
  assert.deepEqual(JSON.parse(calls[0]!.init.body as string), { widgetId: config.widgetId, reqId: reference, otp: '123456' });
  assert.equal(calls[1]!.url, 'https://api.msg91.com/api/v5/widget/verifyAccessToken');
  assert.deepEqual(JSON.parse(calls[1]!.init.body as string), { 'access-token': accessToken });
});

test('HTTP 200 error response is not successful OTP delivery', async () => {
  const { instance, calls } = provider([json({ type: 'error', message: 'Invalid Widget Id' })]);
  await assert.rejects(instance.send(phone), isUnavailable);
  assert.equal(calls.length, 1);
  for (const inconsistent of [{ code: 705 }, { status: 'fail' }, { hasError: true }]) {
    await assert.rejects(provider([json({ type: 'success', message: reference, ...inconsistent })]).instance.send(phone), isUnavailable);
  }
});

test('only documented invalid-code response returns wrong and does not verify a token', async () => {
  const { instance, calls } = provider([json({ type: 'error', code: 705, message: 'invalid otp' })]);
  assert.equal(await instance.verify(phone, '123456', reference), 'wrong');
  assert.equal(calls.length, 1);
  for (const body of [{ type: 'success', code: 705 }, { type: 'error', code: '705' }, { type: 'error', code: 704 }]) {
    await assert.rejects(provider([json(body)]).instance.verify(phone, '123456', reference), isUnavailable);
  }
});

test('missing, untrusted, replayed or mismatched token proof never authenticates', async () => {
  for (const body of [
    { type: 'success' }, { type: 'success', message: '918888888888' },
    { type: 'success', message: phone.slice(1), hasError: true },
    { type: 'success', message: phone.slice(1), code: 702 },
    { type: 'error', code: 701, message: 'invalid access-token' },
    { type: 'error', code: 702, message: 'access-token already verified' },
  ]) {
    const { instance } = provider([json({ type: 'success', message: accessToken }), json(body)]);
    await assert.rejects(instance.verify(phone, '123456', reference), isUnavailable);
  }
  const { instance, calls } = provider([json({ type: 'success', message: 'OTP verified successfully' })]);
  await assert.rejects(instance.verify(phone, '123456', reference), isUnavailable);
  assert.equal(calls.length, 1);
});

test('invalid input never leaves the server and invalid config never exposes supplied values', async () => {
  const { instance, calls } = provider([]);
  for (const invalid of ['919999999999', '+441234567890', '+91invalid', '+919999999999?otp=123456']) {
    await assert.rejects(instance.send(invalid), (e: unknown) => e instanceof ApiError && e.code === 'OTP_INVALID_INPUT');
  }
  await assert.rejects(instance.verify(phone, '12345', reference), ApiError);
  await assert.rejects(instance.verify(phone, '123456', 'bad/challenge'), ApiError);
  assert.equal(calls.length, 0);
  assert.throws(() => new Msg91OtpProvider({ ...config, authKey: 'private\r\nvalue' }), /must be configured/);
  assert.throws(() => new Msg91OtpProvider({ ...config, timeoutMs: 5001 }), /timeout/);
});

test('malformed, oversized, redirect and failing responses expose only safe provider errors', async () => {
  for (const response of [
    new Response('sensitive-provider-response'), json([]), json(null),
    json({ type: 'success', message: reference }, 401),
    new Response(null, { status: 302, headers: { location: 'https://elsewhere.invalid' } }),
    new Response('x'.repeat(32769)),
    new Response('{}', { headers: { 'content-length': '999999999' } }),
    new Error(`sensitive-provider-response ${phone} ${config.authKey} ${accessToken} 123456`),
  ]) {
    await assert.rejects(provider([response]).instance.send(phone), isUnavailable);
  }
});

test('request deadline aborts a stalled transport without automatic resend', async () => {
  let calls = 0;
  let signal: AbortSignal | null | undefined;
  const transport: typeof fetch = (_input, init) => {
    calls++;
    signal = init?.signal;
    return new Promise(() => {});
  };
  const instance = new Msg91OtpProvider({ ...config, timeoutMs: 20 }, transport);
  await assert.rejects(instance.send(phone), isUnavailable);
  assert.equal(calls, 1);
  assert.equal(signal?.aborted, true);
});

test('deadline covers response body and ambiguous token-consumption response', async () => {
  let signal: AbortSignal | null | undefined;
  let cancelled = false;
  const transport: typeof fetch = async (_input, init) => {
    signal = init?.signal;
    return new Response(new ReadableStream({ cancel() { cancelled = true; } }));
  };
  const instance = new Msg91OtpProvider({ ...config, timeoutMs: 20 }, transport);
  await assert.rejects(instance.send(phone), isUnavailable);
  assert.equal(signal?.aborted, true);
  // Even a test transport which ignores AbortSignal has its body cancelled.
  assert.equal(cancelled, true);
  const { instance: ambiguous, calls } = provider([
    json({ type: 'success', message: accessToken }), new Error('sensitive-provider-response'),
  ]);
  await assert.rejects(ambiguous.verify(phone, '123456', reference), isUnavailable);
  assert.equal(calls.length, 2);
});
