# Money and call correctness review prompt

```text
Review the implemented call/payment system against docs/Engineering_Contracts.md and
FA-022,027,028,033–043,050. Inspect code and execute appropriate tests; do not rely on
README claims. Do not perform a live payment or payout without that specific task scope.

Trace one purchase to verified receipt, credit lot, balanced journal, spend hold,
connected interval, customer debit, listener earning, payout and refund. Verify
integer units, rounding, per-unit journal conservation and deterministic idempotency.
Confirm the client cannot dictate money, roles, elapsed duration or purchase success.

Race two callers for one listener; race two calls from one customer; race accept/cancel.
Replay/reorder payment, RTC and payout notifications. Inject process/DB/Redis/provider
failure and verify recovery. Test unknown payout results without issuing a blind retry.

Verify that media cannot continue when credit authorization expires even if a modified
client ignores hang-up and reuses old tokens. A token expiry assumption alone is not
evidence. Verify no charge during ringing or disconnect gaps and a bounded, clearly
funded reconnect grace.

Return findings ordered by severity with file references and reproduction steps.
State which checks used real PostgreSQL, provider sandbox or actual devices, and which
remain untested. Treat duplicate money, negative spendable balance, unauthorized media
or unbounded unpaid continuation as paid-launch blockers. Propose small concrete fixes.
```
