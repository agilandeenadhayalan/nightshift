'use client';
import {useEffect, useRef, useState} from 'react';
import {findingsComplete, policyValue, receiptValue, type DecisionInput, type DecisionReceipt, type EnabledPolicy, type EvidenceKind, type Finding, type Outcome, type ReviewPolicy} from '../lib/decision-contract';
import {object, type StaffSession} from '../lib/staff-contract';
import type {ReviewApplication} from '../lib/review-contract';

const outcomeLabels: Record<Outcome, string> = {approved: 'Approve', rejected: 'Reject', needs_information: 'Request more information'};
const evidenceLabels: Record<EvidenceKind, string> = {application: 'Application details', voice_sample: 'Current voice sample', self_declaration: 'Self-declared adult status'};
type Ticket = {key: string; body: DecisionInput};
type Stage = 'loading' | 'form' | 'confirm' | 'sending' | 'uncertain' | 'recovering' | 'retry' | 'receipt' | 'error';
export default function ReviewDecision({application, session, enabled, onAccessLost, onStale, onRecorded}: {
  application: ReviewApplication; session: StaffSession; enabled: boolean; onAccessLost: () => void; onStale: () => void; onRecorded: () => void;
}) {
  const [policy, setPolicy] = useState<ReviewPolicy | null>(null), [stage, setStage] = useState<Stage>('loading');
  const [findings, setFindings] = useState<Record<string, Partial<Finding>>>({});
  const [outcome, setOutcome] = useState<Outcome | ''>(''), [reason, setReason] = useState('');
  const [language, setLanguage] = useState<'en' | 'ta'>('en'), [error, setError] = useState('');
  const [ticket, setTicket] = useState<Ticket | null>(null), [receipt, setReceipt] = useState<DecisionReceipt | null>(null);
  const generation = useRef(0), pending = useRef<AbortController | null>(null), active = useRef(false);
  const permitted = ['listener.review.read', 'listener.review.evidence.read', 'listener.review.decide'].every(permission => session.permissions.includes(permission as typeof session.permissions[number]));
  useEffect(() => {
    const current = ++generation.current, controller = new AbortController(); pending.current = controller;
    const timer = setTimeout(() => controller.abort(), 18000);
    void (async () => {
      try {
        const response = await fetch('/api/staff/listener-review-policy', {credentials: 'same-origin', cache: 'no-store', redirect: 'error', signal: controller.signal});
        const body: unknown = await response.json();
        if (current !== generation.current) return;
        if ([401, 403].includes(response.status)) {onAccessLost(); return;}
        if (!response.ok || !policyValue(body)) throw Error('Invalid policy');
        setPolicy(body); setStage('form');
      } catch {if (current === generation.current) {setStage('error'); setError('The review policy could not be confirmed. Refresh the application before deciding.');}}
      finally {clearTimeout(timer);}
    })();
    return () => {++generation.current; controller.abort(); pending.current?.abort();};
  }, [onAccessLost]);
  const ready = permitted && enabled && policy?.enabled === true;
  const input: DecisionInput | null = ready && outcome ? {expectedMaterialVersion: application.materialVersion, policyVersion: policy.version, policyDigest: policy.digest,
    outcome, reasonCode: reason, checks: policy.checks.map(check => ({id: check.id, ...findings[check.id]}) as Finding)} : null;
  const complete = !!input && findingsComplete(policy as EnabledPolicy, input);
  const changeFinding = (id: string, result: Finding['result']) => setFindings(old => ({...old, [id]: {id, result, evidenceKinds: result === 'not_checked' ? [] : old[id]?.evidenceKinds ?? []}}));
  const request = async (command: Ticket, recovery: boolean) => {
    if (active.current) return;
    active.current = true;
    const current = ++generation.current, controller = new AbortController(); pending.current?.abort(); pending.current = controller;
    setStage(recovery ? 'recovering' : 'sending'); setError('');
    const timer = setTimeout(() => controller.abort(), 18000);
    try {
      const response = await fetch(`/api/staff/listener-applications/${application.id}/${recovery ? 'decision-receipt' : 'decisions'}`, {
        method: recovery ? 'GET' : 'POST', credentials: 'same-origin', cache: 'no-store', redirect: 'error', signal: controller.signal,
        headers: {'Idempotency-Key': command.key, ...(recovery ? {} : {'Content-Type': 'application/json', 'X-CSRF-Token': session.csrfToken})},
        ...(recovery ? {} : {body: JSON.stringify(command.body)}),
      });
      const body: unknown = await response.json();
      if (current !== generation.current) return;
      if (Date.parse(session.expiresAt) <= Date.now() || [401, 403].includes(response.status)) {onAccessLost(); return;}
      const code = object(body) && object(body.error) ? body.error.code : null;
      if (recovery && response.status === 404 && code === 'REVIEW_DECISION_NOT_FOUND') {setStage('retry'); return;}
      if (!recovery && (response.status === 409 || response.status === 404 || code === 'REVIEW_POLICY_UNAVAILABLE')) {setFindings({}); setTicket(null); onStale(); return;}
      if (!recovery && response.status === 400) {setStage('form'); setTicket(null); setError('The findings were not accepted. Check every policy result, reason and current evidence access before confirming again.'); return;}
      if (!response.ok || !receiptValue(body) || body.applicationId !== application.id || body.materialVersion !== command.body.expectedMaterialVersion ||
          body.outcome !== command.body.outcome || body.policyVersion !== command.body.policyVersion || body.reasonCode !== command.body.reasonCode) throw Error('Uncertain response');
      setReceipt(body); setStage('receipt'); setFindings({}); onRecorded();
    } catch {if (current === generation.current) {setStage('uncertain'); setError('The result is not confirmed. Check the decision receipt before retrying.');}}
    finally {clearTimeout(timer); active.current = false;}
  };
  const confirm = () => {
    if (!input || !complete || active.current) return;
    const frozen = {key: crypto.randomUUID(), body: structuredClone(input)};
    setTicket(frozen); void request(frozen, false);
  };
  return <section className="decision-panel" aria-labelledby="decision-title">
    <h3 id="decision-title">Review decision</h3>
    <p>Review findings are human judgments. A voice sample and self-declared adulthood do not verify age, gender or identity.</p>
    {stage === 'loading' && <p role="status">Checking the approved review policy…</p>}
    {stage === 'error' && <p role="alert">{error}</p>}
    {stage === 'form' && !ready && <p role="status">{!policy?.enabled || !enabled ? 'Review decisions are unavailable until an approved policy is configured. You can continue reading submitted material.' : 'Your staff account does not have permission to record review decisions.'}</p>}
    {ready && stage === 'form' && <>
      <p>Policy version: <strong className="opaque-reference">{policy.version}</strong></p>
      <label className="decision-language">Checklist language<select value={language} onChange={event => setLanguage(event.target.value as 'en' | 'ta')}><option value="en">English</option><option value="ta">தமிழ்</option></select></label>
      <p className="muted">Read the current application. Play the current sample before citing voice evidence. Select each finding yourself; nothing is checked automatically.</p>
      {policy.checks.map(check => <fieldset key={check.id} className="decision-check"><legend lang={language}>{check.label[language]}</legend>
        {check.requiredForApproval && <p className="muted">Must pass for approval</p>}
        <label>Finding<select aria-label={`Finding: ${check.label.en}`} value={findings[check.id]?.result ?? ''} onChange={event => changeFinding(check.id, event.target.value as Finding['result'])}>
          <option value="" disabled>Choose a finding</option><option value="pass">Pass</option><option value="fail">Fail</option><option value="not_checked">Not checked / information missing</option>
        </select></label>
        {findings[check.id]?.result && findings[check.id]?.result !== 'not_checked' && <div className="decision-evidence"><p>Evidence used</p>{check.evidenceKinds.map(kind => <label key={kind}>
          <input type="checkbox" checked={findings[check.id]?.evidenceKinds?.includes(kind) ?? false} disabled={kind === 'voice_sample' && !application.voiceSample}
            onChange={event => setFindings(old => ({...old, [check.id]: {...old[check.id], evidenceKinds: event.target.checked ? [...(old[check.id]?.evidenceKinds ?? []), kind] : (old[check.id]?.evidenceKinds ?? []).filter(value => value !== kind)}}))} />{evidenceLabels[kind]}</label>)}</div>}
      </fieldset>)}
      <label className="decision-field">Outcome<select value={outcome} onChange={event => {setOutcome(event.target.value as Outcome); setReason('');}}><option value="" disabled>Choose an outcome</option>{Object.entries(outcomeLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
      {outcome && <label className="decision-field">Reason<select value={reason} onChange={event => setReason(event.target.value)}><option value="" disabled>Choose an approved reason</option>{policy.reasons[outcome].map(item => <option key={item.code} value={item.code}>{item.label[language]}</option>)}</select></label>}
      {error && <p role="alert">{error}</p>}
      <button disabled={!complete} onClick={() => setStage('confirm')}>Review decision before recording</button>
    </>}
    {stage === 'confirm' && input && ready && <div className="decision-confirm" role="group" aria-label="Confirm review decision">
      <h4>Confirm: {outcomeLabels[input.outcome]}</h4><p>Policy {policy.version}. Reason: {policy.reasons[input.outcome].find(item => item.code === reason)?.label[language]}.</p>
      <ul>{input.checks.map(check => <li key={check.id}>{policy.checks.find(item => item.id === check.id)?.label[language]}: {check.result.replace('_', ' ')}{check.evidenceKinds.length ? ` — ${check.evidenceKinds.map(kind => evidenceLabels[kind]).join(', ')}` : ''}</li>)}</ul>
      <p>This records an immutable decision. Approval does not turn availability on, switch modes or create earnings.</p>
      <button onClick={confirm} disabled={!complete}>Confirm and record decision</button><button className="secondary" onClick={() => setStage('form')}>Back to findings</button>
    </div>}
    {['sending', 'recovering'].includes(stage) && <p role="status">{stage === 'sending' ? 'Recording the decision…' : 'Checking the recorded decision…'}</p>}
    {stage === 'uncertain' && ticket && <div role="status"><p>{error}</p><button onClick={() => void request(ticket, true)}>Check decision receipt</button></div>}
    {stage === 'retry' && ticket && <div role="status"><p>No receipt was found for this request. You may explicitly retry the same unchanged decision. The original request may still finish; the same key prevents a duplicate.</p><button onClick={() => void request(ticket, false)}>Retry same decision</button></div>}
    {stage === 'receipt' && receipt && ticket && <div className="decision-receipt" role="status"><h4>Decision recorded: {receipt.outcome === 'approved' ? 'Approved' : receipt.outcome === 'rejected' ? 'Not approved' : 'More information needed'}</h4>
      <p>Recorded <time dateTime={receipt.recordedAt}>{new Date(receipt.recordedAt).toLocaleString()}</time>.</p><p className="opaque-reference">Decision reference: {receipt.decisionId}</p>
      {receipt.outcome === 'approved' && <p>{receipt.effects.entitlement === 'active' ? 'Listener access is active. Availability remains the applicant’s choice.' : receipt.effects.entitlement === 'pending' ? 'Listener access update is pending.' : 'Listener access is withheld by current account restrictions.'}</p>}
      <p>{receipt.effects.notification === 'available' ? 'The review update is available in the applicant’s account.' : receipt.effects.notification === 'pending' ? 'The in-app review update is pending.' : 'The in-app review update is unavailable for this account.'}</p>
      <button className="secondary" onClick={() => void request(ticket, true)}>Refresh decision status</button>
    </div>}
  </section>;
}
