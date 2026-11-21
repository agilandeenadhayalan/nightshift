# Immutable test rate versions and seed validation

FA-033 integrity prerequisite on `codex/rate-version-integrity`, stacked on PR85 at `45bb2aaa6463fba472de42ae68f15dddb48ae260`. This is an independent engineering subset under FA-007's schema foundation; unresolved FA-002/003 production route/economics decisions remain required for the full catalogue. Verify parent and final-commit CI before handoff.

## Concrete gap

Calls already freeze their rate snapshot, but the referenced `rate_versions` row can still be edited or removed when unused. The fixture seeder uses `ON CONFLICT DO NOTHING`, silently accepting a different persisted policy under a bundled version ID. Preserve current call pricing and snapshots while making version IDs mean one immutable policy.

Migration018 will reject changed updates, deletes and truncation with SQLSTATE23514, while allowing whole-row semantic no-op updates and new inserts under the existing test-only constraint. It changes no existing values. Existing valid or conflicting rows are preserved; a conflict is not automatically repaired.

The seeder keeps its existing transaction and advisory lock. Insert each bundled rate if missing, then read under a shared row lock and validate JSONB equality plus the test-only flag. A fixed `RATE_VERSION_CONFLICT` error aborts the transaction before fixture users, wallets, grants or reviews. A conflict in the second rate also rolls back the first inserted rate. Never print the conflicting policy contents. Do not add an API startup gate, production prices, pack catalogue or SKU placeholders.

## Ownership and verification

- Backend agent owns migration018, `seed.ts`, focused real-database tests and the existing schema test migration list.
- Root registers integration tests and updates evidence/schema/issue documentation.
- Independent review checks append-only semantics, seed atomicity/locking, forward migration and recovery limits.

Capture meaningful RED before the fix. Verify mutation/deletion/truncate rejection, no-op updates, insertion of a new version, unchanged/idempotent seeding, key-order equivalence, first/second-rate conflict rollback, concurrent seeds and a conflicting insert committed while seeding waits. Forward-upgrade fixtures must preserve valid/conflicting rates, existing calls, journal and outbox records; repeated migrations remain stable. Run full isolated backend integration, typecheck/build/unit checks and repository gates. No mobile production change or new APK is required.

No live database migration, repair, deployment or financial transaction is authorized by publishing this slice. Existing private phone database remains at its prior schema. Any real conflicting history needs a separately reviewed repair. Full FA-033 still needs approved tariffs, Listener compensation, route, economics, SKU/region/pack facts and expiring owner-bound quotes; fixtures do not satisfy those gates.

## Execution

- [x] Reproduce two meaningful mutation/seed-conflict failures and implement immutable versions with atomic validation.
- [x] Verify 11 focused and 415 full backend tests (zero failures/skips/cancellations), migration preservation and independent review. Typecheck/build/unit and repository checks pass.
- [x] Publish draft PR #86 stacked on PR #85. Backend, Android and staff CI passed for exact head `a3412e2e910c179eb8e13fd43bca3d6903e22513` in run 44874478124.
