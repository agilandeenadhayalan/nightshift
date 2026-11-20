# Backend domain

`@nightshift/backend-domain` owns the pure server-side test-credit billing policy:
the frozen audio/video rate snapshots, customer charge calculation, and illustrative listener
earnings calculation. Its public entry is compiled CommonJS with TypeScript
declarations. Consumers import `@nightshift/backend-domain`; they do not import
another workspace's source files.

The package has no runtime dependencies, framework, database, network, or mobile
APIs. `check:boundaries` rejects runtime dependencies and source imports outside
this package. The TypeScript configuration excludes ambient Node/browser APIs.
NestJS remains in `apps/api`, where PostgreSQL transactions, verified connected
intervals, authorization, call lifecycle, and settlement idempotency belong.
Flutter displays server results and never computes a charge or earning.

These rules use development fixtures, not approved paid
tariffs. Audio customer charges match `audio/billing.mjs`: free through 40 seconds,
then a 60-second minimum and cumulative whole-second rounding. Listener earnings
use delivered milliseconds at the illustrative rate, independently of customer
charges, and round once per settlement. Inputs are the nonnegative, finite
connected durations established by the API. `test-video-v1` has its own frozen
120-coin/minute rate, twice the audio rate, with the same threshold and duration
rounding. Its illustrative listener rate remains unchanged. Call creation fixes
the selected snapshot; a fallback to audio requires ending video and accepting
a new audio invitation. Omitting the optional rate argument preserves audio
calculation compatibility.

From the repository root, the task graph builds this package before its tests or
API consumers. To work on it directly:

```sh
npm run build --workspace @nightshift/backend-domain
npm run typecheck --workspace @nightshift/backend-domain
npm run test --workspace @nightshift/backend-domain
npm run check:boundaries --workspace @nightshift/backend-domain
```

Tests resolve the public package entry and compare customer charges with the
browser reference. Changing the browser tariff must invalidate this test task's
cache, even though the reference is not a production dependency.

The one-process recovery worker remains in `apps/api` and scans durable calls and
the transactional outbox. A future separately deployed worker can consume this
package; it is not implemented by this extraction. PostgreSQL locks and
constraints remain authoritative. Run only one API replica until shared
Socket.IO fan-out and worker ownership have been load-tested.
