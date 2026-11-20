# Monorepo verification — 20 November 2026

This records the npm-workspaces/Turborepo follow-up to the first Android implementation. It contributes to GitHub issues #4, #5 and #7; it does not mark their remaining acceptance criteria or the two-phone milestone complete.

## Automatically verified

| Check | Result |
|---|---|
| Root repository gate | Secret/file guard, contract drift check and both architecture guards passed. |
| Tooling regressions | 10 passed: 8 architecture fixtures and 2 secret-guard cases. Forbidden dependency edges and private imports fail; explicitly exported public JSON schemas pass. |
| TypeScript | API and backend-domain typechecks and builds passed through the task graph. |
| Domain/API unit tests | 5 domain and 2 API tests passed. Domain customer charges match the independent browser reference across rounding boundaries and sampled durations. |
| Browser reference | All 3 existing Node tests passed; its runtime and billing implementation were preserved. |
| PostgreSQL/Redis integration | All 18 tests passed against a dedicated local test database with isolated per-run schemas. |
| Flutter | Static analysis reported no issues; all 25 tests passed through the root task adapter. |
| Economics | All 10 Python tests passed. |
| Dependency audit | npm reported zero known vulnerabilities in the locked dependency set. |
| Cache behavior | A repeated backend build hit all 3 build caches. A temporary source-only domain change altered both domain and downstream API task hashes while preserving the unrelated contracts hash; original source bytes were restored. Test and Android tasks reported cache bypass and executed. |
| Clean Linux container build | Both build and runtime dependency installs succeeded from the root lockfile. The runtime resolved the compiled domain workspace, applied migrations, seeded fictional accounts and became healthy. |
| Packaged HTTP journey | Real login, availability, discovery, invitation, acceptance, end and both participants' completed history passed against the rebuilt container. No media event was fabricated; the call cost zero. |
| Android artifact | Root `npm run build:android` produced the ARM64 debug APK with the same application ID and two modes. |

Total automated test cases: **73** (10 tooling + 5 domain + 2 API + 3 audio + 18 integration + 25 Flutter + 10 economics). Builds, static checks, cache probes and the HTTP smoke journey are additional checks, not included in that count.

The container follow-up used Windows Docker Desktop's Linux engine consistently; the earlier WSL 2 run is recorded separately in [Verification.md](Verification.md). No unrelated containers or volumes were modified.

Safe diagnostic call ID for the container smoke test: `1b40ef93-57e1-4fcc-bc42-a893f2a73ba9`.

APK: `apps/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, 159,492,318 bytes. SHA256: `0e16a32ae87cc3e8f763755e8c79d3e4cba0c693a9c2ff8f63a4066e0cf7da2a`. The rebuild is byte-identical to the preceding verified ARM64 debug artifact. Build outputs remain ignored.

## Still requires external evidence

No physical phones or owner-controlled Agora credentials were available. Audible two-way media, provider cutoff and actual-device behavior remain unverified; follow [Two_Phone_Test.md](Two_Phone_Test.md). The optional Playwright browser-media script was not run. Full generated Dart-client adoption, production identity/payments, background calling, staff operations and release approvals remain tracked in [Issue_Status.md](Issue_Status.md).

See [Monorepo.md](Monorepo.md) for commands, ownership, environment handling and cache policy.
