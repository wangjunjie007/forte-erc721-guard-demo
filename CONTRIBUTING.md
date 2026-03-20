# Contributing

Thanks for contributing to the ERC721 companion demo.

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

## Good contributions

- clearer NFT policy-driven examples
- stronger test coverage for transfer restrictions
- better local reproducibility
- more precise docs and demo material
- companion examples for marketplace or mint restrictions

## Scope guidance

Keep this repo focused on demonstrating policy-driven NFT transfer controls with Forte.
Avoid unrelated product complexity that weakens the teaching value.
