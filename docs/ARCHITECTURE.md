# Architecture

The demo follows a small but extensible architecture:

1. `ForteGuardedNFT` owns NFT state and forwards transfer context to Forte Rules Engine.
2. `BlacklistOracle` provides an on-chain blacklist signal.
3. The policy file defines blacklist, lockup, and pause logic outside the NFT core.
4. Local scripts rebuild an anvil-based demo stack and prove reproducibility.

## Encoded values sent to the Rules Engine

- `operator`
- `from`
- `to`
- `tokenId`
- `blockTime`
- `tokenUnlockTime`
- `fromBlacklistFlag`
- `toBlacklistFlag`
- `treasuryBypass`
- `transfersPausedFlag`

This keeps the NFT contract readable while allowing the policy layer to express transfer posture changes.
