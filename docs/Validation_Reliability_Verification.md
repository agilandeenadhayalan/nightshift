# Final validation reliability

This FA-005 continuation addresses observed failures in [PR #87](https://github.com/agilandeenadhayalan/nightshift/pull/87). It changes validation tooling rather than the private phone application or its staff permissions.

## Failure evidence

The journal implementation commit `9083a397e8477f4fb8ad74399e4972467b0d4c57` passed backend, Android and staff jobs in [run 44876049224](https://github.com/agilandeenadhayalan/nightshift/actions/runs/44876049224). The subsequent documentation-only commit `a1bcc880b661022eb017e4226aea9c21fd3c7b93` passed backend checks but failed two jobs in [run 44877261379](https://github.com/agilandeenadhayalan/nightshift/actions/runs/44877261379):

- Android stopped during `check:client`: downloading the pinned OpenAPI Generator JAR returned HTTP 429. Later mobile checks and the APK build did not run in that attempt.
- Staff `check:admin` launched build, type generation and tests concurrently. Type generation failed with `ENOENT` for `.next/types/routes.d.ts` while the build could clean the same directory. The failed job also reported 37 passing cases and two cancelled test files. Those cancellations remain part of the failed attempt, not passing evidence. The two affected transport files passed all 19 tests when run independently.

Ignored local failure excerpts are `artifacts/pr87-android-ci-failure.log` and `artifacts/pr87-staff-ci-failure.log`. Their source run/job links are retained. Passing a later run does not erase these failures.

## Corrective scope and verification

The generator retains version 7.26.0 and its exact pinned SHA-256, including verification before executing a cached JAR. It now makes at most three attempts for transient network/stream failures or HTTP 429/500/502/503/504. Per-attempt download time is bounded to 60 seconds, the total download budget to 180 seconds, retry delays to 30 seconds and body size to 64 MiB. Valid Retry-After seconds or canonical HTTP dates are honored; invalid or over-budget instructions fail rather than becoming shorter waits. Permanent HTTP errors, redirects, checksum failures and invalid existing caches are not retried.

Only verified bytes enter a temporary file. Exclusive hard-link publication cannot overwrite a concurrent cache file, and the published winner is verified again. Every existing cache hit is checked. The Android workflow uses an exact version/hash cache key without a broader restore prefix, using the [official cache action](https://github.com/actions/cache). A cache does not turn a failed network or integrity check into success.

Staff `check:admin` now uses `--concurrency=1`, so Next build cleanup and type generation cannot mutate `.next` at the same time. A controlled interleaving of the actual pinned Next commands reproduced the exact missing-file error. The original transport tests passed independently, and the complete ordered check passed without changing runtime code, fixtures, assertions or deadlines. The earlier file cancellations are consistent with sibling-task cancellation after the type-generation failure; an independent transport defect was not reproduced.

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Retry baseline | One meaningful retry failure plus two passing cache controls | `generator-download-red.log` |
| Download/cache regression | 16 passed; zero failures/skips/cancellations | `generator-download-focused.log` |
| Real pinned generator | All 90 checked-in Dart files match; existing valid JAR retained | `generator-client-check-final.log` |
| Repository/contracts/boundaries/secret checks | Passed, including 27 tooling cases | `generator-repo-check-final.log` |
| Actual Next ordering reproduction | Exact `ENOENT` reproduced when build cleanup interrupted type generation | `pr87-admin-validation-race-RED.log` |
| Independent affected transport tests | 19 passed; zero failures/skips/cancellations | `pr87-admin-transport-baseline.log` |
| Forced ordered staff validation | Four uncached tasks passed, including 38 tests with zero cancellations; 11.835 seconds | `pr87-admin-validation-GREEN.log` |
| Independent source review | No blocking findings | Recorded in the PR |
| Final-head backend/Android/staff CI | Pending | Recorded in the PR after completion |

The offline download tests cover retry dates/delays/budgets, permanent errors/redirects, checksum/cache rejection, body bounds, interrupted and held bodies, hanging requests/waits, late completion and concurrent publication. No existing valid JAR was removed to force extra provider requests. No new local API integration run was needed for these tooling-only changes; the unchanged 431-case backend suite passed both locally and in the observed CI runs, and required final CI still runs it.

The Redmi enrollment remains separately verified: exactly four approved staff permissions, one bound session and owner-confirmed opening inside NightShift. No live API/HTTPS restart, database migration, application installation or permission change is part of this tooling repair. Full product/release acceptance remains tracked in [Issue_Status.md](Issue_Status.md).
