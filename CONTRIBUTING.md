# Contributing

Thanks for improving this ERC721 companion demo.

## Local setup

```bash
npm install
forge install foundry-rs/forge-std --no-git
```

## Validation before opening a PR

```bash
npm test
npm run check:integration
npm run check:policy
```

## Good contribution scope

- clearer NFT-specific policy examples
- stronger transfer safety/lockup test coverage
- reproducibility improvements for local stack rebuild
- concise docs for ERC721 integration posture

## Style

- keep transfer logic readable
- avoid unnecessary abstraction for demo code
- preserve deterministic local validation
