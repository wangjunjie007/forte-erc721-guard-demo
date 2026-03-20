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
- README keeps the base ERC721 repo focused, while this document explains the marketplace-oriented extension path
