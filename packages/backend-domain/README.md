# Backend domain boundary

The first Android milestone executes domain rules in `apps/api/src/service.ts` and `billing.ts`, inside the NestJS process and PostgreSQL transactions. Flutter never computes a charge or earning. This directory is the planned extraction boundary for a separately deployed worker; it is intentionally not a duplicate implementation.

The current one-process recovery worker in `createApplication` scans durable calls and the transactional outbox every second. PostgreSQL locks/constraints, not a JavaScript map, authorize calls and settlement. Run only one API replica until shared Socket.IO fan-out and worker ownership have been load-tested. Snapshot/history recovery remains authoritative after a lost notification.
