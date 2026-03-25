# Testnet Route

This document turns the local-only ERC721 marketplace demo into a practical **testnet rollout path**.

It is intentionally split into phases so contributors can validate risk step by step instead of jumping straight from anvil to a public chain.

---

## Goal

Move from:
- local anvil rebuild
- deterministic Rules Engine + NFT policy checks
- reproducible marketplace operator gate validation

To:
- a shared testnet deployment
- reproducible policy application against a real RPC
- a reviewer-friendly verification checklist

---

## Recommended first target

Use **Base Sepolia** first.

Why:
- lower friction for EVM developers already testing on Base
- good fit if the longer-term posture is marketplace / consumer app oriented
- cheaper and simpler than jumping straight to mainnet-like environments

Fallback target:
- **Ethereum Sepolia** if your external reviewer specifically wants Ethereum-native test infrastructure

---

## Suggested rollout phases

### Phase 1 — keep local flow as the source of truth

Before touching testnet, make sure these all pass locally:

```bash
npm test
npm run check:examples
npm run check:integration
npm run check:policy
npm run check:marketplace
```

If local reproducibility is not stable, do **not** promote to testnet yet.

### Phase 2 — deploy marketplace companion contracts to testnet

Target contracts:
- `BlacklistOracle`
- `OperatorRegistry`
- `ForteMarketplaceGuardedNFT`

At this phase, deployment is enough. Do not rush policy application until addresses and ownership are confirmed.

### Phase 3 — wire the Rules Engine and apply the marketplace operator gate policy

Required outcomes:
- Rules Engine address set on the NFT
- calling contract admin configured correctly
- `examples/policies/marketplace-operator-gate-nft.policy.json` created on the target Rules Engine
- policy applied to the deployed marketplace NFT

### Phase 4 — publish an external verification runbook

A reviewer should be able to verify all of this without reading the whole codebase:
- operator not allowlisted → transfer fails
- operator allowlisted → transfer succeeds
- blacklisted recipient still fails
- emergency pause still blocks non-treasury movement
- treasury bypass still works

---

## Environment model

Use a dedicated testnet env file instead of overloading the local `.env`.

Suggested shape:

```bash
TESTNET_RPC_URL=
TESTNET_PRIVATE_KEY=
RULES_ENGINE_ADDRESS=
BLACKLIST_ORACLE_ADDRESS=
OPERATOR_REGISTRY_ADDRESS=
MARKETPLACE_NFT_ADDRESS=
TREASURY_ADDRESS=
POLICY_ID=
POLICY_PATH=examples/policies/marketplace-operator-gate-nft.policy.json
TARGET_CONTRACT_ADDRESS=
```

Recommended practice:
- use a dedicated deployer wallet for testnet only
- keep treasury / admin addresses explicit
- never reuse local anvil assumptions in testnet scripts

---

## What must change before a real testnet script is production-ready

The current repo now has a deterministic **local** marketplace integration path.

For a durable testnet path, the next script should:

1. **skip fresh anvil boot logic**
   - testnet scripts should never assume a resettable chain

2. **accept explicit RPC + private key inputs**
   - no local default fallbacks

3. **persist deployment artifacts separately**
   - e.g. `cache/testnet-deployment-summary.json`

4. **separate create-policy from apply-policy when needed**
   - useful if reviewers want to inspect the policy before applying

5. **print explorer-friendly verification output**
   - contract addresses
   - tx hashes
   - policy id
   - owner / treasury / operator registry addresses

---

## Reviewer checklist for a first public testnet demo

A good first external demo should include:

- network name + chain id
- deployed contract addresses
- policy id
- exact policy JSON path used
- one operator address marked allowed
- one blocked transfer example
- one successful operator-mediated transfer example
- one pause-blocked example
- one treasury bypass example
- transaction hashes for each assertion when possible

---

## Current implementation status

The repo now includes:

- `scripts/testnet-marketplace-deploy.sh`
- `scripts/testnet-marketplace-verify.sh`
- `.env.testnet.marketplace.sample`

Core command flow:

```bash
cp .env.testnet.marketplace.sample .env.testnet.marketplace
# fill in TESTNET_RPC_URL / TESTNET_PRIVATE_KEY / RULES_ENGINE_ADDRESS
npm run deploy:testnet-marketplace
npm run verify:testnet-marketplace
```

Artifacts written locally:
- `cache/testnet-marketplace-deployment-summary.json`
- `cache/testnet-marketplace.env`
- `cache/testnet-marketplace-verify-summary.json`

This turns the repo from a local-only showcase into a reviewer-shareable developer asset.

---

## What not to do

- do not mix local anvil defaults with public testnet deployment assumptions
- do not hardcode treasury / operator addresses into reusable scripts
- do not skip the policy verification step after apply
- do not market the testnet flow as reproducible until the summary artifact and verification checklist are both stable
