# Local NFT Policy Playground

This playground is a local UI for comparing NFT cookbook policy postures and simulating ERC721 transfer outcomes.

## What it does

- select one of the NFT policy templates in `examples/policies/`
- choose calling function (`transferFrom`, `safeTransferFrom`, `safeTransferFromWithData`)
- set transfer context inputs (token id, block time, unlock time, blacklist flags, treasury flag, pause flag)
- see rule-by-rule pass/fail and final allow/revert outcome

## Start

```bash
npm run playground:start
```

Then open:

- `http://127.0.0.1:4174/playground/`

Use a custom port:

```bash
npm run playground:start -- 8080
```

## Notes

- this is a local simulation tool, not an on-chain execution engine
- it evaluates policy rules from NFT policy JSON in-browser for fast posture comparison
- use it to sanity-check design intent before creating/applying policies on local anvil
