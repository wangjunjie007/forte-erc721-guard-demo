# NFT Policy Templates

These example policy files turn the ERC721 repo into a small **NFT policy cookbook** for Forte integrators.

## Included templates

- `baseline-nft-transfer-guard.policy.json`  
  Baseline NFT posture: blacklist checks, token lockup, emergency freeze, treasury bypass.

- `strict-no-bypass-nft.policy.json`  
  Applies freeze and lockup rules equally to treasury and non-treasury senders.

- `lockup-and-sanctions-only-nft.policy.json`  
  Uses Forte for blacklist + token lockup, without emergency freeze logic.

- `emergency-freeze-nft.policy.json`  
  Incident-response posture that allows only treasury-originated transfers.

- `marketplace-operator-gate-nft.policy.json`  
  Marketplace-oriented posture that allows only direct owners, treasury bypasses, or operators approved in an operator registry.

## How to try one

1. Copy a template over `policy/nft-transfer-guard.policy.json`
2. Re-run validation:
   ```bash
   npm run check:examples
   npm test
   npm run check:integration
   npm run check:policy
   ```

For adaptation guidance, see `docs/POLICY_COOKBOOK.md`.
