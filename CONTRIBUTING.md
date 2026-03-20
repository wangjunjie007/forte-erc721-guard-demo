# Contributing

Thanks for contributing to the ERC721 companion demo.

## Local setup

```bash
npm install
forge install foundry-rs/forge-std --no-git
```

## Validation before opening a PR

```bash
npm run check:examples
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
- cookbook-style templates under `examples/policies/`
- validation improvements for `npm run check:examples`

## Adding a new NFT policy template

1. Add the JSON file to `examples/policies/`
2. Keep it compatible with the encoded values actually forwarded by the current NFT integration
3. Document the posture in `docs/POLICY_COOKBOOK.md` or `examples/policies/README.md`
4. Run `npm run check:examples` before opening the PR

## Scope guidance

Keep this repo focused on demonstrating policy-driven NFT transfer controls with Forte.
Avoid unrelated product complexity that weakens the teaching value.
