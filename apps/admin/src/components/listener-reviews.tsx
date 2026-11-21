'use client';

import {useCallback, useEffect, useRef, useState} from 'react';
import {reviewDetailValue, reviewPageValue, type ReviewApplication, type ReviewLanguage, type ReviewSummary, type ReviewTopic} from '../lib/review-contract';
import {object, type StaffSession} from '../lib/staff-contract';
import ReviewDecision from './review-decision';

const languageLabels: Record<ReviewLanguage, string> = {ta: 'Tamil', en: 'English'};
const topicLabels: Record<ReviewTopic, string> = {everyday: 'Everyday life', work: 'Work', study: 'Study', hobbies: 'Hobbies', 'language-practice': 'Language practice'};
type State = {kind: 'queue'; items: ReviewSummary[]; nextCursor: string | null; loading: boolean; error: string | null; expired: boolean} |
  {kind: 'detail-loading'; id: string} | {kind: 'detail'; application: ReviewApplication; decisionsEnabled: boolean; recorded?: boolean} | {kind: 'detail-error'; id: string; message: string};
const emptyQueue = (): State => ({kind: 'queue', items: [], nextCursor: null, loading: true, error: null, expired: false});
function errorCode(body: unknown): string {
  return object(body) && object(body.error) && typeof body.error.code === 'string' ? body.error.code : '';
}
function dateLabel(value: string) {return new Date(value).toLocaleString(undefined, {dateStyle: 'medium', timeStyle: 'short'});}
function PrivateSample({application, unavailable}: {application: ReviewApplication; unavailable: () => void}) {
  const [shown, setShown] = useState(false);
  const audio = useRef<HTMLAudioElement | null>(null);
  useEffect(() => {
    const player = audio.current;
    if (player) player.disableRemotePlayback = true;
    return () => {if (player) {player.pause(); player.removeAttribute('src'); player.load();}};
  }, [shown]);
  return <div className="review-sample">
    <h3>Private voice sample</h3>
    <p>This sample is review material. It does not verify age, gender or identity.</p>
    {!shown ? <button className="secondary" onClick={() => setShown(true)}>Show audio controls</button> :
      <audio ref={audio} controls preload="none" controlsList="nodownload noremoteplayback"
        aria-label={`Private review sample for ${application.alias}`} onError={unavailable}
        src={`/api/staff/listener-applications/${application.id}/voice-sample?version=${application.materialVersion}`} />}
    <p className="muted">Play only in a private setting. Playback starts when you press Play.</p>
  </div>;
}
export default function ListenerReviews({session, onAccessLost}: {session: StaffSession; onAccessLost: () => void}) {
  const [state, setState] = useState<State>(emptyQueue);
  const [language, setLanguage] = useState<ReviewLanguage | ''>('');
  const canReadEvidence = session.permissions.includes('listener.review.evidence.read');
  const revision = useRef(0), pending = useRef<AbortController | null>(null);
  const heading = useRef<HTMLHeadingElement | null>(null);
  const read = useCallback(async (path: string, accept: (response: Response, body: unknown) => void, reject: () => void) => {
    const current = ++revision.current;
    pending.current?.abort();
    const controller = new AbortController(); pending.current = controller;
    const timer = setTimeout(() => controller.abort(), 10000);
    try {
      const response = await fetch(path, {credentials: 'same-origin', cache: 'no-store', redirect: 'error', signal: controller.signal});
      const body: unknown = await response.json();
      if (current !== revision.current) return;
      if ([401, 403].includes(response.status) || Date.parse(session.expiresAt) <= Date.now()) {onAccessLost(); return;}
      accept(response, body);
    } catch {if (current === revision.current) reject();}
    finally {clearTimeout(timer);}
  }, [session.expiresAt, onAccessLost]);
  const firstPage = useCallback(() => {
    setState(emptyQueue());
    const query = language ? `?language=${language}` : '';
    void read(`/api/staff/listener-applications${query}`, (response, body) => {
      if (!response.ok || !reviewPageValue(body)) throw Error('Invalid queue');
      setState({kind: 'queue', items: body.items, nextCursor: body.nextCursor, loading: false, error: null, expired: false});
    }, () => setState({kind: 'queue', items: [], nextCursor: null, loading: false, error: 'Applications could not be loaded. Try refreshing the queue.', expired: false}));
  }, [language, read]);
  useEffect(() => {firstPage(); return () => {++revision.current; pending.current?.abort();};}, [firstPage]);
  const more = () => {
    if (state.kind !== 'queue' || state.loading || !state.nextCursor) return;
    const previous = state;
    setState({...state, loading: true, error: null});
    const query = new URLSearchParams({cursor: state.nextCursor});
    if (language) query.set('language', language);
    void read(`/api/staff/listener-applications?${query}`, (response, body) => {
      if (response.status === 410 || errorCode(body) === 'INVALID_REVIEW_CURSOR') {
        setState({...previous, nextCursor: null, loading: false, expired: true, error: 'This queue has expired. Refresh it to continue.'}); return;
      }
      if (!response.ok || !reviewPageValue(body) || body.items.some(item => previous.items.some(old => old.id === item.id)) || body.nextCursor === previous.nextCursor) throw Error('Invalid page');
      setState({kind: 'queue', items: [...previous.items, ...body.items], nextCursor: body.nextCursor, loading: false, error: null, expired: false});
    }, () => setState({...previous, loading: false, error: 'The next page could not be loaded. Try again or refresh the queue.'}));
  };
  const detail = (id: string) => {
    if (!canReadEvidence) return;
    setState({kind: 'detail-loading', id});
    void read(`/api/staff/listener-applications/${id}`, (response, body) => {
      if (response.status === 404 || response.status === 409) {setState({kind: 'detail-error', id, message: 'This application is no longer available for review. Return to the queue for current submissions.'}); return;}
      if (!response.ok || !reviewDetailValue(body) || body.application.id !== id) throw Error('Invalid detail');
      setState({kind: 'detail', application: body.application, decisionsEnabled: body.decisionsEnabled});
    }, () => setState({kind: 'detail-error', id, message: 'Application details could not be loaded. Try again.'}));
  };
  useEffect(() => {if (state.kind === 'detail' || state.kind === 'detail-error') heading.current?.focus();}, [state.kind]);
  const application = state.kind === 'detail' ? state.application : null;
  const materialGeneration = revision.current;
  return <section className="reviews" aria-label="Listener applications">
    <p className="review-boundary">Submitted applications only. Decisions require an approved policy and separate review permissions.</p>
    {state.kind === 'queue' ? <>
      <div className="review-toolbar"><label>Requested language<select value={language} onChange={event => setLanguage(event.target.value as ReviewLanguage | '')}>
        <option value="">All languages</option><option value="ta">Tamil</option><option value="en">English</option>
      </select></label><button className="secondary" onClick={firstPage} disabled={state.loading}>Refresh queue</button></div>
      <div role="status">{state.loading && <p>Loading applications…</p>}{state.error && <p className="review-error">{state.error}</p>}</div>
      {!canReadEvidence && <p className="muted">You can view queue summaries. Permission to read review evidence is required to open application details or listen to samples.</p>}
      {!state.loading && !state.error && !state.items.length && (state.nextCursor ?
        <p className="review-empty">No applications on this page. Continue to check the remaining submissions.</p> :
        <div className="review-empty"><h2>No submitted applications</h2><p>There are no applications available to you for this language selection.</p></div>)}
      <ul className="review-list" aria-label="Submitted applications" aria-busy={state.loading}>
        {state.items.map(item => <li key={item.id}><button className="review-row" onClick={() => detail(item.id)} disabled={!canReadEvidence || state.expired || state.loading}>
          <span className="review-row-title">{item.alias}</span><span>{item.languages.map(value => languageLabels[value]).join(', ')}</span>
          <time dateTime={item.submittedAt}>Submitted {dateLabel(item.submittedAt)}</time><span className="muted">{item.voiceSampleAvailable ? 'Voice sample available' : 'No current voice sample'}</span>
        </button></li>)}
      </ul>
      {state.nextCursor && <button onClick={more} disabled={state.loading}>Load more applications</button>}
    </> : <>
      <button className="secondary review-back" onClick={firstPage}>Back to applications</button>
      {state.kind === 'detail-loading' && <p role="status">Loading application…</p>}
      {state.kind === 'detail-error' && <div className="review-empty"><h2 ref={heading} tabIndex={-1}>Review material unavailable</h2><p role="status">{state.message}</p><button className="secondary" onClick={() => detail(state.id)}>Refresh application</button></div>}
      {application && <article className="review-detail">
        <header><span className="status-label">{state.kind === 'detail' && state.recorded ? 'Review recorded' : 'Submitted'}</span><h2 ref={heading} tabIndex={-1}>{application.alias}</h2><p>Submitted <time dateTime={application.submittedAt}>{dateLabel(application.submittedAt)}</time></p></header>
        {!(state.kind === 'detail' && state.recorded) && <>
        <dl className="review-facts"><div><dt>Application reference</dt><dd className="opaque-reference">{application.id}</dd></div><div><dt>Requested languages</dt><dd>{application.languages.map(value => languageLabels[value]).join(', ')}</dd></div>
          <div><dt>Age declaration</dt><dd>Self-declared adult. Age and identity have not been verified by this review.</dd></div></dl>
        <section aria-label="Application introduction"><h3>About the applicant</h3><p className="review-bio">{application.bio || 'No introduction provided.'}</p><h3>Conversation topics</h3><p>{application.topics.map(topic => topicLabels[topic]).join(', ') || 'No topics provided.'}</p></section>
        {application.voiceSample && session.permissions.includes('listener.review.evidence.read') ? <PrivateSample key={`${application.id}:${application.materialVersion}`} application={application}
          unavailable={() => setState(current => revision.current === materialGeneration && current.kind === 'detail' && !current.recorded && current.application.id === application.id && current.application.materialVersion === application.materialVersion
            ? {kind: 'detail-error', id: application.id, message: 'The sample could not be loaded or access has changed. Refresh the application before trying again.'} : current)} /> :
          <section className="review-sample"><h3>Private voice sample</h3><p>{application.voiceSample ? 'Your staff account does not have permission to listen to review samples.' : 'No current voice sample is available for this application.'}</p></section>}
        <button className="secondary" onClick={() => detail(application.id)}>Refresh application</button>
        </>}
        <ReviewDecision key={`${application.id}:${materialGeneration}`} application={application} session={session} enabled={state.kind === 'detail' && state.decisionsEnabled} onAccessLost={onAccessLost}
          onRecorded={() => setState(current => current.kind === 'detail' && revision.current === materialGeneration ? {...current, recorded: true} : current)}
          onStale={() => {++revision.current; setState({kind: 'detail-error', id: application.id, message: 'The application or review policy has changed. Refresh and read the current material before recording new findings.'});}} />
      </article>}
    </>}
  </section>;
}
