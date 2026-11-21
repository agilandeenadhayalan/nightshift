# Reliable final validation

The documentation-only PR #87 head `a1bcc880b661022eb017e4226aea9c21fd3c7b93` exposed two real failures in run 44877261379. Backend validation passed. Android validation stopped at a pinned-generator download returning HTTP 429. Staff validation failed when Next type generation attempted to write `.next/types/routes.d.ts` while the build could clean the same directory. Its cancelled test files are retained as failed-run evidence; they are not counted as passing.

This continuation addresses FA-005 validation reliability within the active PR. Existing journal implementation head `9083a397e8477f4fb8ad74399e4972467b0d4c57` already passed all three jobs. No phone runtime, staff grant, database, provider setting or Android application behavior changes are required.

## Work and ownership

- Backend agent owns the pinned generator download/cache helper, meaningful offline regression tests and the Android CI cache step. Preserve generator version 7.26.0, its exact SHA-256 and verification before execution. Retry only bounded transient failures; respect Retry-After or fail when its delay cannot fit the budget. Never change providers or weaken checksum checks to evade throttling. Publish only a fully verified cache file.
- Mobile agent owns diagnosis of staff validation ordering and the root check command. Build and type generation must not write the same directory concurrently. Reproduce the ordering hazard, verify strict transport tests independently, then run the complete ordered validation. Do not weaken timeouts/assertions or label cancellation as success.
- Independent review checks both changes and their evidence. Root owns documentation, PR description and exact final-head CI.

## Verification and limits

Retain the actual failed job excerpts and links. Exercise generator retries, delay limits, nonretryable errors, checksum rejection and cache integrity with controlled local fixtures; verify the unchanged generated Dart client using the real pinned JAR. Verify actual staff build/typecheck/tests and repository gates. Source changes outside these validation paths need separate justification. Do not repeat the unchanged local 431-case API suite merely for this tooling fix; final CI still runs the repository's required checks.

The Redmi staff enrollment is complete and documented separately: four explicitly approved permissions, one bound session and user-confirmed opening. This validation work must not restart its private API/HTTPS processes or alter those permissions. Production review policy, finance/safety/support ownership, monetary workflows and release acceptance remain open.

## Execution

- [x] Reproduce and fix generator retry/cache behavior and the actual Next shared-directory hazard without weakening integrity checks or transport assertions.
- [x] Verify 16 download/cache tests, all 90 generated client files, 27 repository tooling cases, 19 independent transport cases and four uncached ordered staff tasks including 38 tests. Independent source review found no blocker.
- [ ] Publish the reviewed fixes and verify all three CI jobs at the exact final head.
