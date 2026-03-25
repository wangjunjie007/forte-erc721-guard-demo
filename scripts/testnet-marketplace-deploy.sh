#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$ROOT_DIR/cache"
SUMMARY_PATH="${SUMMARY_PATH:-$CACHE_DIR/testnet-marketplace-deployment-summary.json}"
ENV_SNAPSHOT_PATH="${ENV_SNAPSHOT_PATH:-$CACHE_DIR/testnet-marketplace.env}"
DEFAULT_ENV_FILE="$ROOT_DIR/.env.testnet.marketplace"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"
POLICY_PATH_DEFAULT="$ROOT_DIR/examples/policies/marketplace-operator-gate-nft.policy.json"

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

tx_hash_from_json() {
  jq -r '.transactionHash // .txHash // .hash // empty'
}

require_cmd forge
require_cmd cast
require_cmd npx
require_cmd jq

TESTNET_RPC_URL="${TESTNET_RPC_URL:-${RPC_URL:-}}"
TESTNET_PRIVATE_KEY="${TESTNET_PRIVATE_KEY:-${PRIV_KEY:-}}"
RULES_ENGINE_ADDRESS="${RULES_ENGINE_ADDRESS:-}"
CHAIN_NAME="${CHAIN_NAME:-${TESTNET_CHAIN_NAME:-base-sepolia}}"
POLICY_PATH="${POLICY_PATH:-$POLICY_PATH_DEFAULT}"
LOCAL_CONFIRMATION_COUNT="${LOCAL_CONFIRMATION_COUNT:-${TESTNET_CONFIRMATIONS:-2}}"

require_env TESTNET_RPC_URL
require_env TESTNET_PRIVATE_KEY
require_env RULES_ENGINE_ADDRESS

if [[ ! -f "$POLICY_PATH" ]]; then
  echo "Policy file not found: $POLICY_PATH" >&2
  exit 1
fi

CHAIN_ID="$(cast chain-id --rpc-url "$TESTNET_RPC_URL")"
DEPLOYER_ADDRESS="$(cast wallet address --private-key "$TESTNET_PRIVATE_KEY")"
TREASURY_ADDRESS="${TREASURY_ADDRESS:-$DEPLOYER_ADDRESS}"
CALLING_CONTRACT_ADMIN="${CALLING_CONTRACT_ADMIN:-$TREASURY_ADDRESS}"

case "$(echo "$CHAIN_NAME" | tr '[:upper:]' '[:lower:]')" in
  base-sepolia|basesepolia|base_sepolia) NETWORK_NAME="Base Sepolia" ;;
  sepolia) NETWORK_NAME="Sepolia" ;;
  base) NETWORK_NAME="Base" ;;
  mainnet|ethereum) NETWORK_NAME="Ethereum Mainnet" ;;
  *) NETWORK_NAME="$CHAIN_NAME" ;;
esac

cd "$ROOT_DIR"

PRIV_KEY="$TESTNET_PRIVATE_KEY" \
  forge script script/DeployMarketplaceDemo.s.sol --broadcast --slow --rpc-url "$TESTNET_RPC_URL" --private-key "$TESTNET_PRIVATE_KEY" -vv \
  >/tmp/forte_testnet_marketplace_deploy.log 2>&1 || {
    cat /tmp/forte_testnet_marketplace_deploy.log >&2
    exit 1
  }

RUN_JSON="$ROOT_DIR/broadcast/DeployMarketplaceDemo.s.sol/$CHAIN_ID/run-latest.json"
if [[ ! -f "$RUN_JSON" ]]; then
  echo "Deployment run JSON not found: $RUN_JSON" >&2
  exit 1
fi

BLACKLIST_ORACLE_ADDRESS="$(jq -r '.transactions[] | select(.contractName=="BlacklistOracle") | .contractAddress' "$RUN_JSON" | tail -n1)"
OPERATOR_REGISTRY_ADDRESS="$(jq -r '.transactions[] | select(.contractName=="OperatorRegistry") | .contractAddress' "$RUN_JSON" | tail -n1)"
MARKETPLACE_NFT_ADDRESS="$(jq -r '.transactions[] | select(.contractName=="ForteMarketplaceGuardedNFT") | .contractAddress' "$RUN_JSON" | tail -n1)"

