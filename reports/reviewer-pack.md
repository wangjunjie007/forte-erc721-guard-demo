# Reviewer Pack

## Overview

- Source kind: **local**
- Network: **anvil**
- Chain ID: **31337**
- Rules Engine diamond: `0x8A791620dd6260079BF849Dc5567aDC3F2FdC318`
- Marketplace NFT: `0x0dcd1bf9a1b36ce34237eeafef220932846bcd82`
- Policy ID: `1`
- Policy path: `/Users/wangjunjie/.openclaw/workspace/forte-erc721-guard-demo/examples/policies/marketplace-operator-gate-nft.policy.json`

## Contract Addresses

- BlacklistOracle: `0xb7f8bc63bbcad18155201308c8f3540b07f84f5e`
- OperatorRegistry: `0xa51c1fc2f0d1a1b8494ed1fe312d7c3a78ed91c0`
- ForteMarketplaceGuardedNFT: `0x0dcd1bf9a1b36ce34237eeafef220932846bcd82`
- Treasury: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

## Validation Snapshot
- operatorAllowlist: pass
- blacklistRule: pass
- pauseRule: pass
- treasuryBypass: pass
- safeTransferOperatorFlow: pass

## Artifacts

- JSON pack: `reports/reviewer-pack.json`
- Markdown pack: `reports/reviewer-pack.md`
- Source summary: `cache/marketplace-integration-summary.json`
