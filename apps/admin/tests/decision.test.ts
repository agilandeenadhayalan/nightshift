import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {Ajv2020} from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import {decisionValue, findingsComplete, policyValue, receiptValue, type Outcome} from '../src/lib/decision-contract.ts';
import {proxyDecision, type DecisionOperation} from '../src/server/decision-transport.ts';
import {applicationId} from './review-fixtures.ts';
import {decision, policy, receipt} from './decision-fixtures.ts';
const require = createRequire(import.meta.url), contract = require('@nightshift/contracts/staff.openapi.json');
const ajv = new Ajv2020({strict: true}); (formats as unknown as (instance: Ajv2020) => void)(ajv);
const schema = (name: string) => ajv.compile(contract.components.schemas[name]);
const config = {apiOrigin: 'https://api.example.test', consoleOrigin: 'https://staff.example.test'};
const token = 'a'.repeat(64), csrf = 'b'.repeat(64), key = 'synthetic-command-1';
const op = {kind: 'decision', id: applicationId} as const;
function request(operation: DecisionOperation = op, body: unknown = decision(), headers: Record<string, string> = {}) {
  return new Request(`${config.consoleOrigin}/api/staff/test`, {method: operation.kind === 'decision' ? 'POST' : 'GET',
    headers: {Cookie: `__Host-nightshift_staff=${token}`, Origin: config.consoleOrigin, 'Content-Type': 'application/json', 'X-CSRF-Token': csrf, 'Idempotency-Key': key, ...headers},
    ...(operation.kind === 'decision' ? {body: JSON.stringify(body)} : {})});
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {status});
test('policy, command and receipt validators match the public decision contract', () => {
  for (const [name, value, validate] of [['StaffReviewPolicy', policy, policyValue], ['StaffReviewDecision', decision(), decisionValue], ['StaffReviewReceipt', receipt(), receiptValue]] as const) {
    const valid = schema(name); assert.ok(valid(value)); assert.ok(validate(value));
    for (const field of Object.keys(value)) {const broken = {...value} as Record<string, unknown>; delete broken[field]; assert.equal(valid(broken), false); assert.equal(validate(broken), false);}
    assert.equal(valid({...value, phone: 'private'}), false); assert.equal(validate({...value, phone: 'private'}), false);
  }
  assert.ok(schema('StaffReviewPolicy')({enabled: false, reasonCode: 'REVIEW_POLICY_UNAVAILABLE'}));
  assert.ok(policyValue({enabled: false, reasonCode: 'REVIEW_POLICY_UNAVAILABLE'}));
  assert.equal(policyValue({enabled: false, reasonCode: 'REVIEW_POLICY_UNAVAILABLE', checks: policy.checks}), false);
});
test('explicit findings enforce complete unique checks, evidence and each outcome rule', () => {
  for (const outcome of ['approved', 'rejected', 'needs_information'] as Outcome[]) assert.ok(findingsComplete(policy, decision(outcome)));
  for (const broken of [{...decision(), checks: []}, {...decision(), checks: [decision().checks[0], decision().checks[0]]},
    {...decision(), checks: [{...decision().checks[0], id: 'unknown'}]}, {...decision(), checks: [{...decision().checks[0], evidenceKinds: []}]},
    {...decision(), checks: [{...decision().checks[0], result: 'fail' as const}]}, {...decision('rejected'), checks: decision().checks},
    {...decision('needs_information'), checks: decision().checks}, {...decision(), reasonCode: 'unknown'}]) assert.equal(findingsComplete(policy, broken), false);
});
test('decision proxy forwards frozen command/key and exact CSRF without bearer or extra cookies', async () => {
  const result = await proxyDecision(request(op, decision(), {Authorization: 'Bearer private-synthetic', Cookie: `customer=private; __Host-nightshift_staff=${token}; __Host-nightshift_staff_challenge=${csrf}`}), op, config, {fetch: async (url, options) => {
    assert.equal(url, `${config.apiOrigin}/v1/admin/listener-applications/${applicationId}/decisions`);
    assert.equal(options?.redirect, 'manual'); const headers = new Headers(options?.headers);
    assert.equal(headers.get('cookie'), `__Host-nightshift_staff=${token}`); assert.equal(headers.get('authorization'), null);
    assert.equal(headers.get('origin'), config.consoleOrigin); assert.equal(headers.get('x-csrf-token'), csrf); assert.equal(headers.get('idempotency-key'), key);
    assert.deepEqual(JSON.parse(String(options?.body)), decision()); return json(receipt());
  }});
  assert.equal(result.status, 200); assert.equal(result.headers.get('cache-control'), 'no-store, private');
});
test('wrong origin, missing CSRF/key and extra command fields never dispatch', async () => {
  let calls = 0; const fetcher: typeof fetch = async () => {calls++; return json(receipt());};
  for (const headers of [{Origin: ''}, {'X-CSRF-Token': ''}, {'Idempotency-Key': ''}, {Cookie: '', Authorization: 'Bearer synthetic'}] as Record<string, string>[]) assert.ok((await proxyDecision(request(op, decision(), headers), op, config, {fetch: fetcher})).status >= 400);
  assert.equal((await proxyDecision(request(op, {...decision(), internalReason: 'private'}), op, config, {fetch: fetcher})).status, 400);
  assert.equal(calls, 0);
});
test('receipt recovery is GET/header scoped and rejects mismatched or private results', async () => {
  const recovery = {kind: 'receipt', id: applicationId} as const;
  const result = await proxyDecision(request(recovery), recovery, config, {fetch: async (url, options) => {
    assert.equal(url, `${config.apiOrigin}/v1/admin/listener-applications/${applicationId}/decision-receipt`); assert.equal(options?.method, 'GET');
    assert.equal(options?.body, undefined); assert.equal(new Headers(options?.headers).get('idempotency-key'), key); return json(receipt());
  }}); assert.equal(result.status, 200);
  for (const body of [{...receipt(), applicationId: '2a1eec02-9d54-4c93-8806-5b9a763785d2'}, {...receipt(), internalReason: 'private'}]) assert.equal((await proxyDecision(request(recovery), recovery, config, {fetch: async () => json(body)})).status, 502);
  assert.equal((await proxyDecision(request(op), op, config, {fetch: async () => json(receipt(decision('rejected')))})).status, 502);
});
test('maximal valid multilingual policy passes a bounded256KiB response allowance', async () => {
  const label = {en: '😀'.repeat(160), ta: '😀'.repeat(155) + 'தமிழ்'};
  const maximum = {...policy, checks: Array.from({length: 20}, (_, n) => ({...policy.checks[0], id: `check_${n}`, label})),
    reasons: Object.fromEntries(['approved', 'rejected', 'needs_information'].map(outcome => [outcome, Array.from({length: 20}, (_, n) => ({code: `reason_${n}`, label}))]))};
  assert.ok(Buffer.byteLength(JSON.stringify(maximum)) > 65536); assert.ok(schema('StaffReviewPolicy')(maximum)); assert.ok(policyValue(maximum));
  const policyOp = {kind: 'policy'} as const;
  assert.equal((await proxyDecision(request(policyOp), policyOp, config, {fetch: async () => json(maximum)})).status, 200);
  assert.equal((await proxyDecision(request(policyOp), policyOp, config, {fetch: async () => json({padding: 'x'.repeat(262144)})})).status, 503);
});
test('uncertain redirect and error responses cannot leak private data or invent receipts', async () => {
  let calls = 0;
  assert.equal((await proxyDecision(request(), op, config, {fetch: async (_url, options) => {calls++; assert.equal(options?.redirect, 'manual'); return new Response(null, {status: 307, headers: {Location: 'https://foreign.test'}});}})).status, 502);
  assert.equal(calls, 1);
  const response = await proxyDecision(request(), op, config, {fetch: async () => json({error: {code: 'REVIEW_MATERIAL_CHANGED', message: 'private-synthetic'}}, 409)});
  assert.equal(response.status, 409); assert.doesNotMatch(await response.text(), /private-synthetic/);
});
