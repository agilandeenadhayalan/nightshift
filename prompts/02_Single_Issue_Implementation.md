# One-issue implementation prompt

```text
Implement <FA-ID> in this repository. Read its body in github/issues/<FA-ID>.md
and use github/import_map.json, if present, to locate its actual GitHub issue.

Read applicable AGENTS.md plus the master plan and relevant contracts/UI/test documents.
Inspect existing behavior and dependency evidence before editing. Do not assume an
upstream issue is implemented merely because it is closed or has a placeholder file.
If a dependency is missing, implement a clearly scoped prerequisite only if authorized,
or report the exact dependency and continue independent work on this issue.

Use the agreed stack. Keep domain logic on the server and preserve wallet/call/privacy
invariants. Use current primary provider docs. Keep migrations backward compatible,
idempotent event handling explicit, and test-only providers impossible in production.
Do not refactor unrelated modules or add frameworks just to complete this task.

Build the end-to-end behavior needed for this issue: API, state, UI, error handling,
telemetry and migration where applicable. Include loading/empty/error/offline states.
Write and run meaningful tests for concurrency, security or money changes, and the
issue's acceptance cases. UI copy/styling alone needs proportionate visual validation.

Prepare a reviewable PR with the concrete problem and resulting behavior, verified
checks, migration/recovery steps and external checks still pending. Reference the
actual GitHub issue only when resolved from evidence. Do not auto-close unverified
criteria, auto-merge, publish or spend money as part of this issue prompt.

Finish with what works, what was actually tested, remaining blockers and the next
dependency-ready FA ID. A missing API key is a configuration blocker, not a reason
to replace real functionality with a fake success screen.
```
