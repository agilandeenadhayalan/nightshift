import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {Ajv2020} from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import {accessRequestValue, sessionValue, statusValue} from '../src/lib/staff-contract.ts';
import {proxyStaff} from '../src/server/transport.ts';
import {reviewDetailValue, reviewPageValue} from '../src/lib/review-contract.ts';
import {detail, page} from './review-fixtures.ts';
const require = createRequire(import.meta.url);
const contract = require('@nightshift/contracts/staff.openapi.json');
const ajv = new Ajv2020({strict: true});
// ajv-formats publishes both CJS and ESM declarations.
const addFormats = formats as unknown as (instance: Ajv2020) => void;
addFormats(ajv);
const validate = (name: string) => ajv.compile(contract.components.schemas[name]);
const session = {staff: {id: 'c874c564-4701-445c-a090-cceab31ba9c9'}, permissions: ['listener.review.read'], expiresAt: '2030-01-01T00:00:00.000Z', csrfToken: 'a'.repeat(64)};
test('strict staff session decoder matches public schema and rejects private fields', () => {
  const schema = validate('StaffSession');
  assert.ok(schema(session)); assert.ok(sessionValue(session));
  for (const broken of [{...session, permissions: ['admin']}, {...session, phone: 'synthetic'}, {...session, staff: {}}, {...session, csrfToken: null}]) {
    assert.equal(schema(broken), false); assert.equal(sessionValue(broken), false);
  }
  for (const key of Object.keys(session)) {
    const broken = {...session} as Record<string, unknown>; delete broken[key];
    assert.equal(schema(broken), false); assert.equal(sessionValue(broken), false);
  }
});
test('both staff status responses require explicit reasonCode', () => {
  const schema = validate('StaffAuthStatus');
  for (const value of [{configured: false, available: false, reasonCode: 'STAFF_AUTH_UNAVAILABLE'}, {configured: true, available: true, reasonCode: null}]) {
    assert.ok(schema(value)); assert.ok(statusValue(value));
    const missing = {configured: value.configured, available: value.available};
    assert.equal(schema(missing), false); assert.equal(statusValue(missing), false);
  }
});
test('native receipt and explicit access-administration permission match the separate public schema', () => {
  const authority = {...session, permissions: ['staff.access.manage']};
  assert.ok(validate('StaffSession')(authority)); assert.ok(sessionValue(authority));
  const schema = validate('StaffAccessRequest');
  const receipt = {requestId: session.staff.id, accountReference: 'a874c564-4701-445c-a090-cceab31ba9c9', status: 'pending', expiresAt: session.expiresAt};
  for (const status of ['pending', 'provisioned']) {
    const value = {...receipt, status}; assert.ok(schema(value)); assert.ok(accessRequestValue(value));
  }
  for (const broken of [{...receipt, status: 'admin'}, {...receipt, providerSubject: 'private'}, {...receipt, requestId: 'invalid'}]) {
    assert.equal(schema(broken), false); assert.equal(accessRequestValue(broken), false);
  }
});
test('challenge and sanitized proxy errors conform to public staff contract', async () => {
  const request = new Request('https://staff.example.test/api/staff/auth/challenge', {method: 'POST', headers: {'Origin': 'https://staff.example.test', 'Content-Type': 'application/json'}, body: '{}'});
  const challenge = {csrfToken: 'a'.repeat(64), expiresAt: session.expiresAt};
  const result = await proxyStaff(request, 'challenge', {apiOrigin: 'https://api.example.test', consoleOrigin: 'https://staff.example.test'}, {fetch: async () => new Response(JSON.stringify(challenge))});
  assert.ok(validate('StaffChallenge')(await result.json()));
  const denied = await proxyStaff(new Request('https://staff.example.test/api/staff/session'), 'session', null);
  assert.ok(validate('StaffError')(await denied.json()));
});
test('submitted review queue decoder matches public contract without private fields', () => {
  const schema = validate('StaffReviewQueue');
  assert.ok(schema(page)); assert.ok(reviewPageValue(page));
  for (const key of Object.keys(page)) {
    const broken = {...page} as Record<string, unknown>; delete broken[key];
    assert.equal(schema(broken), false); assert.equal(reviewPageValue(broken), false);
  }
  for (const broken of [{...page, decisionsEnabled: true}, {...page, nextCursor: 'invalid'}, {...page, phone: 'private'},
    {...page, items: [{...page.items[0], state: 'needs_information'}]}, {...page, items: [{...page.items[0], languages: ['fr']}]},
    {...page, items: [{...page.items[0], languages: ['ta', 'ta']}]}, {...page, items: [{...page.items[0], voiceSampleAvailable: null}]}]) {
    assert.equal(schema(broken), false); assert.equal(reviewPageValue(broken), false);
  }
  assert.equal(reviewPageValue({...page, items: [page.items[0], page.items[0]]}), false);
});
test('review detail exposes only submitted self-declared data with exact material descriptor', () => {
  const schema = validate('StaffReviewDetail');
  assert.ok(schema(detail)); assert.ok(reviewDetailValue(detail));
  for (const key of Object.keys(detail.application)) {
    const application = {...detail.application} as Record<string, unknown>; delete application[key];
    assert.equal(schema({...detail, application}), false); assert.equal(reviewDetailValue({...detail, application}), false);
  }
  for (const application of [{...detail.application, dateOfBirth: 'private'}, {...detail.application, providerUid: 'private'},
    {...detail.application, adultStatus: 'verified'}, {...detail.application, topics: ['romance']}, {...detail.application, state: 'draft'},
    {...detail.application, materialVersion: 'invalid'}, {...detail.application, voiceSample: {...detail.application.voiceSample, byteLength: 2097153}}]) {
    assert.equal(schema({...detail, application}), false); assert.equal(reviewDetailValue({...detail, application}), false);
  }
  const absent = {...detail, application: {...detail.application, voiceSample: null}};
  assert.ok(schema(absent)); assert.ok(reviewDetailValue(absent));
});
