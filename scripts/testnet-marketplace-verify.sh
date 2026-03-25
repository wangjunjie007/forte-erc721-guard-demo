#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$ROOT_DIR/cache"
VERIFY_SUMMARY_PATH="${VERIFY_SUMMARY_PATH:-$CACHE_DIR/testnet-marketplace-verify-summary.json}"
DEFAULT_ENV_FILE="$ROOT_DIR/.env.testnet.marketplace"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"

mkdir -p "$CACHE_DIR"

if [[ -f "$HOME/.zshenv" ]]; then
  source "$HOME/.zshenv"
fi

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

export NO_PROXY="${NO_PROXY:+$NO_PROXY,}127.0.0.1,localhost"
export no_proxy="${no_proxy:+$no_proxy,}127.0.0.1,localhost"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

normalize_address() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

require_cmd cast
require_cmd jq

TESTNET_RPC_URL="${TESTNET_RPC_URL:-${RPC_URL:-}}"
CHAIN_NAME="${CHAIN_NAME:-${TESTNET_CHAIN_NAME:-unknown}}"
CHAIN_ID_EXPECTED="${CHAIN_ID:-${TESTNET_CHAIN_ID:-}}"
RULES_ENGINE_ADDRESS="${RULES_ENGINE_ADDRESS:-}"
BLACKLIST_ORACLE_ADDRESS="${BLACKLIST_ORACLE_ADDRESS:-}"
OPERATOR_REGISTRY_ADDRESS="${OPERATOR_REGISTRY_ADDRESS:-}"
MARKETPLACE_NFT_ADDRESS="${MARKETPLACE_NFT_ADDRESS:-${TARGET_CONTRACT_ADDRESS:-}}"
TARGET_CONTRACT_ADDRESS="${TARGET_CONTRACT_ADDRESS:-$MARKETPLACE_NFT_ADDRESS}"
TREASURY_ADDRESS="${TREASURY_ADDRESS:-}"
POLICY_ID="${POLICY_ID:-}"
POLICY_PATH="${POLICY_PATH:-$ROOT_DIR/examples/policies/marketplace-operator-gate-nft.policy.json}"

require_env TESTNET_RPC_URL
require_env RULES_ENGINE_ADDRESS
require_env BLACKLIST_ORACLE_ADDRESS
require_env OPERATOR_REGISTRY_ADDRESS
require_env MARKETPLACE_NFT_ADDRESS
require_env TARGET_CONTRACT_ADDRESS
require_env POLICY_ID

CHAIN_ID_ACTUAL="$(cast chain-id --rpc-url "$TESTNET_RPC_URL")"
if [[ -n "$CHAIN_ID_EXPECTED" && "$CHAIN_ID_EXPECTED" != "$CHAIN_ID_ACTUAL" ]]; then
  echo "VERIFY_FAIL: expected chain id $CHAIN_ID_EXPECTED but got $CHAIN_ID_ACTUAL" >&2
  exit 1
fi

NFT_RULES_ENGINE="$(cast call "$MARKETPLACE_NFT_ADDRESS" 'rulesEngineAddress()(address)' --rpc-url "$TESTNET_RPC_URL")"
NFT_TREASURY="$(cast call "$MARKETPLACE_NFT_ADDRESS" 'treasury()(address)' --rpc-url "$TESTNET_RPC_URL")"
NFT_ORACLE="$(cast call "$MARKETPLACE_NFT_ADDRESS" 'blacklistOracle()(address)' --rpc-url "$TESTNET_RPC_URL")"
NFT_OPERATOR_REGISTRY="$(cast call "$MARKETPLACE_NFT_ADDRESS" 'operatorRegistry()(address)' --rpc-url "$TESTNET_RPC_URL")"
APPLIED_POLICIES="$(cast call "$RULES_ENGINE_ADDRESS" 'getAppliedPolicyIds(address)(uint256[])' "$TARGET_CONTRACT_ADDRESS" --rpc-url "$TESTNET_RPC_URL")"
POLICY_CLOSED="$(cast call "$RULES_ENGINE_ADDRESS" 'isClosedPolicy(uint256)(bool)' "$POLICY_ID" --rpc-url "$TESTNET_RPC_URL")"
POLICY_DISABLED="$(cast call "$RULES_ENGINE_ADDRESS" 'isDisabledPolicy(uint256)(bool)' "$POLICY_ID" --rpc-url "$TESTNET_RPC_URL")"
POLICY_METADATA="$(cast call "$RULES_ENGINE_ADDRESS" 'getPolicyMetadata(uint256)((string,string))' "$POLICY_ID" --rpc-url "$TESTNET_RPC_URL")"

