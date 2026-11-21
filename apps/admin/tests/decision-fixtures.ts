import type {DecisionInput, DecisionReceipt, EnabledPolicy, Outcome} from '../src/lib/decision-contract.ts';
import {applicationId, materialVersion} from './review-fixtures.ts';
export const policy: EnabledPolicy = {enabled: true, reasonCode: null, version: 'synthetic-fixture-v1', digest: 'e'.repeat(64),
  checks: [{id: 'fixture_details', label: {en: 'Synthetic application check', ta: 'செயற்கை விண்ணப்பத்தின் சோதனை சரிபார்ப்பு'}, requiredForApproval: true, evidenceKinds: ['application', 'self_declaration']}],
  reasons: {approved: [{code: 'fixture_approved', label: {en: 'Synthetic criteria met', ta: 'செயற்கை சோதனை நிபந்தனைகள் நிறைவேறின'}}],
    rejected: [{code: 'fixture_rejected', label: {en: 'Synthetic criterion failed', ta: 'செயற்கை சோதனை நிபந்தனை நிறைவேறவில்லை'}}],
    needs_information: [{code: 'fixture_missing', label: {en: 'Synthetic information missing', ta: 'செயற்கை சோதனைக்கான தகவல் தேவை'}}]}};
export function decision(outcome: Outcome = 'approved'): DecisionInput {return {expectedMaterialVersion: materialVersion, policyVersion: policy.version, policyDigest: policy.digest, outcome,
  checks: [{id: 'fixture_details', result: outcome === 'approved' ? 'pass' : outcome === 'rejected' ? 'fail' : 'not_checked', evidenceKinds: outcome === 'needs_information' ? [] : ['application']}], reasonCode: policy.reasons[outcome][0].code};}
export function receipt(input = decision()): DecisionReceipt {return {decisionId: '7a1eec02-9d54-4c93-8806-5b9a763785d7', applicationId, outcome: input.outcome, policyVersion: input.policyVersion,
  materialVersion: input.expectedMaterialVersion, reasonCode: input.reasonCode, recordedAt: '2026-11-21T10:00:00.000Z', effects: {entitlement: input.outcome === 'approved' ? 'pending' : 'not_applicable', notification: 'pending'}};}
