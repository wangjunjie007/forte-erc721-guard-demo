# Marketplace Restriction Companion Example

This companion example shows how to extend the ERC721 posture from simple transfer restrictions into **operator-gated marketplace movement**.

## What it adds

- `OperatorRegistry` for allowed marketplace operators
- `ForteMarketplaceGuardedNFT` for ERC721 transfer gating via Forte Rules Engine
- a policy that allows only:
  - direct owner transfers
  - treasury bypass transfers
  - explicitly approved operators

## Why this matters

Many NFT teams do not just care about *whether* a token moves. They care *how* it moves:

- direct wallet-to-wallet transfer
- marketplace operator transfer
- approved operator transfer through specific channels
- emergency halt posture during incidents

This example shows how to move that logic into a policy-driven control surface.

## Validation path

- unit tests in `test/ForteMarketplaceGuardedNFT.t.sol`
- policy file in `examples/policies/marketplace-operator-gate-nft.policy.json`
- deterministic local-chain integration command: `npm run check:marketplace`
- reproducible output summary: `cache/marketplace-integration-summary.json`

## Runbook

```bash
npm run check:marketplace
```

What this does on a fresh anvil chain:

1. deploys the Forte Rules Engine diamond
2. deploys `BlacklistOracle`, `OperatorRegistry`, and `ForteMarketplaceGuardedNFT`
3. wires the NFT to Forte Rules Engine
4. creates and applies the marketplace operator gate policy
5. proves five live behaviors:
   - unapproved operator transfer reverts
   - approved operator transfer succeeds
   - blacklist still blocks approved operators
   - emergency pause still blocks approved operators
   - treasury bypass still works during pause
6. writes `cache/marketplace-integration-summary.json`

README keeps the base ERC721 repo focused, while this document explains the marketplace-oriented extension path.
