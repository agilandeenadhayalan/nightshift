# ADR-0002: npm workspaces and an explicit Turborepo task graph

Date: 20 November 2026
Status: Accepted for development under the owner's monorepo implementation request
Related GitHub issues: [#4](https://github.com/agilandeenadhayalan/nightshift/issues/4), [#5](https://github.com/agilandeenadhayalan/nightshift/issues/5), [#7](https://github.com/agilandeenadhayalan/nightshift/issues/7)
Decision owner: Agilan Deenadhayalan; reversible engineering choice within the requested implementation, not a production-release approval

## Context

NightShift already has one Flutter Android application, one NestJS backend, a root npm lockfile, Dart lockfile and a runnable browser audio reference. The layout reserves future website, staff and worker applications. Root commands previously delegated mostly to the API, and backend billing rules lived inside that application. As shared code grows, builds need explicit ordering and dependency checks without coupling Flutter's package system to Node.

## Decision

Keep npm workspaces and the existing root lockfile. Pin npm 11.6.2 with Node 24.13.0, add Turborepo 2.11.13, and use explicit workspace registration and repository boundary checks. npm provides local workspace linking; Turbo runs package scripts in dependency order. This uses their documented [workspace model](https://docs.npmjs.com/cli/v11/using-npm/workspaces/) and [repository structure](https://turborepo.dev/docs/crafting-your-repository/structuring-a-repository).

Register the API, mobile task adapter, browser reference, contracts and backend-domain packages. Extract the existing pure server billing calculation into backend-domain. Leave `apps/admin`, `apps/web`, `apps/worker` and `packages/config` as documented reserved boundaries until they contain real implementations. Keep financial state transitions and database transactions in the modular backend.

The Flutter workspace manifest adapts native Flutter commands to the task graph; `pubspec.yaml` and `pubspec.lock` remain authoritative. A contracts dependency orders and invalidates relevant tasks and does not import TypeScript into Dart. This follows Turbo's [multi-language task-wrapper approach](https://turborepo.dev/docs/guides/multi-language).

The allowed graph is API → backend-domain/contracts and mobile task adapter → contracts. Apps do not import other apps. Backend-domain has no runtime dependencies; contracts remain public schemas without private configuration. Package consumers use declared exports, not another package's source paths.

Cache deterministic TypeScript builds and checks only with complete inputs and outputs. All tests, Flutter operations, migrations, seed operations, smoke checks and development services execute uncached. Runtime tasks explicitly pass required environment variables through strict environment filtering. APK caching is deferred because host tooling and signing state are not represented safely by the initial task hash.

## Alternatives

| Option | Assessment for this repository |
|---|---|
| npm scripts alone | Keeps installation simple but would require more custom dependency ordering as shared packages grow. npm remains the installer; Turbo supplies the task graph. |
| Nx | Offers integrated project tooling and [module-boundary enforcement](https://nx.dev/docs/features/enforce-module-boundaries). Reconsider if many applications or teams need its generators and project policies. Current scope can use smaller explicit rules with the existing scripts. |
| pnpm plus Turbo | A valid [workspace alternative](https://pnpm.io/workspaces), but migrating the lockfile, installation behavior, CI and Docker adds work unrelated to the current acceptance criteria. Reconsider if measured install/storage needs justify it. |
| Multiple Flutter apps or separate backend services | Conflicts with the current single-app milestone or adds deployment boundaries without a demonstrated need. Keep one Android application ID and one modular backend. |

These are fit decisions for the present repository, not claims that one tool is universally best.

## Consequences and verification

The root TypeScript build works without the Android SDK. Windows Flutter and WSL 2 backend commands share task names and contracts while retaining their native toolchains. API containers must copy runtime workspace packages and migration assets; npm symlinks alone are insufficient. Installed dependencies and native build caches are not shared across operating systems.

Required checks for this change are a clean install, task-graph inspection, forbidden-boundary regression tests, TypeScript build/static checks, uncached backend/audio tests, dedicated-database integration tests and an API container smoke test. Run Flutter analysis/tests and a debug APK build where its toolchain is available. Verify repeated pure builds can replay from cache while tests still execute. Record actual outcomes in [Verification.md](../Verification.md), without treating this ADR as evidence those checks passed.

The change does not complete physical two-way audio, provider readiness, production identity, billing approval or release gates. Remote caching is explicitly disabled; no paid service is needed. Secrets and local data remain outside Git and task artifacts.

## Follow-up

See [Monorepo.md](../Monorepo.md) for dependency, cache and contributor rules. Revisit the orchestrator when application/team growth or measured build costs require capabilities beyond this graph. Add worker/admin/web packages only alongside their implementation and issue acceptance criteria. Owner-dependent product decisions remain in [Decision_Register.md](../Decision_Register.md).
