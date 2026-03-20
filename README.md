# Forte ERC721 Guard Demo

[![CI](https://github.com/wangjunjie007/forte-erc721-guard-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/wangjunjie007/forte-erc721-guard-demo/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-3C3C3D)](https://book.getfoundry.sh/)

A practical ERC721 companion demo that shows how to enforce **blacklist checks**, **token lockups**, and an **emergency transfer freeze** on NFTs with **Forte Rules Engine**.

> Status: **public-release ready for local demo use**  
> Validation: **10/10 Foundry tests passing** + **end-to-end integration flow passing**

---

## Why this repo exists

The ERC20 demo proves that Forte can guard fungible transfers. This companion repo extends the same architecture to NFTs, where teams often need different controls:

- block transfers involving sanctioned or restricted wallets
- lock specific NFTs until an unlock date
- freeze market movement during an incident
- preserve a treasury / admin escape hatch when operations need it

Instead of hardcoding all of that directly inside ERC721 transfer logic, this repo routes policy decisions through **Forte Rules Engine**.

---

## What the demo enforces

### 1) Blacklist protection
Transfers revert if either the sender or recipient is blacklisted.

### 2) Token lockup
A token with `tokenUnlockTime[tokenId] > block.timestamp` cannot move until unlock time.

### 3) Emergency transfer freeze
When `transfersPaused` is enabled, non-treasury transfers revert.

### 4) Treasury bypass
A designated treasury address can bypass lockup and pause restrictions.

---

## Core components

- `src/ForteGuardedNFT.sol`  
  ERC721 contract that forwards transfer context into Forte Rules Engine.

- `src/BlacklistOracle.sol`  
  Minimal on-chain blacklist oracle.

- `src/RulesEngineClientCustom.sol`  
  Integration layer for transfer selectors.

- `policy/nft-transfer-guard.policy.json`  
  Policy definition covering `transferFrom` and both `safeTransferFrom` flows.

- `scripts/rebuild-local-stack.sh`  
  One-command rebuild for local anvil + Rules Engine + NFT demo + policy apply + validation.

---

## Repository layout

```text
forte-erc721-guard-demo/
├─ .env.sample
├─ CONTRIBUTING.md
├─ LICENSE
├─ README.md
├─ SECURITY.md
├─ foundry.toml
├─ package.json
├─ policy/
│  └─ nft-transfer-guard.policy.json
├─ script/
│  └─ DeployDemo.s.sol
├─ scripts/
│  ├─ apply-policy-template.ts
│  ├─ apply-policy.ts
│  ├─ assert-policy-state.sh
│  ├─ integration-check.sh
│  ├─ live-check.sh
│  ├─ policy-helper.ts
│  ├─ rebuild-local-stack.sh
│  ├─ run-policy-playground.sh
│  └─ validate-policy-examples.ts
├─ src/
│  ├─ BlacklistOracle.sol
│  ├─ ForteGuardedNFT.sol
│  └─ RulesEngineClientCustom.sol
├─ test/
│  ├─ ForteGuardedNFT.t.sol
│  └─ MockRulesEngine.sol
├─ docs/
│  ├─ ARCHITECTURE.md
│  ├─ DEMO.md
│  ├─ POLICY_COOKBOOK.md
│  ├─ POLICY_PLAYGROUND.md
│  ├─ PUBLISHING.md
│  └─ TYPESCRIPT_HELPER.md
├─ examples/
│  ├─ deployment-summary.example.json
│  └─ policies/
│     ├─ README.md
│     ├─ baseline-nft-transfer-guard.policy.json
│     ├─ emergency-freeze-nft.policy.json
│     ├─ lockup-and-sanctions-only-nft.policy.json
│     └─ strict-no-bypass-nft.policy.json
└─ playground/
   ├─ app.js
   ├─ index.html
   └─ styles.css
```

---

## Prerequisites

- Foundry
- Node.js 20+
- npm
- local shell access to `forge`, `cast`, `anvil`, `jq`

---

## Quick start

### 1. Install dependencies

```bash
npm install
forge install foundry-rs/forge-std --no-git
```

### 2. Rebuild the full local stack

```bash
npm run rebuild:local
```

This will:

1. start a fresh local anvil chain
2. deploy the Forte Rules Engine diamond
3. deploy `BlacklistOracle` and `ForteGuardedNFT`
4. create and apply the NFT transfer policy
5. write `.env`
6. run live validation checks

---

## Verification commands

### Policy example validation

```bash
npm run check:examples
```

This validates the active NFT policy file plus every cookbook template in `examples/policies/`.

### Unit tests

```bash
npm test
```

### End-to-end integration check

```bash
npm run check:integration
```

### Assert the applied policy on the real local Rules Engine

```bash
npm run check:policy
```

### Run only the live NFT transfer scenario checks

```bash
npm run check:live
```

---

## NFT policy cookbook

Developers rarely want a single NFT policy file. They want a set of starting postures they can fork quickly.

This repo now includes:

- `docs/POLICY_COOKBOOK.md` for posture selection and adaptation guidance
- `examples/policies/` for ready-to-copy NFT policy templates
- `npm run check:examples` to keep the cookbook valid in CI

---

## TypeScript / viem helper wrapper

To expand participation beyond Solidity-only contributors, this repo now includes a TypeScript helper layer:

- `npm run policy:templates` to list available NFT cookbook templates
- `npm run policy:apply-template -- --template <name>` to create+apply a template
- `npm run policy:apply-template -- --template <name> --create-only` to create without apply

See `docs/TYPESCRIPT_HELPER.md` for full usage.

---

## Local NFT policy playground

For fast posture simulation, run:

```bash
npm run playground:start
```

Then open:

- `http://127.0.0.1:4174/playground/`

This playground evaluates NFT policy rules from cookbook JSON in-browser and shows a rule-by-rule PASS/FAIL view with final allow/revert outcome.

See `docs/POLICY_PLAYGROUND.md` for usage details.

---

## Why choose ERC721 guard patterns

Use ERC721 guard patterns when:

- individual assets need lock schedules
- NFT transfers must freeze during incidents
- secondary market movement needs policy-level control
- collections need sanctions or blacklist screening without overloading token core logic

If your product mainly cares about amount-based controls, the ERC20 demo is the better starting point. If each asset has its own lifecycle or operational freeze posture, this ERC721 demo is the better fit.

---

## Related repo

- ERC20 companion: `https://github.com/wangjunjie007/forte-erc20-guard-demo`

## License

MIT