if [[ -z "$BLACKLIST_ORACLE_ADDRESS" || -z "$OPERATOR_REGISTRY_ADDRESS" || -z "$MARKETPLACE_NFT_ADDRESS" || "$MARKETPLACE_NFT_ADDRESS" == "null" ]]; then
  echo "Failed to parse deployed marketplace contract addresses" >&2
  cat /tmp/forte_testnet_marketplace_deploy.log >&2
  exit 1
fi

SET_RULES_JSON="$(cast send "$MARKETPLACE_NFT_ADDRESS" "setRulesEngineAddress(address)" "$RULES_ENGINE_ADDRESS" --rpc-url "$TESTNET_RPC_URL" --private-key "$TESTNET_PRIVATE_KEY" --json)"
SET_ADMIN_JSON="$(cast send "$MARKETPLACE_NFT_ADDRESS" "setCallingContractAdmin(address)" "$CALLING_CONTRACT_ADMIN" --rpc-url "$TESTNET_RPC_URL" --private-key "$TESTNET_PRIVATE_KEY" --json)"
SET_TREASURY_JSON='{}'
if [[ "$TREASURY_ADDRESS" != "$DEPLOYER_ADDRESS" ]]; then
  SET_TREASURY_JSON="$(cast send "$MARKETPLACE_NFT_ADDRESS" "setTreasury(address)" "$TREASURY_ADDRESS" --rpc-url "$TESTNET_RPC_URL" --private-key "$TESTNET_PRIVATE_KEY" --json)"
fi

RPC_URL="$TESTNET_RPC_URL" \
PRIV_KEY="$TESTNET_PRIVATE_KEY" \
RULES_ENGINE_ADDRESS="$RULES_ENGINE_ADDRESS" \
TARGET_CONTRACT_ADDRESS="$MARKETPLACE_NFT_ADDRESS" \
POLICY_PATH="$POLICY_PATH" \
CHAIN_NAME="$CHAIN_NAME" \
CHAIN_ID="$CHAIN_ID" \
LOCAL_CONFIRMATION_COUNT="$LOCAL_CONFIRMATION_COUNT" \
  npx tsx scripts/apply-policy.ts >/tmp/forte_testnet_marketplace_apply_policy.log 2>&1 || {
    cat /tmp/forte_testnet_marketplace_apply_policy.log >&2
    exit 1
  }

POLICY_ID="$(jq -r '.policyId' "$ROOT_DIR/cache/apply-policy-result.json")"
if [[ -z "$POLICY_ID" || "$POLICY_ID" == "null" ]]; then
  echo "Failed to parse policy id" >&2
  cat /tmp/forte_testnet_marketplace_apply_policy.log >&2
  exit 1
fi

cat > "$ENV_SNAPSHOT_PATH" <<EOF
CHAIN_NAME=$CHAIN_NAME
CHAIN_ID=$CHAIN_ID
TESTNET_RPC_URL=$TESTNET_RPC_URL
RULES_ENGINE_ADDRESS=$RULES_ENGINE_ADDRESS
BLACKLIST_ORACLE_ADDRESS=$BLACKLIST_ORACLE_ADDRESS
OPERATOR_REGISTRY_ADDRESS=$OPERATOR_REGISTRY_ADDRESS
MARKETPLACE_NFT_ADDRESS=$MARKETPLACE_NFT_ADDRESS
TREASURY_ADDRESS=$TREASURY_ADDRESS
CALLING_CONTRACT_ADMIN=$CALLING_CONTRACT_ADMIN
POLICY_ID=$POLICY_ID
POLICY_PATH=$POLICY_PATH
TARGET_CONTRACT_ADDRESS=$MARKETPLACE_NFT_ADDRESS
EOF

