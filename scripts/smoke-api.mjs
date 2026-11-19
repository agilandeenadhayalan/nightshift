// Real HTTP control-plane check. No RTC join or microphone is simulated or claimed.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const base = (process.env.API_BASE_URL ?? 'http://127.0.0.1:3000').replace(/\/$/, '');
const key = process.env.DEV_ACCESS_KEY;
assert.ok(key?.length >= 24, 'Load the private DEV_ACCESS_KEY from your local environment');
const sessions = [];
let currentCall;

async function request(method, path, token, body, idempotencyKey = randomUUID()) {
  const response = await fetch(`${base}/v1${path}`, {
    method, signal: AbortSignal.timeout(10_000),
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Idempotency-Key': idempotencyKey },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const data = await response.json();
  // Log only stable status/code on failure; responses can contain credentials.
  if (!response.ok) throw new Error(`${method} ${path}: ${response.status} ${data.error?.code ?? 'UNKNOWN'}`);
  return data;
}

try {
  assert.equal((await request('GET', '/health')).status, 'ok');
  for (const handle of ['customer', 'listener']) {
    const session = await request('POST', '/auth/dev', undefined, { handle, accessKey: key, deviceId: `http-smoke-${handle}` });
    sessions.push(session);
  }
  const [customer, listener] = sessions;
  if (process.env.SMOKE_CALL_ID) {
    for (const session of sessions) {
      const call = await request('GET', `/calls/${process.env.SMOKE_CALL_ID}`, session.token);
      assert.equal(call.id, process.env.SMOKE_CALL_ID);
      assert.equal(call.state, 'ended');
      assert.equal(call.chargeMicrocredits, 0);
    }
    console.log(JSON.stringify({ result: 'passed', callId: process.env.SMOKE_CALL_ID,
      checks: ['both participants retain completed history after API restart'], mediaVerification: 'NOT performed' }, null, 2));
  } else {
  await request('PUT', '/me/mode', customer.token, { mode: 'customer' });
  await request('PUT', '/me/mode', listener.token, { mode: 'listener' });
  await request('PUT', '/me/availability', listener.token, { online: true });
  await request('POST', '/presence/heartbeat', listener.token);
  const directory = await request('GET', '/listeners?language=ta', customer.token);
  assert.ok(directory.items.some(item => item.id === listener.user.id && item.available));
  const invitationKey = randomUUID();
  const body = { listenerId: listener.user.id, quoteId: 'test-audio-v1' };
  currentCall = await request('POST', '/calls', customer.token, body, invitationKey);
  const repeated = await request('POST', '/calls', customer.token, body, invitationKey);
  assert.equal(repeated.id, currentCall.id);
  assert.equal((await request('GET', '/snapshot', listener.token)).activeCall.id, currentCall.id);
  currentCall = await request('POST', `/calls/${currentCall.id}/accept`, listener.token, { expectedVersion: currentCall.version });
  assert.equal(currentCall.state, 'connecting');
  // No media readiness is reported: accepted-but-unjoined calls must cost zero.
  currentCall = await request('POST', `/calls/${currentCall.id}/end`, customer.token, { expectedVersion: currentCall.version });
  assert.equal(currentCall.state, 'ended');
  assert.equal(currentCall.chargeMicrocredits, 0);
  assert.equal(currentCall.connectedMs, 0);
  for (const session of sessions) {
    const history = await request('GET', '/calls', session.token);
    const receipt = history.items.find(call => call.id === currentCall.id);
    assert.equal(receipt?.state, 'ended');
    assert.equal(receipt?.chargeMicrocredits, 0);
    assert.equal((await request('GET', '/snapshot', session.token)).activeCall, null);
  }
  console.log(JSON.stringify({ result: 'passed', callId: currentCall.id, checks: [
    'HTTP authentication', 'online listener discovery', 'idempotent invitation', 'listener accepts',
    'customer ends', 'zero charge without media', 'same completed call in both histories', 'claims released',
  ], mediaVerification: 'NOT performed: two phones and Agora test credentials required' }, null, 2));
  }
} finally {
  for (const session of sessions) {
    // Logout ends any abandoned test encounter and clears presence.
    await request('POST', '/auth/logout', session.token).catch(() => {});
  }
}
