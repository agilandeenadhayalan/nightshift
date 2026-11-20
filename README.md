# NightShift

One Flutter Android application, one application ID, and exactly two user-facing modes: **Customer** and **Listener**. Both use one shared NestJS backend backed by PostgreSQL. Redis tracks short-lived presence; Agora carries voice and optional private test video. Staff tools remain separate.

The first Android implementation uses fictional identities and test credits. The API refuses production startup. The [foreground two-phone milestone passed on 20 November 2026](docs/Device_Debug_2026-11-20.md), including audible speech, either-party hangup and durable histories. Reconnect stability, broader device coverage, provider-side cutoff, production sign-in, payments and launch approvals remain open. See [issue status](docs/Issue_Status.md) and the [decision register](docs/Decision_Register.md).

[Private video calling](docs/Video_Calling.md) extends the same app and call lifecycle with camera preview/consent, camera controls and an explicit new audio call for fallback. `VIDEO_CALLS_ENABLED` is off by default; enable it only in the ignored environment for a private local test stack. Video uses a proposed engineering fixture of 120 test coins/minute, separate from 60 for audio; no production price is approved. #57 and #58 remain implemented subsets with device/provider evidence and dependency/public-release gates open. See the video document for the current verification evidence.

## Run the Android milestone

Follow [Windows Flutter + WSL 2 backend setup](docs/Local_Development.md) for PostgreSQL/Redis, test seeding, server-only Agora configuration, the APK build and two-device networking.

| Path | Purpose |
|---|---|
| `apps/mobile` | Single Flutter app: Customer and Listener |
| `apps/api` | Shared NestJS sessions, presence, calls, test billing and history |
| `db/migrations` | PostgreSQL schema and constraints |
| `packages/contracts` | Versioned API/event contracts and generated Dart SDK |
| `packages/backend-domain` | Pure billing rules imported by the backend |
| `infra` | Local PostgreSQL/Redis Compose stack |
| `apps/admin`, `apps/web`, `apps/worker` | Boundaries for subsequent staff/public/worker work |
| `audio` | Preserved independent browser reference |

## Checks

The monorepo uses **npm workspaces + Turborepo** for task dependencies and local TypeScript build caching. Flutter keeps its native pub/Gradle toolchain. See [monorepo commands and boundaries](docs/Monorepo.md).

Use Node 24.13.0 (`.node-version` / `.nvmrc`), its bundled npm 11.6.2, and Flutter 3.27.4. From the repository root:

```sh
npm ci
npm run check:repo
npm run typecheck
npm run build
npm test
npm run test:integration
npm run test:economics
```

`npm test` includes backend, domain and browser-reference tests. Integration tests require a separate test database; see the setup runbook. From the root with Flutter on PATH:

```sh
npm run check:mobile
npm run build:android
```

The Android command builds the ARM64 debug APK. Native Flutter commands from `apps/mobile` remain supported, including `flutter build apk --debug` for a universal APK. See [verification evidence](docs/Verification.md), [two-phone procedure](docs/Two_Phone_Test.md), and [contributor checks](docs/Contributor_Guide.md). An APK build does not establish audible two-way media on physical phones.

API changes also require `npm run generate:client` and `npm run check:client` with Java 17+. The official generator is pinned and checksum-verified; ordinary app builds use the checked-in Dart SDK. With the local backend running, `npm run smoke:client` checks the generated SDK's actual HTTP call/history journey using the ignored local environment.

The Flutter navigation/state continuation and its physical accessibility checklist are tracked in [FA-008 verification](docs/FA008_Verification.md). Automated loading, retry, restoration and semantics tests complement the required real-phone checks.

The [account and application continuation](docs/Account_Application_Verification.md) adds phone sign-in and secure refresh, adult onboarding, private Listener applications, consent history and deletion receipts. Provider configuration remains disabled by default; real SMS, physical account journeys, staff review and retention approvals remain separate. The [all-issue completion plan](docs/Backlog_Completion_Plan.md) records the exact dependencies and outstanding work.

## Browser reference

With Node 24, from `audio/` run `node --test`, then `node server.mjs`. Open the printed private localhost URL in two Chromium tabs. Choose Listener and go online in one, Customer and call in the other. Answer, allow microphones, end and check statements. It supports one pair with test credits and creates an ignored local SQLite database. See [audio/README.md](audio/README.md).

## Product and backlog

Read [AGENTS.md](AGENTS.md), [master plan](NightShift_Master_Plan.md), [product scope](docs/Product_Scope.md), and [engineering contracts](docs/Engineering_Contracts.md). Detailed acceptance criteria are in `github/issues/FA-001.md` through `FA-064.md`; `github/import_map.json` maps actual GitHub issue numbers.

Work in dependency order, cite actual issue numbers in PRs, preserve audio tests, and record unresolved decisions. Keep provider keys, identity files, local databases and generated builds out of Git. This project must remain independent of employer code, data and accounts.
