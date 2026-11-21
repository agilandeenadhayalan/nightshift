# Local media connection details

FA-032 / issue #32 engineering continuation on `codex/local-media-diagnostics`, stacked on PR84 at `3d76f5d41bb31bd7c922f6c2d529dfc2e7465bd9`. Verify the parent and this branch's final CI before handoff. FA-028/031 physical acceptance remains separate. Customer and Listener are the only app modes; staff tooling remains separately authorized.

## Outcome

Add an explicit Connection details view for the current or most recent call. Retain a bounded local receipt of typed connection milestones and allowed numeric SDK measurements so an owner can distinguish an accepted invitation from an actual SDK join and inspect failure context. Do not change billing, media readiness, settlement, cleanup ownership or provider configuration. Existing Report remains separate; no automatic upload or diagnostic text injection.

## Boundaries

- One in-memory receipt, replaced by the next call; fixed 15-minute monotonic expiry from creation, never extended by reads/callbacks. Clear synchronously on owner/origin/session invalidation, logout/401 and disposal. An already open dialog must hide cleared data.
- Separate authenticated acceptance observed (`connecting`, `connected` or `reconnecting` only), join requested, actual SDK join callback, local recording, expected-peer decoding, intentional remote mute and cleanup observations. No milestone establishes audible two-way speech. Returning from `join()` is not the SDK join callback; ended/declined calls do not imply acceptance.
- Seven allowlisted numeric summaries: local audio transmit packet loss and bitrate; remote audio frame loss and bitrate; sender-to-receiver delay, receiver-to-jitter-buffer delay and client-to-server delay. Preserve units and missing/invalid values. Buffer delay is not raw jitter. No metric sets readiness, charges or an inferred one-way-audio diagnosis.
- Use fixed milestone slots/bounded counters and count/latest/maximum metric summaries; no unbounded event stream. Capture immutable per-attempt sinks before asynchronous join work. Reject preview, foreign-peer and stale callbacks. Only the original scoped close future can establish later release; timeout remains uncertain and the native release barrier stays intact.
- Export only a random local receipt ID, existing opaque call UUID and allowlisted enums/numbers. Never include SDK objects, channel/UID/token, raw error text, conversation content, audio, phone numbers or account/origin identifiers in the diagnostic payload or export. Internal ownership checks still compare the app's owner/session identity and origin. The local ID is not a remotely retrievable support reference.
- Viewing/copying is an explicit user action, with English/Tamil and large-text support. Guard both visible dialogs and asynchronous copy completion against account changes. No persistence, network request or clipboard mutation follows merely from collecting/viewing data.

## Ownership and verification

Backend agent owns the isolated Dart receipt model and focused tests; mobile agent owns optional audio diagnostics capability, adapter/controller wiring and callback/lifecycle tests; root owns the explicit UI, integration tests and documentation. Coordinate the typed interface and Flutter lane. An independent reviewer examines privacy, owner/attempt fences, TTL and cleanup semantics.

Test actual fake-engine callback wiring for join failure, synthetic packet/frame loss and delay, intentional mute, absent data, foreign/stale callbacks, exact expiry, account/origin changes, held copy operations, late native release and sentinel redaction. Verify no collection-driven HTTP/storage/clipboard effects and unchanged readiness/End behavior. Run full Flutter/analyzer and repository/native checks proportionate to final changes; run `node --test` from `audio/`. Build a separately numbered private configured APK only after source freeze and record its provenance; no install is implied.

Primary SDK evidence is the installed pinned Agora Flutter 6.5.3 source. Current publisher [remote audio statistics](https://pub.dev/documentation/agora_rtc_engine/latest/agora_rtc_engine/RemoteAudioStats-class.html) and [call statistics](https://pub.dev/documentation/agora_rtc_engine/latest/agora_rtc_engine/RtcStats-class.html) corroborate metric meanings; current web documentation is 6.6.4, not a reason to upgrade the pinned SDK. Version-specific web pages were unavailable, so API signatures are checked against the installed 6.5.3 files.

## Execution

- [x] Implement bounded owner/attempt-scoped receipt and model verification: 8 focused cases passed.
- [x] Wire actual SDK callbacks and controller lifecycle without affecting call behavior: 30 focused cases passed.
- [x] Implement explicit localized view/copy with owner-fenced widget verification: 12 cases passed, including real Call/Recents navigation.
- [x] Complete independent review and local checks: 499 Flutter cases passed with 24 explicit platform/time-zone skips, clean analyzer, 3 audio reference and 11 tooling cases. Configured APK 6007 verifies 222 source/four private inputs, signature and 31 ELF/ZIP alignments; no installation.
- [ ] Publish a draft stacked PR and verify its final-commit CI.

Synthetic callbacks are not real network impairment, audible one-way audio or physical capture-stop evidence. This slice does not provide backend QoS retention, remote support lookup, staffed support or complete FA-032 acceptance. Production diagnostic retention/upload policy remains a later owner-reviewed decision; no such storage is activated here.
