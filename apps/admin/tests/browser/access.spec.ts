import {test, expect, type APIRequestContext, type BrowserContext} from '@playwright/test';
async function mode(request: APIRequestContext, value: string) {await request.post('http://127.0.0.1:4774/__fixture/control', {data: {mode: value}});}
async function grant(context: BrowserContext) {
  await context.addCookies([{name: '__Host-nightshift_staff', value: 'a'.repeat(64), domain: '127.0.0.1', path: '/', secure: true, httpOnly: true, sameSite: 'Strict'}]);
}
test('unconfigured access shows no sign-in shortcut or private request', async ({page, request}) => {
  await mode(request, 'unavailable');
  await page.goto('/');
  await expect(page.getByRole('heading', {name: 'Staff sign-in is not available yet'})).toBeVisible();
  await page.getByRole('button', {name: 'Check access again'}).click();
  await expect(page.getByText('Access not configured')).toBeVisible();
  expect(await (await request.get('http://127.0.0.1:4774/__fixture/counts')).json()).toEqual({sessionReads: 0, mutations: 0});
  expect(await page.evaluate(() => ({local: localStorage.length, session: sessionStorage.length}))).toEqual({local: 0, session: 0});
  await page.screenshot({path: '../../artifacts/staff-admin-unconfigured.png', fullPage: true});
});
test('synthetic session permissions are read-only and sign-out clears private view', async ({page, request, context}) => {
  await mode(request, 'active'); await grant(context); await page.goto('/');
  await expect(page.getByText('Your access is confirmed')).toBeVisible();
  await expect(page.getByText('View applications', {exact: true})).toBeVisible();
  await expect(page.getByText('Record review decisions', {exact: true})).toHaveCount(0);
  await page.screenshot({path: '../../artifacts/staff-admin-synthetic-session.png', fullPage: true});
  await page.getByRole('button', {name: 'Sign out of staff access'}).click();
  await expect(page.getByText('You are signed out of staff access.')).toBeVisible();
  await expect(page.getByText('c874c564-4701-445c-a090-cceab31ba9c9')).toHaveCount(0);
  expect((await context.cookies()).find(cookie => cookie.name === '__Host-nightshift_staff')).toBeUndefined();
});
test('uncertain sign-out hides staff details without claiming revocation or retrying', async ({page, request, context}) => {
  await mode(request, 'logout-uncertain'); await grant(context); await page.goto('/');
  await page.getByRole('button', {name: 'Sign out of staff access'}).click();
  await expect(page.getByText('Your session may still be active')).toBeVisible();
  await expect(page.getByText('c874c564-4701-445c-a090-cceab31ba9c9')).toHaveCount(0);
  await page.evaluate(() => {
    window.dispatchEvent(new PageTransitionEvent('pageshow', {persisted: true}));
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.waitForTimeout(200);
  await expect(page.getByText('Your session may still be active')).toBeVisible();
  expect((await (await request.get('http://127.0.0.1:4774/__fixture/counts')).json()).sessionReads).toBe(1);
  expect((await (await request.get('http://127.0.0.1:4774/__fixture/counts')).json()).mutations).toBe(1);
  await mode(request, 'active'); await page.getByRole('button', {name: 'Retry sign-out'}).click();
  await expect(page.getByText('You are signed out of staff access.')).toBeVisible();
});
test('expiry and restored-page revocation remove private session state', async ({page, request, context}) => {
  await mode(request, 'expiring'); await grant(context); await page.goto('/');
  await expect(page.getByText('Your access is confirmed')).toBeVisible();
  await expect(page.getByText('Your staff session has expired.')).toBeVisible();
  await mode(request, 'active'); await page.getByRole('button', {name: 'Check access again'}).click();
  await expect(page.getByText('Your access is confirmed')).toBeVisible();
  await mode(request, 'revoked');
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', {persisted: true})));
  await expect(page.getByText('There is no active staff session.')).toBeVisible();
  await expect(page.getByText('c874c564-4701-445c-a090-cceab31ba9c9')).toHaveCount(0);
});
test('expired session response cannot replace a newer denied result', async ({page, request, context}) => {
  await mode(request, 'held-session'); await grant(context); await page.goto('/');
  await page.waitForRequest('**/api/staff/session');
  await mode(request, 'revoked');
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', {persisted: true})));
  await expect(page.getByText('There is no active staff session.')).toBeVisible();
  await page.waitForTimeout(350);
  await expect(page.getByText('Your access is confirmed')).toHaveCount(0);
});
test('narrow screen and 200% text keep access controls reachable by keyboard', async ({page, request}) => {
  await mode(request, 'unavailable'); await page.setViewportSize({width: 360, height: 800}); await page.goto('/');
  await page.addStyleTag({content: 'html {font-size: 200%}'});
  const action = page.getByRole('button', {name: 'Check access again'});
  await action.focus(); await expect(action).toBeFocused();
  await action.press('Enter'); await expect(page.getByText('Access not configured')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
});
