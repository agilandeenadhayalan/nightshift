import {defineConfig} from '@playwright/test';
export default defineConfig({
  testDir: './tests/browser', fullyParallel: false, workers: 1, retries: 0,
  use: {baseURL: 'http://127.0.0.1:4773', browserName: 'chromium', trace: 'off', screenshot: 'only-on-failure'},
  webServer: {command: 'node tests/fixture-server.mjs --test-fixtures', url: 'http://127.0.0.1:4773', reuseExistingServer: false, timeout: 60000},
});