if [[ "$(normalize_address "$NFT_RULES_ENGINE")" != "$(normalize_address "$RULES_ENGINE_ADDRESS")" ]]; then
  echo "VERIFY_FAIL: rulesEngineAddress mismatch ($NFT_RULES_ENGINE != $RULES_ENGINE_ADDRESS)" >&2
  exit 1
fi

if [[ "$(normalize_address "$NFT_ORACLE")" != "$(normalize_address "$BLACKLIST_ORACLE_ADDRESS")" ]]; then
  echo "VERIFY_FAIL: blacklistOracle mismatch ($NFT_ORACLE != $BLACKLIST_ORACLE_ADDRESS)" >&2
  exit 1
fi

if [[ "$(normalize_address "$NFT_OPERATOR_REGISTRY")" != "$(normalize_address "$OPERATOR_REGISTRY_ADDRESS")" ]]; then
  echo "VERIFY_FAIL: operatorRegistry mismatch ($NFT_OPERATOR_REGISTRY != $OPERATOR_REGISTRY_ADDRESS)" >&2
  exit 1
fi

if [[ -n "$TREASURY_ADDRESS" && "$(normalize_address "$NFT_TREASURY")" != "$(normalize_address "$TREASURY_ADDRESS")" ]]; then
  echo "VERIFY_FAIL: treasury mismatch ($NFT_TREASURY != $TREASURY_ADDRESS)" >&2
  exit 1
fi

if [[ "$APPLIED_POLICIES" != *"$POLICY_ID"* ]]; then
  echo "VERIFY_FAIL: policy $POLICY_ID not applied to contract $TARGET_CONTRACT_ADDRESS" >&2
  exit 1
fi

if [[ "$POLICY_CLOSED" != "false" ]]; then
  echo "VERIFY_FAIL: expected policy $POLICY_ID open, got closed=$POLICY_CLOSED" >&2
  exit 1
fi

if [[ "$POLICY_DISABLED" != "false" ]]; then
  echo "VERIFY_FAIL: expected policy $POLICY_ID enabled, got disabled=$POLICY_DISABLED" >&2
  exit 1
fi

jq -n \
  --arg chainName "$CHAIN_NAME" \
  --argjson chainId "$CHAIN_ID_ACTUAL" \
  --arg rulesEngineAddress "$RULES_ENGINE_ADDRESS" \
  --arg marketplaceNft "$MARKETPLACE_NFT_ADDRESS" \
  --arg treasury "$NFT_TREASURY" \
  --arg blacklistOracle "$NFT_ORACLE" \
  --arg operatorRegistry "$NFT_OPERATOR_REGISTRY" \
  --arg targetContractAddress "$TARGET_CONTRACT_ADDRESS" \
  --argjson policyId "$POLICY_ID" \
  --arg appliedPolicies "$APPLIED_POLICIES" \
  --arg policyClosed "$POLICY_CLOSED" \
  --arg policyDisabled "$POLICY_DISABLED" \
  --arg policyMetadata "$POLICY_METADATA" \
  --arg policyPath "$POLICY_PATH" \
  '{
    network: {
      chainName: $chainName,
      chainId: $chainId
    },
    wiring: {
      rulesEngineAddress: $rulesEngineAddress,
      marketplaceNft: $marketplaceNft,
      treasury: $treasury,
      blacklistOracle: $blacklistOracle,
      operatorRegistry: $operatorRegistry,
      targetContractAddress: $targetContractAddress
    },
    policy: {
      policyId: $policyId,
      policyPath: $policyPath,
      appliedPoliciesRaw: $appliedPolicies,
      closed: $policyClosed,
      disabled: $policyDisabled,
      metadataRaw: $policyMetadata
    }
  }' > "$VERIFY_SUMMARY_PATH"

echo "TESTNET_MARKETPLACE_VERIFY_OK"
echo "CHAIN_ID=$CHAIN_ID_ACTUAL"
echo "RULES_ENGINE_ADDRESS=$RULES_ENGINE_ADDRESS"
echo "MARKETPLACE_NFT_ADDRESS=$MARKETPLACE_NFT_ADDRESS"
echo "POLICY_ID=$POLICY_ID"
echo "VERIFY_SUMMARY_PATH=$VERIFY_SUMMARY_PATH"
