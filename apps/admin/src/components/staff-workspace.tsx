'use client';

import {useCallback, useEffect, useRef, useState} from 'react';
import {sessionValue, statusValue, type Permission, type StaffSession} from '../lib/staff-contract';
import ListenerReviews from './listener-reviews';

type State = {kind: 'loading' | 'unavailable' | 'signed-out' | 'error' | 'signing-out'; message?: string} |
  {kind: 'authenticated'; session: StaffSession} | {kind: 'logout-uncertain'; csrf: string};
const labels: Record<Permission, string> = {
  'listener.review.read': 'View applications',
  'listener.review.evidence.read': 'Listen to review samples',
  'listener.review.decide': 'Record review decisions',
  'staff.access.manage': 'Administer staff access',
};
async function get(path: string, signal: AbortSignal) {
  const response = await fetch(`/api/staff/${path}`, {credentials: 'same-origin', cache: 'no-store', redirect: 'error', signal});
  return {response, body: await response.json() as unknown};
}
export default function StaffWorkspace() {
  const [state, setState] = useState<State>({kind: 'loading'});
  const [view, setView] = useState<'access' | 'reviews'>('access');
  const revision = useRef(0), pending = useRef<AbortController | null>(null);
  const logoutPending = useRef(false);
  const logoutUnresolved = useRef(false);
  const check = useCallback(async () => {
    if (logoutPending.current || logoutUnresolved.current) return;
    const current = ++revision.current;
    pending.current?.abort();
    const controller = new AbortController(); pending.current = controller;
    setState({kind: 'loading'});
    const deadline = setTimeout(() => controller.abort(), 10000);
    try {
      const status = await get('auth/status', controller.signal);
      if (current !== revision.current) return;
      if (!status.response.ok || !statusValue(status.body)) throw Error('Unavailable');
      if (!status.body.available) {setState({kind: 'unavailable'}); return;}
      const session = await get('session', controller.signal);
      if (current !== revision.current) return;
      if ([401, 403].includes(session.response.status)) {setState({kind: 'signed-out'}); return;}
      if (!session.response.ok || !sessionValue(session.body)) throw Error('Unavailable');
      if (Date.parse(session.body.expiresAt) <= Date.now()) {setState({kind: 'signed-out', message: 'Your staff session has expired.'}); return;}
      setState({kind: 'authenticated', session: session.body});
    } catch {if (current === revision.current) setState({kind: 'error'});}
    finally {clearTimeout(deadline);}
  }, []);
  useEffect(() => {
    void check();
    const visible = () => {
      if (document.visibilityState === 'visible') void check();
      else if (!logoutPending.current && !logoutUnresolved.current) {++revision.current; pending.current?.abort(); setState({kind: 'loading'});}
    };
    const restored = (event: PageTransitionEvent) => {if (event.persisted) void check();};
    window.addEventListener('pageshow', restored);
    document.addEventListener('visibilitychange', visible);
    return () => {++revision.current; pending.current?.abort(); window.removeEventListener('pageshow', restored); document.removeEventListener('visibilitychange', visible);};
  }, [check]);
  useEffect(() => {
    if (state.kind !== 'authenticated') return;
    const expiry = Date.parse(state.session.expiresAt);
    const tick = () => {
      if (Date.now() >= expiry) {++revision.current; pending.current?.abort(); setState({kind: 'signed-out', message: 'Your staff session has expired.'});}
    };
    const timer = setInterval(tick, 1000);
    return () => clearInterval(timer);
  }, [state]);
  const accessLost = useCallback(() => {
    ++revision.current; pending.current?.abort();
    setState({kind: 'signed-out', message: 'Staff access has changed. Reopen the staff workspace to confirm access.'});
  }, []);
  const logout = async (csrf: string) => {
    if (logoutPending.current) return;
    logoutPending.current = true;
    logoutUnresolved.current = true;
    const current = ++revision.current;
    pending.current?.abort();
    const controller = new AbortController(); pending.current = controller;
    setState({kind: 'signing-out'});
    const timer = setTimeout(() => controller.abort(), 10000);
    try {
      const result = await fetch('/api/staff/auth/logout', {method: 'POST', credentials: 'same-origin', redirect: 'error', cache: 'no-store',
        headers: {'Content-Type': 'application/json', 'X-CSRF-Token': csrf}, body: '{}', signal: controller.signal});
      const body = await result.json();
      if (current !== revision.current) return;
      if ((result.ok && body?.signedOut === true) || result.status === 401) {
        logoutUnresolved.current = false;
        setState({kind: 'signed-out', message: 'You are signed out of staff access.'});
      }
      else setState({kind: 'logout-uncertain', csrf});
    } catch {if (current === revision.current) setState({kind: 'logout-uncertain', csrf});}
    finally {clearTimeout(timer); logoutPending.current = false;}
  };
  const session = state.kind === 'authenticated' ? state.session : null;
  const reviews = session !== null && view === 'reviews' && session.permissions.includes('listener.review.read');
  return <div className="workspace">
    <aside className="workspace-rail" aria-label="Staff workspace">
      <a className="brand" href="/" aria-label="NightShift staff home"><span className="brand-mark" aria-hidden="true" />NightShift</a>
      <p className="rail-description">Staff workspace</p>
      <nav aria-label="Staff navigation"><button className="nav-button" aria-current={!reviews ? 'page' : undefined} onClick={() => setView('access')}>Access</button>
        {session?.permissions.includes('listener.review.read') ? <button className="nav-button" aria-current={reviews ? 'page' : undefined} onClick={() => setView('reviews')}>Listener reviews</button> : <span className="nav-unavailable">Listener reviews <small>Permission required</small></span>}</nav>
      <p className="rail-note">Private access for the people responsible for Listener reviews.</p>
    </aside>
    <main id="main" tabIndex={-1}>
      <header className="page-heading"><h1>{reviews ? 'Listener reviews' : 'Staff access'}</h1><p>{reviews ? 'Read submitted applications and their consented review material.' : 'Review access begins with an approved staff account.'}</p></header>
      {!reviews && <section className="access-panel" aria-labelledby="access-title" aria-live="polite" aria-busy={state.kind === 'loading' || state.kind === 'signing-out'}>
        {state.kind === 'loading' && <><span className="status-dot" aria-hidden="true" /><h2 id="access-title">Checking access</h2><p>Confirming the current staff session.</p></>}
        {state.kind === 'unavailable' && <><span className="status-label">Access not configured</span><h2 id="access-title">Staff sign-in is not available yet</h2><p>The staff sign-in service and access permissions must be configured before this workspace can be used.</p><button onClick={() => void check()}>Check access again</button></>}
        {state.kind === 'signed-out' && <><span className="status-label">Signed out</span><h2 id="access-title">An approved staff sign-in is required</h2><p>{state.message ?? 'There is no active staff session.'}</p><p>Reopen Staff workspace from your NightShift profile to sign in. If asked, verify your phone again.</p><button onClick={() => void check()}>Check access again</button></>}
        {state.kind === 'error' && <><span className="status-label">Connection unavailable</span><h2 id="access-title">Access could not be confirmed</h2><p>Private staff information is hidden. Check the connection and try again.</p><button onClick={() => void check()}>Check access again</button></>}
        {state.kind === 'signing-out' && <><h2 id="access-title">Signing out</h2><p>Private staff information has been cleared from this view.</p></>}
        {state.kind === 'logout-uncertain' && <><span className="status-label">Sign-out not confirmed</span><h2 id="access-title">Your session may still be active</h2><p>Private staff information is hidden. Retry sign-out to confirm that access is closed.</p><button onClick={() => void logout(state.csrf)}>Retry sign-out</button></>}
        {session && <><span className="status-label approved">Staff session active</span><h2 id="access-title">Your access is confirmed</h2><p className="session-reference">Staff reference <span>{session.staff.id}</span></p><p>Session ends <time dateTime={session.expiresAt}>{new Date(session.expiresAt).toLocaleString(undefined, {timeZoneName: 'short'})}</time>.</p><button className="secondary" onClick={() => void logout(session.csrfToken)}>Sign out of staff access</button></>}
      </section>}
      {session && !reviews && <section className="permissions" aria-labelledby="permissions-title"><h2 id="permissions-title">Granted permissions</h2>{session.permissions.length ? <ul>{session.permissions.map(permission => <li key={permission}>{labels[permission]}</li>)}</ul> : <p>No review permissions have been granted.</p>}<p className="muted">A staff session does not approve an application. Review decisions are not enabled.</p></section>}
      {session && reviews && <><div className="review-session"><p className="muted">Private staff session</p><button className="secondary" onClick={() => void logout(session.csrfToken)}>Sign out of staff access</button></div>
        <ListenerReviews key={`${session.staff.id}:${session.csrfToken}`} session={session} onAccessLost={accessLost} /></>}
      <footer><strong>Private by design</strong><p>Access is limited to your granted staff permissions. Account phone numbers and identity records are excluded from this workspace.</p></footer>
    </main>
  </div>;
}
