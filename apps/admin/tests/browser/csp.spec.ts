import {test, expect} from '@playwright/test';

test('production CSP hydrates with unique server nonces and blocks credential-bearing cross-port resources', async ({page, request}) => {
  await request.post('http://127.0.0.1:4774/__fixture/control', {data: {mode: 'unavailable'}});
  const violations: string[] = [];
  page.on('console', message => {if (/Content Security Policy|Refused to/.test(message.text())) violations.push(message.text());});
  await page.setExtraHTTPHeaders({'x-nonce': 'attacker-chosen', 'Content-Security-Policy': "default-src * 'unsafe-inline'"});
  const first = await page.goto('/');
  await expect(page.getByText('Access not configured')).toBeVisible();
  await page.getByRole('button', {name: 'Check access again'}).click();
  await expect(page.getByText('Access not configured')).toBeVisible();
  expect(violations).toEqual([]);
  const policy = first!.headers()['content-security-policy'];
  const nonce = /'nonce-([^']+)'/.exec(policy)![1];
  expect(nonce).not.toBe('attacker-chosen');
  expect(policy).not.toMatch(/unsafe-inline|unsafe-eval/);
  expect(await page.locator('script').evaluateAll(nodes => nodes.every(node => typeof node.nonce === 'string' && node.nonce.length > 0))).toBe(true);
  // Parser-created injected script has no nonce. Automation evaluation itself
  // is privileged and would not faithfully model this HTML injection.
  await page.route('http://127.0.0.1:4773/', async route => {
    const response = await route.fetch();
    await route.fulfill({response, body: (await response.text()).replace('</body>', '<script>window.__unsafeScriptRan=true;</script></body>')});
  });
  const second = await page.reload();
  expect(second!.headers()['content-security-policy']).not.toBe(policy);
  await expect(page.getByText('Access not configured')).toBeVisible();
  // Cookies ignore ports: the page must block even another listener on this host.
  const blocked = await page.evaluate(async () => {
    const target = 'http://127.0.0.1:4774/__fixture/probe';
    const image = document.createElement('img'); image.src = `${target}?image`; document.body.append(image);
    const frame = document.createElement('iframe'); frame.src = `${target}?frame`; document.body.append(frame);
    try {await fetch(`${target}?fetch`, {credentials: 'include'}); return false;} catch {return true;}
  });
  expect(blocked).toBe(true);
  expect(await page.evaluate(() => Reflect.get(window, '__unsafeScriptRan'))).toBeUndefined();
  await expect.poll(async () => (await (await request.get('http://127.0.0.1:4774/__fixture/counts')).json()).probes).toBe(0);
  expect(violations.length).toBeGreaterThan(0);
});
