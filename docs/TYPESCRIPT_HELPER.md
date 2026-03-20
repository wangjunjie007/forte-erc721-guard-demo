# TypeScript / viem NFT Policy Helper

This repo now ships a TypeScript helper wrapper for local ERC721 policy workflows.

## What it provides

- list available NFT cookbook templates
- load a named template from `examples/policies/`
- create a policy on Forte Rules Engine
- optionally apply that policy to the demo NFT

## Files

- `scripts/policy-helper.ts` — reusable helper module
- `scripts/apply-policy-template.ts` — CLI entrypoint

## Quick usage

### 1) List templates

```bash
npm run policy:templates
```

### 2) Apply a template using `.env`

```bash
npm run policy:apply-template -- --template strict-no-bypass-nft
```

### 3) Create-only mode (no apply)

```bash
npm run policy:apply-template -- --template emergency-freeze-nft --create-only
```

### 4) Explicit arguments

```bash
npm run policy:apply-template -- \
  --template baseline-nft-transfer-guard \
  --rpc http://127.0.0.1:8545 \
  --private-key 0x... \
  --rules-engine 0x... \
  --nft 0x...
```

### 5) Save machine-readable output

```bash
npm run policy:apply-template -- --template lockup-and-sanctions-only-nft --out cache/policy-helper-result.json
```

## Env fallback

The CLI auto-loads `./.env` if present and reads:

- `RPC_URL`
- `PRIV_KEY`
- `RULES_ENGINE_ADDRESS`
- `NFT_ADDRESS`

## Notes

- Current helper is intentionally local-first and targets the anvil/foundry workflow used by this repo.
- For production networks, keep the same workflow shape but update chain/client configuration and key management to match your deployment standards.
