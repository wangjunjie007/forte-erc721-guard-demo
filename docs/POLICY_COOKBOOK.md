# NFT Policy Cookbook

This repo now includes a small **NFT policy cookbook** so developers can start from named policy postures instead of treating `policy/nft-transfer-guard.policy.json` as a one-off file.

## Why this matters

NFT control surfaces often differ from fungible token flows. Teams usually care about:

- whether a specific asset is unlocked yet
- whether market movement should freeze during an incident
- whether treasury / ops wallets need an escape hatch
- whether blacklist enforcement should apply uniformly or with explicit exceptions

The cookbook makes those posture decisions visible, comparable, and forkable.

---

## Current encoded values in this repo

The demo NFT forwards these values into Forte Rules Engine:

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

That means the templates in `examples/policies/` are intentionally constrained to postures expressible with those values today.

If you later want mint allowlists, marketplace adapters, claim windows, KYC tiers, or creator royalty routing logic, extend the encoded values first and then add a new template + tests.

---

## Included templates

| Template | Best for | Key idea |
| --- | --- | --- |
| `baseline-nft-transfer-guard.policy.json` | General NFT operations | Blacklist + token lockup + emergency freeze with treasury bypass |
| `strict-no-bypass-nft.policy.json` | High-control environments | No treasury bypass for freeze or lockup |
| `lockup-and-sanctions-only-nft.policy.json` | Vesting / claim flows | Keep blacklist + token unlock, remove emergency freeze |
| `emergency-freeze-nft.policy.json` | Incident response | Allow only treasury-originated transfers |

---

## Recommended workflow

### 1) Pick a posture

- **general NFT operations** → start with `baseline-nft-transfer-guard`
- **high-control / no-privileged-bypass pilot** → start with `strict-no-bypass-nft`
- **unlock schedule / claim flow** → start with `lockup-and-sanctions-only-nft`
- **incident response** → start with `emergency-freeze-nft`

### 2) Copy the template into the active policy file

```bash
cp examples/policies/baseline-nft-transfer-guard.policy.json policy/nft-transfer-guard.policy.json
```

### 3) Re-run validation

```bash
npm run check:examples
npm test
npm run check:integration
npm run check:policy
```

---

## Design notes by posture

### Baseline NFT transfer guard

Use this for a general-purpose collection or asset workflow where blacklist enforcement, token unlock scheduling, and an emergency freeze switch all matter.

### Strict no bypass NFT guard

Use this when treasury or admin wallets should not silently bypass freeze or unlock restrictions.

### Lockup and sanctions only NFT guard

Use this when time-based unlock and sanctions screening are the real constraints, but a live emergency freeze switch is unnecessary.

### Emergency freeze NFT guard

Use this when you need a policy-level incident posture that freezes all non-treasury movement quickly.

---

## How to extend the cookbook

A new template should:

1. express a clearly named NFT posture
2. use only encoded values the current integration actually forwards
3. explain why the posture exists, not just what it checks
4. remain reproducible with `npm run check:examples` + local validation

---

## What to build next

High-ROI next steps after this cookbook:

1. add mint / claim / marketplace-specific encoded signals
2. add a TypeScript helper wrapper for ERC721 templates
3. add a browser playground for NFT posture simulation
4. add a marketplace-restriction companion example
