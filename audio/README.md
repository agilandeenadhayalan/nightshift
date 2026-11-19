# NightShift audio calling
Run with Node.js 24 or later. From this directory run:

    node server.mjs

Open the private localhost URL printed by the server in two Chromium tabs. Choose Customer in one and Listener in the other. Click Go online as the listener, Call listener as the customer, then Answer. Allow microphone access. Headphones help prevent feedback. End the call to see both statements. Only one customer/listener pair should use the local app at a time.

## launch tariff
The customer starts with 10,000 test coins. 60 coins cost ₹20 and earn one listener diamond. The listener earns ₹500 per 60 diamonds. A full hour costs 3,600 coins (₹1,200). ₹700 remains before tax, fees and operating expenses. The modeled operating contribution is approximately ₹330 before fixed costs under the earlier assumptions. Customer prices are tax-inclusive in that illustration.

The implementation assumes the 40-second rule applies once at the beginning. A maximum of one call can use the wallet. It requires at least 60 coins to start. Ringing and waiting are free. Up to and including 40 connected seconds costs zero. Crossing 40 seconds costs 60 coins, covering through 60 seconds. After that, each additional second started costs one coin and earns 1/60 diamond. Gaps reported by peers pause metering. The server closes the call when available coins run out. Payout rounds only after summing all earned coins.

## Verification
Run node --test for pricing boundaries. The optional browser_test.py uses Python Playwright, Chromium and fake microphone input to exercise two peers through the actual payment threshold. Start the server with a fresh database and pass the printed URL to the test. It takes roughly 45 seconds.

## Scope
This local browser implementation uses WebRTC for audio, server-side elapsed time and SQLite for completed call records. Restarting the server retains settled receipts and clears unfinished calls. It relies on participant-reported connection state and a heartbeat timeout. The demo link permits either role. Use test credits only. A public deployment needs individual authentication, an authoritative media provider event source, durable in-progress sessions and reservations, payment verification, moderation controls and real-device network tests. Flutter, MSG91/DLT, Firebase, Agora and cash withdrawals belong to that release. There are no provider keys to configure for the local demonstration.