TESTNET_RPC_URL="$TESTNET_RPC_URL" \
RULES_ENGINE_ADDRESS="$RULES_ENGINE_ADDRESS" \
BLACKLIST_ORACLE_ADDRESS="$BLACKLIST_ORACLE_ADDRESS" \
OPERATOR_REGISTRY_ADDRESS="$OPERATOR_REGISTRY_ADDRESS" \
MARKETPLACE_NFT_ADDRESS="$MARKETPLACE_NFT_ADDRESS" \
TREASURY_ADDRESS="$TREASURY_ADDRESS" \
POLICY_ID="$POLICY_ID" \
POLICY_PATH="$POLICY_PATH" \
TARGET_CONTRACT_ADDRESS="$MARKETPLACE_NFT_ADDRESS" \
CHAIN_NAME="$CHAIN_NAME" \
CHAIN_ID="$CHAIN_ID" \
  bash "$ROOT_DIR/scripts/testnet-marketplace-verify.sh" >/tmp/forte_testnet_marketplace_verify.log 2>&1 || {
    cat /tmp/forte_testnet_marketplace_verify.log >&2
    exit 1
  }

jq -n \
  --arg networkName "$NETWORK_NAME" \
  --arg chainName "$CHAIN_NAME" \
  --argjson chainId "$CHAIN_ID" \
  --arg rulesEngineAddress "$RULES_ENGINE_ADDRESS" \
  --arg deployerAddress "$DEPLOYER_ADDRESS" \
  --arg treasuryAddress "$TREASURY_ADDRESS" \
  --arg callingContractAdmin "$CALLING_CONTRACT_ADMIN" \
  --arg blacklistOracle "$BLACKLIST_ORACLE_ADDRESS" \
  --arg operatorRegistry "$OPERATOR_REGISTRY_ADDRESS" \
  --arg marketplaceNft "$MARKETPLACE_NFT_ADDRESS" \
  --arg policyPath "$POLICY_PATH" \
  --argjson policyId "$POLICY_ID" \
  --arg setRulesTxHash "$(printf '%s' "$SET_RULES_JSON" | tx_hash_from_json)" \
  --arg setAdminTxHash "$(printf '%s' "$SET_ADMIN_JSON" | tx_hash_from_json)" \
  --arg setTreasuryTxHash "$(printf '%s' "$SET_TREASURY_JSON" | tx_hash_from_json)" \
  --slurpfile applyResult "$ROOT_DIR/cache/apply-policy-result.json" \
  'def clean(v): if (v == null or v == "") then empty else v end;
   {
     network: {
       name: $networkName,
       chainName: $chainName,
       chainId: $chainId
     },
     rulesEngine: {
       diamondAddress: $rulesEngineAddress
     },
     actors: {
       deployer: $deployerAddress,
       treasury: $treasuryAddress,
       callingContractAdmin: $callingContractAdmin
     },
     contracts: {
       blacklistOracle: $blacklistOracle,
       operatorRegistry: $operatorRegistry,
       marketplaceNft: $marketplaceNft
     },
     policy: {
       path: $policyPath,
       appliedPolicyId: $policyId,
       applyResult: ($applyResult[0] // {})
     },
     txHashes: {
       deployment: [inputs.transactions[] | {contractName, contractAddress, txHash}],
       configuration: {
         setRulesEngineAddress: clean($setRulesTxHash),
         setCallingContractAdmin: clean($setAdminTxHash),
         setTreasury: clean($setTreasuryTxHash)
       }
     },
     artifacts: {
       envSnapshot: "cache/testnet-marketplace.env",
       verifyLog: "/tmp/forte_testnet_marketplace_verify.log"
     }
   }' "$RUN_JSON" > "$SUMMARY_PATH"

echo "TESTNET_MARKETPLACE_DEPLOY_OK"
echo "CHAIN_ID=$CHAIN_ID"
echo "RULES_ENGINE_ADDRESS=$RULES_ENGINE_ADDRESS"
echo "BLACKLIST_ORACLE_ADDRESS=$BLACKLIST_ORACLE_ADDRESS"
echo "OPERATOR_REGISTRY_ADDRESS=$OPERATOR_REGISTRY_ADDRESS"
echo "MARKETPLACE_NFT_ADDRESS=$MARKETPLACE_NFT_ADDRESS"
echo "POLICY_ID=$POLICY_ID"
echo "SUMMARY_PATH=$SUMMARY_PATH"
