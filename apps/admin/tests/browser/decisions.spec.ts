import {test, expect, type APIRequestContext, type BrowserContext, type Page} from '@playwright/test';
import type {Outcome} from '../../src/lib/decision-contract';
async function mode(request: APIRequestContext, value: string) {await request.post('http://127.0.0.1:4774/__fixture/control', {data: {mode: value}});}
async function open(page: Page, context: BrowserContext, request: APIRequestContext, value = 'decision-active') {
  await request.post('http://127.0.0.1:4774/__fixture/reset-decisions'); await mode(request, value);
  await context.addCookies([{name: '__Host-nightshift_staff', value: 'a'.repeat(64), domain: '127.0.0.1', path: '/', secure: true, httpOnly: true, sameSite: 'Strict'}]);
  await page.goto('/'); await page.getByRole('button', {name: 'Listener reviews', exact: true}).click();
  await page.getByRole('button', {name: /Applicant Moon/}).click();
}
async function findings(page: Page, outcome: Outcome = 'approved') {
  await page.getByLabel('Finding: Synthetic application check').selectOption(outcome === 'approved' ? 'pass' : outcome === 'rejected' ? 'fail' : 'not_checked');
  if (outcome !== 'needs_information') await page.getByRole('checkbox', {name: 'Application details', exact: true}).check();
  await page.getByRole('combobox', {name: 'Outcome', exact: true}).selectOption(outcome);
  await page.getByRole('combobox', {name: 'Reason', exact: true}).selectOption(outcome === 'approved' ? 'fixture_approved' : outcome === 'rejected' ? 'fixture_rejected' : 'fixture_missing');
  await page.getByRole('button', {name: 'Review decision before recording'}).click();
}
const counts = async (request: APIRequestContext) => (await request.get('http://127.0.0.1:4774/__fixture/decision-counts')).json();
test('no approved policy or missing decision permission leaves real decisions disabled', async ({page, request, context}) => {
  await open(page, context, request, 'decision-off');
  await expect(page.getByText(/Review decisions are unavailable until an approved policy is configured/)).toBeVisible();
  await expect(page.getByRole('combobox', {name: 'Outcome', exact: true})).toHaveCount(0);
  expect((await counts(request)).decisionPosts).toBe(0);
  await open(page, context, request, 'decision-no-permission');
  await expect(page.getByText('Your staff account does not have permission to record review decisions.')).toBeVisible();
  await expect(page.getByRole('button', {name: 'Confirm and record decision'})).toHaveCount(0);
});
for (const outcome of ['approved', 'rejected', 'needs_information'] as Outcome[]) test(`synthetic ${outcome} requires explicit findings and confirmation`, async ({page, request, context}) => {
  await open(page, context, request);
  await expect(page.getByLabel('Finding: Synthetic application check')).toHaveValue('');
  await expect(page.getByRole('button', {name: 'Review decision before recording'})).toBeDisabled();
  if (outcome === 'approved') {
    await page.getByRole('button', {name: 'Show audio controls'}).click();
    await page.locator('audio').evaluate(async player => {Reflect.set(window, '__decisionOldAudio', player); await (player as HTMLAudioElement).play();});
  }
  await findings(page, outcome);
  expect((await counts(request)).decisionPosts).toBe(0);
  await page.getByRole('button', {name: 'Confirm and record decision'}).click();
  await expect(page.getByRole('heading', {name: `Decision recorded: ${outcome === 'approved' ? 'Approved' : outcome === 'rejected' ? 'Not approved' : 'More information needed'}`})).toBeVisible();
  expect((await counts(request)).decisionPosts).toBe(1);
  await expect(page.getByRole('region', {name: 'Application introduction'})).toHaveCount(0);
  await expect(page.getByRole('button', {name: 'Show audio controls'})).toHaveCount(0);
  if (outcome === 'approved') {
    expect(await page.evaluate(() => {const player = Reflect.get(window, '__decisionOldAudio') as HTMLAudioElement;
      player.dispatchEvent(new Event('error')); return player.paused && player.getAttribute('src') === null;})).toBe(true);
    await expect(page.getByRole('heading', {name: 'Decision recorded: Approved'})).toBeVisible();
  }
  if (outcome === 'approved') await expect(page.getByText('Listener access update is pending.')).toBeVisible();
  await expect(page.getByText('The in-app review update is pending.')).toBeVisible();
  expect(await page.evaluate(() => ({local: localStorage.length, session: sessionStorage.length}))).toEqual({local: 0, session: 0});
});
test('lost success recovers its receipt without a second mutation', async ({page, request, context}) => {
  await open(page, context, request, 'decision-lost'); await findings(page);
  await page.getByRole('button', {name: 'Confirm and record decision'}).click();
  await expect(page.getByText('The result is not confirmed. Check the decision receipt before retrying.')).toBeVisible();
  await expect(page.getByRole('combobox', {name: 'Outcome', exact: true})).toHaveCount(0);
  await page.waitForTimeout(150); expect((await counts(request)).decisionPosts).toBe(1);
  await page.getByRole('button', {name: 'Check decision receipt'}).click();
  await expect(page.getByRole('heading', {name: 'Decision recorded: Approved'})).toBeVisible();
  const result = await counts(request); expect(result.decisionPosts).toBe(1); expect(result.receiptReads).toBe(1);
});
test('absent receipt permits only explicit retry of the identical frozen command', async ({page, request, context}) => {
  await open(page, context, request, 'decision-failed'); await findings(page);
  await page.getByRole('button', {name: 'Confirm and record decision'}).click();
  await page.getByRole('button', {name: 'Check decision receipt'}).click();
  await expect(page.getByRole('button', {name: 'Retry same decision'})).toBeVisible();
  expect((await counts(request)).decisionPosts).toBe(1);
  await page.getByRole('button', {name: 'Retry same decision'}).click();
  await expect(page.getByRole('heading', {name: 'Decision recorded: Approved'})).toBeVisible();
  const result = await counts(request); expect(result.decisionPosts).toBe(2); expect(result.decisionKeys[0]).toBe(result.decisionKeys[1]); expect(result.decisionBodies[0]).toEqual(result.decisionBodies[1]);
});
for (const conflict of ['decision-stale', 'decision-policy-changed']) test(`${conflict} requires rereading and clears stale findings`, async ({page, request, context}) => {
  await open(page, context, request, conflict); await findings(page);
  await page.getByRole('button', {name: 'Confirm and record decision'}).click();
  await expect(page.getByText('The application or review policy has changed. Refresh and read the current material before recording new findings.')).toBeVisible();
  await mode(request, 'decision-active'); await page.getByRole('button', {name: 'Refresh application'}).click();
  await expect(page.getByLabel('Finding: Synthetic application check')).toHaveValue('');
  await expect(page.getByRole('button', {name: 'Review decision before recording'})).toBeDisabled();
});
test('logout cancels UI publication of a late decision and changed grants clear confirmation', async ({page, request, context}) => {
  await open(page, context, request, 'decision-held'); await findings(page);
  const submitted = page.waitForRequest('**/decisions'); await page.getByRole('button', {name: 'Confirm and record decision'}).click(); await submitted;
  await page.getByRole('button', {name: 'Sign out of staff access'}).click();
  await expect(page.getByText('You are signed out of staff access.')).toBeVisible(); await page.waitForTimeout(750);
  await expect(page.getByRole('heading', {name: 'Decision recorded: Approved'})).toHaveCount(0);
  await open(page, context, request); await findings(page);
  await mode(request, 'decision-no-permission');
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', {persisted: true})));
  await page.getByRole('button', {name: /Applicant Moon/}).click();
  await expect(page.getByText('Your staff account does not have permission to record review decisions.')).toBeVisible();
  await expect(page.getByRole('button', {name: 'Confirm and record decision'})).toHaveCount(0);
});
test('Tamil checklist and confirmation fit360px at200% text with keyboard controls', async ({page, request, context}) => {
  await page.setViewportSize({width: 360, height: 800}); await open(page, context, request);
  await page.getByLabel('Checklist language').selectOption('ta');
  await page.evaluate(() => {const style = document.createElement('style'); style.nonce = document.querySelector<HTMLScriptElement>('script[nonce]')!.nonce;
    style.textContent = ':root {font-size: 32px} body, .brand {font-family: Arial, sans-serif}'; document.head.append(style);});
  await expect(page.getByText('செயற்கை விண்ணப்பத்தின் சோதனை சரிபார்ப்பு', {exact: true})).toBeVisible();
  await findings(page); const confirm = page.getByRole('button', {name: 'Confirm and record decision'}); await confirm.focus(); await expect(confirm).toBeFocused();
  const overflow = await page.locator('.decision-panel *').evaluateAll(elements => elements.filter(element => element.getBoundingClientRect().right > window.innerWidth + 1).map(element => ({tag: element.tagName, text: element.textContent?.slice(0, 80)})));
  expect(overflow).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  expect(await page.locator('.decision-panel button, .decision-panel select, .decision-check').evaluateAll(elements => elements.every(element => element.getBoundingClientRect().right <= window.innerWidth + 1))).toBe(true);
  await page.screenshot({path: '../../artifacts/staff-decision-tamil-200-synthetic.png', fullPage: true});
});
