#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f "$HOME/.zshenv" ]]; then
  source "$HOME/.zshenv"
fi

export NO_PROXY="${NO_PROXY:+$NO_PROXY,}127.0.0.1,localhost"
export no_proxy="${no_proxy:+$no_proxy,}127.0.0.1,localhost"

source ./.env

RPC="$RPC_URL"
DIAMOND="$RULES_ENGINE_ADDRESS"
TARGET_CONTRACT="${TARGET_CONTRACT_ADDRESS:-${MARKETPLACE_NFT_ADDRESS:-${NFT_ADDRESS:-}}}"
if [[ -z "$TARGET_CONTRACT" ]]; then
  echo "ASSERT_FAIL: TARGET_CONTRACT_ADDRESS / MARKETPLACE_NFT_ADDRESS / NFT_ADDRESS missing" >&2
  exit 1
fi
POLICY_ID="$POLICY_ID"

applied="$(cast call "$DIAMOND" "getAppliedPolicyIds(address)(uint256[])" "$TARGET_CONTRACT" --rpc-url "$RPC")"
closed="$(cast call "$DIAMOND" "isClosedPolicy(uint256)(bool)" "$POLICY_ID" --rpc-url "$RPC")"
disabled="$(cast call "$DIAMOND" "isDisabledPolicy(uint256)(bool)" "$POLICY_ID" --rpc-url "$RPC")"
meta="$(cast call "$DIAMOND" "getPolicyMetadata(uint256)((string,string))" "$POLICY_ID" --rpc-url "$RPC")"

if [[ "$applied" != *"$POLICY_ID"* ]]; then
  echo "ASSERT_FAIL: policy $POLICY_ID not applied to contract $TARGET_CONTRACT" >&2
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
