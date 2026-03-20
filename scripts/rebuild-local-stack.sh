#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$ROOT_DIR/tmp/forte-rules-engine-upstream"
LOG_DIR="$ROOT_DIR/logs"
CACHE_DIR="$ROOT_DIR/cache"
ANVIL_LOG="$LOG_DIR/anvil.log"
ANVIL_PID_FILE="$CACHE_DIR/anvil.pid"
RPC_URL="http://127.0.0.1:8545"
OWNER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
OWNER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

mkdir -p "$LOG_DIR" "$CACHE_DIR"

if [[ -f "$HOME/.zshenv" ]]; then
  source "$HOME/.zshenv"
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

require_cmd forge
require_cmd cast
require_cmd anvil
require_cmd npx
require_cmd jq

cd "$ROOT_DIR"

start_fresh_anvil() {
  for attempt in 1 2 3; do
    if [[ -f "$ANVIL_PID_FILE" ]]; then
      OLD_PID="$(cat "$ANVIL_PID_FILE" 2>/dev/null || true)"
      if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$OLD_PID" 2>/dev/null || true
      fi
      rm -f "$ANVIL_PID_FILE"
    fi

    if command -v lsof >/dev/null 2>&1; then
      mapfile -t PORT_PIDS < <(lsof -ti tcp:8545 || true)
      if [[ ${#PORT_PIDS[@]} -gt 0 ]]; then
        for pid in "${PORT_PIDS[@]}"; do
          kill "$pid" 2>/dev/null || true
        done
        sleep 1
        for pid in "${PORT_PIDS[@]}"; do
          kill -9 "$pid" 2>/dev/null || true
        done
      fi
    fi

    nohup anvil --host 127.0.0.1 --port 8545 >"$ANVIL_LOG" 2>&1 &
    NEW_PID=$!
    echo "$NEW_PID" > "$ANVIL_PID_FILE"

    for _ in $(seq 1 30); do
      if cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    BLOCK_NUMBER="$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null || echo "-1")"
    if [[ "$BLOCK_NUMBER" == "0" ]]; then
      return 0
    fi

    echo "anvil freshness check failed on attempt $attempt (block=$BLOCK_NUMBER), restarting..." >&2
    kill "$NEW_PID" 2>/dev/null || true
    sleep 1
    kill -9 "$NEW_PID" 2>/dev/null || true
  done

  echo "anvil failed to start as a fresh chain" >&2
  tail -n 80 "$ANVIL_LOG" >&2 || true
  exit 1
}

ensure_upstream_ready() {
  if [[ ! -d "$UPSTREAM_DIR" ]]; then
    git clone https://github.com/Forte-Service-Company-Ltd/forte-rules-engine.git "$UPSTREAM_DIR"
  fi

  cd "$UPSTREAM_DIR"
  if [[ ! -d node_modules ]]; then
    npm install
  fi
  forge soldeer install >/dev/null
  cd "$ROOT_DIR"
}

deploy_rules_engine() {
  cd "$UPSTREAM_DIR"

  ETH_RPC_URL="$(grep '^ETH_RPC_URL=' .env | cut -d '=' -f2 | tr -d '[:space:]')"
  GAS_NUMBER="$(grep '^GAS_NUMBER=' .env | cut -d '=' -f2 | tr -d '[:space:]')"

  forge script script/deployment/DeployRulesDiamond.s.sol \
    --ffi --broadcast --slow -vvv --non-interactive \
    --rpc-url="${ETH_RPC_URL}" --gas-price="${GAS_NUMBER}" --legacy \
    >/tmp/forte_rules_engine_deploy_nft.log 2>&1 || {
      cat /tmp/forte_rules_engine_deploy_nft.log >&2
      exit 1
    }

  DIAMOND_ADDRESS="$(grep '^DIAMOND_ADDRESS=' .env | cut -d '=' -f2 | tr -d '[:space:]')"
  cd "$ROOT_DIR"
  if [[ -z "$DIAMOND_ADDRESS" || "$DIAMOND_ADDRESS" == "0x0000000000000000000000000000000000000000" ]]; then
    echo "Failed to get DIAMOND_ADDRESS" >&2
    exit 1
  fi
}

deploy_demo() {
  PRIV_KEY="$OWNER_KEY" \
    forge script script/DeployDemo.s.sol --broadcast --slow --rpc-url "$RPC_URL" --private-key "$OWNER_KEY" -vv >/tmp/forte_nft_demo_deploy.log 2>&1 || {
      cat /tmp/forte_nft_demo_deploy.log >&2
      exit 1
    }

  local run_json="$ROOT_DIR/broadcast/DeployDemo.s.sol/31337/run-latest.json"
  BLACKLIST_ORACLE_ADDRESS="$(jq -r '.transactions[] | select(.contractName=="BlacklistOracle") | .contractAddress' "$run_json" | tail -n1)"
  NFT_ADDRESS="$(jq -r '.transactions[] | select(.contractName=="ForteGuardedNFT") | .contractAddress' "$run_json" | tail -n1)"

  if [[ -z "$BLACKLIST_ORACLE_ADDRESS" || -z "$NFT_ADDRESS" || "$NFT_ADDRESS" == "null" ]]; then
    echo "Failed to parse deployed contract addresses" >&2
    cat /tmp/forte_nft_demo_deploy.log >&2
    exit 1
  fi
}

configure_nft() {
  cast send "$NFT_ADDRESS" "setRulesEngineAddress(address)" "$DIAMOND_ADDRESS" --rpc-url "$RPC_URL" --private-key "$OWNER_KEY" >/dev/null
  cast send "$NFT_ADDRESS" "setCallingContractAdmin(address)" "$OWNER" --rpc-url "$RPC_URL" --private-key "$OWNER_KEY" >/dev/null
}

create_and_apply_policy() {
  NFT_ADDRESS="$NFT_ADDRESS" \
  RULES_ENGINE_ADDRESS="$DIAMOND_ADDRESS" \
  RPC_URL="$RPC_URL" \
  PRIV_KEY="$OWNER_KEY" \
  SKIP_APPLY=1 \
    npx tsx scripts/apply-policy.ts >/tmp/forte_nft_apply_policy.log 2>&1 || {
      cat /tmp/forte_nft_apply_policy.log >&2
      exit 1
    }

  POLICY_ID="$(jq -r '.policyId' "$ROOT_DIR/cache/apply-policy-result.json")"
  if [[ -z "$POLICY_ID" || "$POLICY_ID" == "null" ]]; then
    echo "Failed to parse policy id" >&2
    cat /tmp/forte_nft_apply_policy.log >&2
    exit 1
  fi

  cast send "$DIAMOND_ADDRESS" "applyPolicy(address,uint256[])" "$NFT_ADDRESS" "[$POLICY_ID]" --rpc-url "$RPC_URL" --private-key "$OWNER_KEY" >/dev/null
}

write_env() {
  cat > "$ROOT_DIR/.env" <<EOF
RPC_URL=$RPC_URL
PRIV_KEY=$OWNER_KEY
RULES_ENGINE_ADDRESS=$DIAMOND_ADDRESS
BLACKLIST_ORACLE_ADDRESS=$BLACKLIST_ORACLE_ADDRESS
NFT_ADDRESS=$NFT_ADDRESS
TREASURY_ADDRESS=$OWNER
POLICY_ID=$POLICY_ID
TRANSFERS_PAUSED=false
EOF
}

run_validation() {
  "$ROOT_DIR/scripts/live-check.sh" >/tmp/forte_nft_live_check.log 2>&1 || {
    cat /tmp/forte_nft_live_check.log >&2
    exit 1
  }
}

write_summary() {
  cat > "$ROOT_DIR/cache/deployment-summary.json" <<EOF
{
  "network": {
    "name": "anvil",
    "chainId": 31337,
    "rpc": "$RPC_URL"
  },
  "rulesEngine": {
    "diamondAddress": "$DIAMOND_ADDRESS"
  },
  "demoContracts": {
    "blacklistOracle": "$BLACKLIST_ORACLE_ADDRESS",
    "nft": "$NFT_ADDRESS"
  },
  "policy": {
    "appliedPolicyId": $POLICY_ID,
    "policyType": "open"
  },
  "validation": {
    "blacklistRule": "pass",
    "lockupRule": "pass",
    "pauseRule": "pass"
  }
}
EOF
}

start_fresh_anvil
ensure_upstream_ready
deploy_rules_engine
deploy_demo
configure_nft
create_and_apply_policy
write_env
run_validation
write_summary

echo "DONE"
echo "DIAMOND_ADDRESS=$DIAMOND_ADDRESS"
echo "BLACKLIST_ORACLE_ADDRESS=$BLACKLIST_ORACLE_ADDRESS"
echo "NFT_ADDRESS=$NFT_ADDRESS"
echo "POLICY_ID=$POLICY_ID"
