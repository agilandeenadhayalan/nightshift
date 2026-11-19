# Local test operations and release gaps

This is an operator procedure for the first test milestone, not evidence of deployed production monitoring. No live charges or payouts are enabled. Product, finance, safety ownership and support hours remain in the decision register.

## RTC or API failure during a test

1. Capture the opaque call ID and stable error code, device model, app version, network type and UTC time. Never capture private voice, tokens, phone numbers or environment contents.
2. Stop the call in either client. If control traffic is unavailable, the app must stop its local media connection; server timeout recovery releases abandoned claims and records the reason.
3. Restart the API with the same database. Verify both participant histories converge on one session and that repeated end requests do not duplicate settlement.
4. If the Agora certificate or app ID is missing, configure an owner-controlled test project locally and retry. Do not bypass token checks, ship a static token or substitute simulated success.

An issued Agora token may outlive a server-side end. Denying renewal is not equivalent to provider-enforced immediate cutoff against a modified client. This remains a paid-launch blocker until the provider adapter and real hostile-client test pass.

## PostgreSQL outage

Stop new call attempts. Never replace durable claims, balances or histories with memory-only fallbacks. Restore PostgreSQL connectivity, run health checks, and let the recovery logic examine existing sessions. Retry idempotent requests using the same key. Investigate discrepancies before clearing any claims manually.

For a backup exercise, use `pg_dump` to an ignored `artifacts/` path, restore to a **separate disposable database**, and compare row counts and journal balances. Do not overwrite the development database or delete the Docker volume as an incident workaround. A production restore drill, retention policy and encrypted off-host backups remain #54.

## Redis outage

Redis presence is expendable; PostgreSQL claims are authoritative. Disconnected listeners must not be shown as newly available solely because Redis restarted. Restore Redis, require fresh authenticated heartbeats and confirm an active claim still prevents a second call. Do not use Redis to reconstruct wallet balances.

## Identity, payment or payout provider incidents

These providers are not enabled by the milestone. Production runbooks must define timeout/pending states, verified event replay, reconciliation, controlled retries and accountable operators before activation. Do not interpret a local test balance as money or send a payout from it.

## Safety or privacy incident

End the encounter and preserve only permitted technical metadata. Keep sensitive reports outside public issues and logs. The owner must nominate the human escalation contact, operating hours and retention process before external testing. No automated workflow can substitute for the pending safety appointment.

## Launch observability still required

Before paid release, implement and test dashboards/alerts for join success and latency, host absence versus technical failure, dropped media, presence freshness, journal discrepancies, pending purchases/refunds/payouts, queue lag and provider cost. Assign each alert to an actual owner and trigger a synthetic alert to a test destination. None of those external deployments or deliveries is claimed by this local document.
