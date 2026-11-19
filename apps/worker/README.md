# Worker boundary

The first milestone runs recovery from the shared API domain. A separately deployed worker must reuse the same PostgreSQL state and compare-and-set transitions. Queue/outbox delivery and operational separation remain tracked in the issue register; do not start an unrelated backend domain here.
