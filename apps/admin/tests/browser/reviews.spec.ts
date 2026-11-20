import {test, expect, type APIRequestContext, type BrowserContext, type Page} from '@playwright/test';
import {applicationId, materialVersion} from '../review-fixtures';
async function mode(request: APIRequestContext, value: string) {await request.post('http://127.0.0.1:4774/__fixture/control', {data: {mode: value}});}
async function open(page: Page, context: BrowserContext, request: APIRequestContext, value = 'review-active') {
  await mode(request, value);
  await context.addCookies([{name: '__Host-nightshift_staff', value: 'a'.repeat(64), domain: '127.0.0.1', path: '/', secure: true, httpOnly: true, sameSite: 'Strict'}]);
  await page.goto('/'); await page.getByRole('button', {name: 'Listener reviews', exact: true}).click();
}
const counts = async (request: APIRequestContext) => (await request.get('http://127.0.0.1:4774/__fixture/review-counts')).json();
async function showSample(page: Page) {
  await page.getByRole('button', {name: /Applicant Moon/}).click();
  await page.getByRole('button', {name: 'Show audio controls'}).click();
  await page.locator('audio').evaluate(async player => {Reflect.set(window, '__oldReviewPlayer', player); await (player as HTMLAudioElement).play();});
}
async function expectCleared(page: Page) {
  await expect(page.locator('audio')).toHaveCount(0);
  expect(await page.evaluate(() => {const old = Reflect.get(window, '__oldReviewPlayer') as HTMLAudioElement; return old.paused && old.getAttribute('src') === null;})).toBe(true);
}
test('submitted queue filters and pages without duplicates or review mutations', async ({page, request, context}) => {
  await open(page, context, request);
  await expect(page.getByRole('button', {name: /Applicant Moon/})).toBeVisible();
  await page.getByRole('button', {name: 'Load more applications'}).click();
  await expect(page.getByRole('button', {name: /Applicant Wave/})).toBeVisible();
  await expect(page.getByRole('list', {name: 'Submitted applications'}).getByRole('listitem')).toHaveCount(3);
  await page.getByLabel('Requested language').selectOption('ta');
  await expect(page.getByRole('button', {name: /Applicant Leaf/})).toBeVisible();
  await expect(page.getByRole('button', {name: /Applicant Moon/})).toHaveCount(0);
  expect((await counts(request)).sampleReads).toBe(0);
  expect((await (await request.get('http://127.0.0.1:4774/__fixture/counts')).json()).mutations).toBe(0);
});
test('queue-only staff cannot open private detail or sample', async ({page, request, context}) => {
  await open(page, context, request, 'review-no-evidence');
  await expect(page.getByRole('button', {name: /Applicant Moon/})).toBeDisabled();
  await expect(page.getByText(/Permission to read review evidence is required/)).toBeVisible();
  expect(await counts(request)).toEqual({queueReads: 1, detailReads: 0, sampleReads: 0});
  const direct = await context.request.get(`/api/staff/listener-applications/${applicationId}`);
  expect(direct.status()).toBe(403);
  const sample = await context.request.get(`/api/staff/listener-applications/${applicationId}/voice-sample?version=${materialVersion}`);
  expect(sample.status()).toBe(403);
  await mode(request, 'review-no-read');
  await page.reload(); await expect(page.getByText('Your access is confirmed')).toBeVisible();
  await expect(page.getByRole('button', {name: 'Listener reviews', exact: true})).toHaveCount(0);
  expect(await counts(request)).toEqual({queueReads: 0, detailReads: 0, sampleReads: 0});
});
test('an empty page with a continuation never claims the review queue is empty', async ({page, request, context}) => {
  await open(page, context, request, 'review-short-page');
  await expect(page.getByText('No applications on this page. Continue to check the remaining submissions.')).toBeVisible();
  await expect(page.getByRole('heading', {name: 'No submitted applications'})).toHaveCount(0);
  await page.getByRole('button', {name: 'Load more applications'}).click();
  await expect(page.getByRole('button', {name: /Applicant Wave/})).toBeVisible();
  await expect(page.getByRole('list', {name: 'Submitted applications'}).getByRole('listitem')).toHaveCount(1);
});
test('private sample is explicit, same-origin, unverified evidence and clears on tab exit', async ({page, request, context}) => {
  await open(page, context, request);
  await page.getByRole('button', {name: /Applicant Moon/}).click();
  await expect(page.getByText('Self-declared adult. Age and identity have not been verified by this review.')).toBeVisible();
  await expect(page.getByRole('button', {name: /approve|reject|needs information/i})).toHaveCount(0);
  expect((await counts(request)).sampleReads).toBe(0);
  await page.getByRole('button', {name: 'Show audio controls'}).click();
  await expect(page.locator('audio')).toHaveAttribute('preload', 'none');
  await page.waitForTimeout(150); expect((await counts(request)).sampleReads).toBe(0);
  await page.locator('audio').evaluate(async player => {Reflect.set(window, '__oldReviewPlayer', player); await (player as HTMLAudioElement).play();});
  await expect.poll(async () => (await counts(request)).sampleReads).toBeGreaterThan(0);
  await page.getByRole('button', {name: 'Access', exact: true}).click();
  await expectCleared(page);
  expect(await page.evaluate(() => ({local: localStorage.length, session: sessionStorage.length}))).toEqual({local: 0, session: 0});
});
test('old detail response cannot restore a previous selection', async ({page, request, context}) => {
  await open(page, context, request, 'review-held-detail');
  await page.getByRole('button', {name: /Applicant Moon/}).click();
  await expect(page.getByText('Loading application…')).toBeVisible();
  await page.getByRole('button', {name: 'Back to applications'}).click();
  await page.getByRole('button', {name: /Applicant Leaf/}).click();
  await expect(page.getByRole('heading', {name: 'Applicant Leaf'})).toBeVisible();
  await page.waitForTimeout(650);
  await expect(page.getByRole('heading', {name: 'Applicant Moon'})).toHaveCount(0);
});
test('loading failures, empty queues and expired pagination remain distinct', async ({page, request, context}) => {
  await open(page, context, request, 'review-error');
  await expect(page.getByText('Applications could not be loaded. Try refreshing the queue.')).toBeVisible();
  await expect(page.getByText('No submitted applications', {exact: true})).toHaveCount(0);
  await mode(request, 'review-empty'); await page.getByRole('button', {name: 'Refresh queue'}).click();
  await expect(page.getByRole('heading', {name: 'No submitted applications'})).toBeVisible();
  await mode(request, 'review-expired'); await page.getByRole('button', {name: 'Refresh queue'}).click();
  await page.getByRole('button', {name: 'Load more applications'}).click();
  await expect(page.getByText('This queue has expired. Refresh it to continue.')).toBeVisible();
  await expect(page.getByRole('button', {name: /Applicant Moon/})).toBeDisabled();
});
test('changed material removes stale detail and never automatically retries audio', async ({page, request, context}) => {
  await open(page, context, request, 'review-changed');
  await page.getByRole('button', {name: /Applicant Moon/}).click();
  await page.getByRole('button', {name: 'Show audio controls'}).click();
  await page.locator('audio').evaluate(player => (player as HTMLAudioElement).load());
  await expect(page.getByRole('heading', {name: 'Review material unavailable'})).toBeVisible();
  await expect(page.locator('audio')).toHaveCount(0);
  const reads = (await counts(request)).sampleReads;
  await page.waitForTimeout(200); expect((await counts(request)).sampleReads).toBe(reads);
});
test('known evidence permission loss clears playback while preserving queue access', async ({page, request, context}) => {
  await open(page, context, request); await showSample(page);
  await mode(request, 'review-no-evidence');
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', {persisted: true})));
  await expectCleared(page);
  await expect(page.getByRole('button', {name: /Applicant Moon/})).toBeDisabled();
  await expect(page.getByText(/Permission to read review evidence is required/)).toBeVisible();
  expect((await counts(request)).sampleReads).toBe(0);
});
test('logout and session expiry both stop and remove private playback', async ({page, request, context}) => {
  await open(page, context, request); await showSample(page);
  await page.getByRole('button', {name: 'Sign out of staff access'}).click();
  await expect(page.getByText('You are signed out of staff access.')).toBeVisible(); await expectCleared(page);
  await open(page, context, request); await showSample(page);
  await page.clock.install(); await page.clock.fastForward(610000);
  await expect(page.getByText('Your staff session has expired.')).toBeVisible(); await expectCleared(page);
});
test('background hides audio and late old-player errors cannot replace refreshed same-version detail', async ({page, request, context}) => {
  await open(page, context, request); await showSample(page);
  await page.getByRole('button', {name: 'Refresh application'}).click();
  await expect(page.getByRole('heading', {name: 'Applicant Moon'})).toBeVisible();
  await page.evaluate(() => (Reflect.get(window, '__oldReviewPlayer') as HTMLAudioElement).dispatchEvent(new Event('error')));
  await expect(page.getByRole('heading', {name: 'Applicant Moon'})).toBeVisible();
  await page.getByRole('button', {name: 'Show audio controls'}).click();
  await page.locator('audio').evaluate(async player => {Reflect.set(window, '__oldReviewPlayer', player); await (player as HTMLAudioElement).play();});
  await page.evaluate(() => {Object.defineProperty(document, 'visibilityState', {configurable: true, get: () => 'hidden'}); document.dispatchEvent(new Event('visibilitychange'));});
  await expectCleared(page);
  await expect(page.getByRole('heading', {name: 'Applicant Moon'})).toHaveCount(0);
});
test('Tamil detail at 360px and 200% text fits without clipping and retains keyboard controls', async ({page, request, context}) => {
  await page.setViewportSize({width: 360, height: 800}); await open(page, context, request);
  await page.evaluate(() => {
    const style = document.createElement('style'); style.nonce = document.querySelector<HTMLScriptElement>('script[nonce]')!.nonce;
    style.textContent = ':root {font-size: 32px} body, .brand {font-family: Arial, sans-serif}'; document.head.append(style);
  });
  const skip = page.getByRole('link', {name: 'Skip to workspace'});
  expect(await skip.evaluate(element => element.getBoundingClientRect().bottom <= 0)).toBe(true);
  await skip.focus(); expect(await skip.evaluate(element => element.getBoundingClientRect().top >= 0)).toBe(true);
  await page.getByLabel('Requested language').focus();
  expect(await skip.evaluate(element => element.getBoundingClientRect().bottom <= 0)).toBe(true);
  await page.screenshot({path: '../../artifacts/staff-review-queue-200-synthetic.png', fullPage: true});
  await page.getByRole('button', {name: /Applicant Leaf/}).click();
  await expect(page.getByText(/அன்றாட உரையாடல்களையும்/)).toBeVisible();
  await page.getByRole('button', {name: 'Show audio controls'}).click();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  const overflowing = await page.locator('main button, main select, main audio, nav button').evaluateAll(elements => elements.filter(element => element.getBoundingClientRect().right > window.innerWidth + 1).map(element => element.tagName));
  expect(overflowing).toEqual([]);
  await page.getByRole('button', {name: 'Refresh application'}).focus(); await expect(page.getByRole('button', {name: 'Refresh application'})).toBeFocused();
  expect(await skip.evaluate(element => getComputedStyle(element).opacity)).toBe('0');
  await page.screenshot({path: '../../artifacts/staff-review-detail-200-synthetic.png', fullPage: true});
});
