# Demo flow

A good public demo flow for this repo:

1. rebuild the local stack with `npm run rebuild:local`
2. mint an NFT to Alice
3. pause transfers and show Alice transfer reverting
4. show treasury transfer still succeeding during pause
5. blacklist Bob and show Alice -> Bob transfer reverting
6. add a token lockup and show transfer reverting until unlock
7. run `npm test` and `npm run check:integration`

This demonstrates blacklist, lockup, and incident-response posture in one concise flow.
