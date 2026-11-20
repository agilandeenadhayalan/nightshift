# Staff access foundation

This separate Next.js security boundary supplies the staff session shell for #10, opened from Profile in NightShift's built-in browser. Customer and Listener remain the only application modes. The owner selected staff SMS OTP, not MFA, and the Redmi account for the initial reviewer/access administrator. This web application does not provision an account or infer a grant from customer sign-in.

The backend defaults to staff authentication disabled. Explicit configuration selects the real Firebase verifier and requires separately provisioned permissions and a live source app lineage. With no web server configuration, the page shows that access is not configured and sends no upstream requests. There is no default administrator, provider sign-in form, role override, environment-controlled fixture login, review decision, entitlement or notification action.

## Local commands

Use the repository's Node24.13.0/npm11.6.2 toolchain and root lockfile.

```
npm ci
npm run dev:admin
npm run check:admin
npm exec --workspace @nightshift/admin -- playwright install chromium
npm run test:admin:e2e
```

The development server binds to `127.0.0.1:3100`. Server-only `STAFF_API_BASE_URL` and `STAFF_CONSOLE_ORIGIN` must be complete, fixed origins: HTTPS, or explicit loopback HTTP for local transport. No path, credentials, query, fragment, LAN HTTP, browser-supplied API URL or redirect is accepted. Neither setting enables the backend verifier. Do not put secrets in public Next variables.

## Browser boundary

Only five same-origin operations are proxied: status, challenge, exchange, session and logout. The public wire contract is `@nightshift/contracts/staff.openapi.json`. Staff cookies alone are forwarded; customer cookies, Authorization and forwarded-host headers are excluded. Cookies remain host-only Secure/HttpOnly/SameSite=Strict/Path=/. Mutation requests require the exact configured Origin and JSON body; exchange/logout also require a valid CSRF header which the backend checks against its challenge/session. Backend permissions and current identity are authoritative.

Four distinct `/api/staff/native/...` operations accept the native app bearer: challenge, exchange, access-request and access-request-current. They require a fixed HTTPS console origin, exact Origin and bounded JWT-shaped Authorization, forward only the exchange's challenge cookie, and reject redirects. The server verifies the identity and app lineage; the path name is not an authentication claim. These operations use a15-second deadline to cover sequential bounded provider checks. Proofs never enter the web page. The Android native bridge installs only the returned opaque staff cookie before loading the credential-free page.

The proxy has an eight-second full-request deadline, a bounded JSON body, no redirect following, private no-store responses and safe errors with diagnostic IDs. Cookie and proof values never enter URLs, logs, localStorage or sessionStorage. The page clears private state before rechecking, on expiry and before sign-out. An uncertain sign-out remains hidden through page lifecycle events until an explicit retry confirms the outcome.

## Evidence and limitations

Unit tests exercise actual local HTTP redirect/held-response servers and public-schema validation. Playwright runs a production Next build against `tests/fixture-server.mjs`, a separate loopback-only synthetic upstream. Fixture sessions are installed by the test runner, not a runtime login route. That file is not imported by application code; its controls and identities do not ship in the app bundle. Browser screenshots in ignored artifacts are synthetic UI evidence, not proof of real staff sign-in.

The browser tests cover unconfigured access, permission display, expiry/revocation, stale responses, sign-out uncertainty, keyboard/200%-text layout and enforced nonce-based CSP. Resources/connects are restricted to the same origin, including port; nonces are regenerated server-side for each dynamic document. The authenticated Redmi request/provisioning, real embedded-device evidence and human review criteria remain pending. Review tools remain unavailable.

See [foundation verification](../../docs/Staff_Access_Verification.md) and [embedded integration](../../docs/Embedded_Staff_Verification.md). The latter documents the optional private debug-only CA and `start:local-https` command; neither modifies OS trust nor enables TLS-error bypasses.
