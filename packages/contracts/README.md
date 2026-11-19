# Versioned API and event contracts

`openapi.json` is OpenAPI 3.1 for the runnable test milestone, version 0.1.0. `events.schema.json` describes durable participant-authorized event envelopes. Both are generated from `build-contract.mjs`: run `node packages/contracts/build-contract.mjs`, or `node packages/contracts/build-contract.mjs --check` to reject drift.

Backend integration tests validate actual HTTP responses against these schemas. Removing/renaming a required response field or changing a call-state value fails the contract check. Change the contract and consumer together and raise the API version for incompatible released changes.

Flutter currently uses its small checked-in client and typed models to keep the first call slice inspectable. Before growing the endpoint surface, generate a Dart client with OpenAPI Generator's `dart-dio` generator from `openapi.json`, pin the generator image/version, and review changes in `apps/mobile/lib/api/generated/`. Do not hand-edit generated files or move charge computation to Dart. Full generated-client adoption is an outstanding part of FA-007, not claimed complete by this milestone.

Calls accept no price, elapsed duration, arbitrary RTC channel or participant UID from a client. New calls require the test quote ID and an `Idempotency-Key`. Lifecycle actions require the last observed `expectedVersion`; after `STALE_VERSION` retrieve the current call and retry with a fresh key. Replaying the same actor/operation/key/body returns the original response, while reuse with a different body returns `IDEMPOTENCY_CONFLICT`.

The only modes are `customer` and `listener`. Account approval is a server entitlement; there is no staff mode or self-approval endpoint in the mobile API.
