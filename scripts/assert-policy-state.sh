#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f "$HOME/.zshenv" ]]; then
  source "$HOME/.zshenv"
fi
source ./.env

RPC="$RPC_URL"
DIAMOND="$RULES_ENGINE_ADDRESS"
NFT="$NFT_ADDRESS"
POLICY_ID="$POLICY_ID"

applied="$(cast call "$DIAMOND" "getAppliedPolicyIds(address)(uint256[])" "$NFT" --rpc-url "$RPC")"
closed="$(cast call "$DIAMOND" "isClosedPolicy(uint256)(bool)" "$POLICY_ID" --rpc-url "$RPC")"
disabled="$(cast call "$DIAMOND" "isDisabledPolicy(uint256)(bool)" "$POLICY_ID" --rpc-url "$RPC")"
meta="$(cast call "$DIAMOND" "getPolicyMetadata(uint256)((string,string))" "$POLICY_ID" --rpc-url "$RPC")"

if [[ "$applied" != *"$POLICY_ID"* ]]; then
  echo "ASSERT_FAIL: policy $POLICY_ID not applied to NFT $NFT" >&2
  exit 1
fi

if [[ "$closed" != "false" ]]; then
  echo "ASSERT_FAIL: expected policy $POLICY_ID to be open, got closed=$closed" >&2
  exit 1
fi

if [[ "$disabled" != "false" ]]; then
  echo "ASSERT_FAIL: expected policy $POLICY_ID to be enabled, got disabled=$disabled" >&2
  exit 1
fi

echo "ASSERT_OK"
echo "applied=$applied"
echo "closed=$closed"
echo "disabled=$disabled"
echo "metadata=$meta"
