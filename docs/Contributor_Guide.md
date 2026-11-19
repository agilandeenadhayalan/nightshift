# Contributor checks

Use the actual GitHub issue numbers in `github/import_map.json`. Work in dependency order; an implemented test fixture does not satisfy provider, business, release or physical-device acceptance criteria. Keep unfinished gates in `docs/Issue_Status.md`.

Use a `codex/` branch and a focused PR. The FA-001 scope PR is separate; the first Android integration is stacked on that scope because the owner requested continued independent implementation while decisions remain pending. Do not close an issue on partial evidence.

Local supported versions: Node 24.13.0, Flutter 3.27.4 (Dart 3.6.2), JDK 17 or the compatible Android Studio JBR, PostgreSQL 17.7 and Redis 7.4.7. Commit npm and Flutter lockfiles. Keep SQLite files, local databases, provider credentials, environment files and generated builds out of Git.

Run `npm ci`, `npm run check:secrets`, `npm run typecheck`, `npm run build`, `npm test`, `npm run test:integration`, and `npm run test:audio`; run `flutter analyze`, `flutter test`, and `flutter build apk --debug` in `apps/mobile`. Integration tests require a dedicated PostgreSQL database and Redis instance; never point them at production. See the setup runbook for configuration.

The `validation` workflow runs these checks with isolated services. The secret guard includes a deliberate synthetic forbidden-key test, proving the checker recognizes a failing input before restoring a clean checkout. `npm audit --audit-level=high` rejects known high/critical npm vulnerabilities. Neither check proves the absence of every secret or security defect.

Repository owner follow-up: if the GitHub plan supports rulesets for this private repository, require the `backend` and `android` checks and a review on the default branch, block force pushes, and enable GitHub secret scanning where available. We do not claim branch protection is configured or available on the current plan. A green debug build is not a release approval.
