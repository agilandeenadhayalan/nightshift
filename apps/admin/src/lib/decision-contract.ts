import {exactKeys, hex64, object, utcTime} from './staff-contract.ts';
import {reviewId} from './review-contract.ts';
export const outcomes = ['approved', 'rejected', 'needs_information'] as const;
export const evidenceKinds = ['application', 'voice_sample', 'self_declaration'] as const;
export type Outcome = typeof outcomes[number];
export type EvidenceKind = typeof evidenceKinds[number];
export type LocalizedText = {en: string; ta: string};
export type PolicyCheck = {id: string; label: LocalizedText; requiredForApproval: boolean; evidenceKinds: EvidenceKind[]};
export type EnabledPolicy = {enabled: true; reasonCode: null; version: string; digest: string; checks: PolicyCheck[]; reasons: Record<Outcome, {code: string; label: LocalizedText}[]>};
export type ReviewPolicy = EnabledPolicy | {enabled: false; reasonCode: 'REVIEW_POLICY_UNAVAILABLE'};
export type Finding = {id: string; result: 'pass' | 'fail' | 'not_checked'; evidenceKinds: EvidenceKind[]};
export type DecisionInput = {expectedMaterialVersion: string; policyVersion: string; policyDigest: string; outcome: Outcome; checks: Finding[]; reasonCode: string};
export type DecisionReceipt = {decisionId: string; applicationId: string; outcome: Outcome; policyVersion: string; materialVersion: string; reasonCode: string; recordedAt: string;
  effects: {entitlement: 'not_applicable' | 'pending' | 'active' | 'withheld'; notification: 'pending' | 'available' | 'suppressed'}};
const slug = (value: unknown): value is string => typeof value === 'string' && /^[a-z][a-z0-9_]{0,63}$/.test(value);
const boundedText = (value: unknown, max: number): value is string => typeof value === 'string' && [...value].length >= 1 && [...value].length <= max && !/[\x00-\x1f\x7f]/.test(value);
const translated = (value: unknown) => object(value) && exactKeys(value, ['en', 'ta']) && boundedText(value.en, 160) && boundedText(value.ta, 160);
const evidence = (value: unknown): value is EvidenceKind[] => Array.isArray(value) && value.length <= 3 && new Set(value).size === value.length && value.every(kind => evidenceKinds.includes(kind));
export function policyValue(value: unknown): value is ReviewPolicy {
  if (!object(value)) return false;
  if (value.enabled === false) return exactKeys(value, ['enabled', 'reasonCode']) && value.reasonCode === 'REVIEW_POLICY_UNAVAILABLE';
  if (value.enabled !== true || value.reasonCode !== null || !exactKeys(value, ['enabled', 'reasonCode', 'version', 'digest', 'checks', 'reasons']) ||
      !boundedText(value.version, 80) || typeof value.digest !== 'string' || !hex64.test(value.digest) || !Array.isArray(value.checks) || value.checks.length < 1 || value.checks.length > 20) return false;
  if (!value.checks.every(check => object(check) && exactKeys(check, ['id', 'label', 'requiredForApproval', 'evidenceKinds']) && slug(check.id) && translated(check.label) &&
      typeof check.requiredForApproval === 'boolean' && evidence(check.evidenceKinds) && check.evidenceKinds.length > 0) || new Set(value.checks.map(check => check.id)).size !== value.checks.length || !value.checks.some(check => check.requiredForApproval)) return false;
  const reasons = value.reasons;
  return object(reasons) && exactKeys(reasons, [...outcomes]) && outcomes.every(outcome => {
    const entries = reasons[outcome];
    return Array.isArray(entries) && entries.length >= 1 && entries.length <= 20 && entries.every(reason => object(reason) && exactKeys(reason, ['code', 'label']) && slug(reason.code) && translated(reason.label)) && new Set(entries.map(reason => reason.code)).size === entries.length;
  });
}
export function decisionValue(value: unknown): value is DecisionInput {
  if (!object(value) || !exactKeys(value, ['expectedMaterialVersion', 'policyVersion', 'policyDigest', 'outcome', 'checks', 'reasonCode'])) return false;
  return typeof value.expectedMaterialVersion === 'string' && hex64.test(value.expectedMaterialVersion) && boundedText(value.policyVersion, 80) &&
    typeof value.policyDigest === 'string' && hex64.test(value.policyDigest) && outcomes.includes(value.outcome as Outcome) && slug(value.reasonCode) &&
    Array.isArray(value.checks) && value.checks.length >= 1 && value.checks.length <= 20 && new Set(value.checks.map(check => object(check) ? check.id : null)).size === value.checks.length &&
    value.checks.every(check => object(check) && exactKeys(check, ['id', 'result', 'evidenceKinds']) && slug(check.id) && ['pass', 'fail', 'not_checked'].includes(String(check.result)) && evidence(check.evidenceKinds) &&
      (check.result === 'not_checked' ? check.evidenceKinds.length === 0 : check.evidenceKinds.length > 0));
}
export function receiptValue(value: unknown): value is DecisionReceipt {
  return object(value) && exactKeys(value, ['decisionId', 'applicationId', 'outcome', 'policyVersion', 'materialVersion', 'reasonCode', 'recordedAt', 'effects']) &&
    typeof value.decisionId === 'string' && reviewId.test(value.decisionId) && typeof value.applicationId === 'string' && reviewId.test(value.applicationId) && outcomes.includes(value.outcome as Outcome) &&
    boundedText(value.policyVersion, 80) && typeof value.materialVersion === 'string' && hex64.test(value.materialVersion) && slug(value.reasonCode) && utcTime(value.recordedAt) &&
    object(value.effects) && exactKeys(value.effects, ['entitlement', 'notification']) && ['not_applicable', 'pending', 'active', 'withheld'].includes(String(value.effects.entitlement)) &&
    ['pending', 'available', 'suppressed'].includes(String(value.effects.notification)) &&
    (value.outcome === 'approved' ? value.effects.entitlement !== 'not_applicable' : value.effects.entitlement === 'not_applicable');
}
export function findingsComplete(policy: EnabledPolicy, input: DecisionInput): boolean {
  return decisionValue(input) && input.policyVersion === policy.version && input.policyDigest === policy.digest && input.checks.length === policy.checks.length &&
    policy.reasons[input.outcome].some(reason => reason.code === input.reasonCode) && policy.checks.every(check => {
      const result = input.checks.find(item => item.id === check.id);
      return result && result.evidenceKinds.every(kind => check.evidenceKinds.includes(kind)) && (input.outcome !== 'approved' || !check.requiredForApproval || result.result === 'pass');
    }) && (input.outcome !== 'rejected' || input.checks.some(check => check.result === 'fail')) &&
    (input.outcome !== 'needs_information' || input.checks.some(check => check.result !== 'pass'));
}
