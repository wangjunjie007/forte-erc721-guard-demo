#!/usr/bin/env bash
set -euo pipefail

if [[ -f "$HOME/.zshenv" ]]; then
  source "$HOME/.zshenv"
fi

export NO_PROXY="${NO_PROXY:+$NO_PROXY,}127.0.0.1,localhost"
export no_proxy="${no_proxy:+$no_proxy,}127.0.0.1,localhost"

source ./.env

RPC="$RPC_URL"
MARKETPLACE_NFT_ADDR="${MARKETPLACE_NFT_ADDRESS:?MARKETPLACE_NFT_ADDRESS is required}"
REGISTRY="${OPERATOR_REGISTRY_ADDRESS:?OPERATOR_REGISTRY_ADDRESS is required}"
ORACLE="$BLACKLIST_ORACLE_ADDRESS"
OWNER_KEY="$PRIV_KEY"
OWNER="${TREASURY_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
ALICE="${ALICE_ADDRESS:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}"
ALICE_KEY="${ALICE_PRIVATE_KEY:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"
BOB="${BOB_ADDRESS:-0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC}"
OPERATOR="${OPERATOR_ADDRESS:-0x90F79bf6EB2c4f870365E785982E1f101E93b906}"
OPERATOR_KEY="${OPERATOR_PRIVATE_KEY:-0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6}"

ok(){ echo "[PASS] $1"; }
fail(){ echo "[FAIL] $1"; exit 1; }
expect_revert(){
  local name="$1"; shift
  set +e
  "$@" >/tmp/forte_market_cmd_out.txt 2>/tmp/forte_market_cmd_err.txt
  local code=$?
  set -e
  if [ $code -eq 0 ]; then
    echo "---- stdout ----"; cat /tmp/forte_market_cmd_out.txt || true
    echo "---- stderr ----"; cat /tmp/forte_market_cmd_err.txt || true
    fail "$name (expected revert but succeeded)"
  else
    ok "$name"
  fi
}

OWNER_TOKEN_ID=$(cast call "$MARKETPLACE_NFT_ADDR" "nextTokenId()(uint256)" --rpc-url "$RPC")
cast send "$MARKETPLACE_NFT_ADDR" "mint(address)(uint256)" "$OWNER" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner minted token $OWNER_TOKEN_ID to treasury"

ALICE_TOKEN_ID=$(cast call "$MARKETPLACE_NFT_ADDR" "nextTokenId()(uint256)" --rpc-url "$RPC")
cast send "$MARKETPLACE_NFT_ADDR" "mint(address)(uint256)" "$ALICE" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner minted token $ALICE_TOKEN_ID to alice"

SAFE_TOKEN_ID=$(cast call "$MARKETPLACE_NFT_ADDR" "nextTokenId()(uint256)" --rpc-url "$RPC")
cast send "$MARKETPLACE_NFT_ADDR" "mint(address)(uint256)" "$ALICE" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner minted token $SAFE_TOKEN_ID to alice for safe transfer flow"

cast send "$MARKETPLACE_NFT_ADDR" "approve(address,uint256)" "$OPERATOR" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$ALICE_KEY" >/dev/null
ok "alice approved operator for token $ALICE_TOKEN_ID"
expect_revert "unapproved operator transfer reverts" cast send "$MARKETPLACE_NFT_ADDR" "transferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$OPERATOR_KEY"

cast send "$REGISTRY" "setAllowedOperator(address,bool)" "$OPERATOR" true --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner allowed marketplace operator"

cast send "$ORACLE" "setBlacklisted(address,bool)" "$BOB" true --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner blacklisted bob"
expect_revert "blacklist blocks approved operator" cast send "$MARKETPLACE_NFT_ADDR" "transferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$OPERATOR_KEY"
cast send "$ORACLE" "setBlacklisted(address,bool)" "$BOB" false --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner unblacklisted bob"

cast send "$MARKETPLACE_NFT_ADDR" "setTransfersPaused(bool)" true --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner set transfersPaused=true"
expect_revert "pause blocks approved operator" cast send "$MARKETPLACE_NFT_ADDR" "transferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$OPERATOR_KEY"
cast send "$MARKETPLACE_NFT_ADDR" "transferFrom(address,address,uint256)" "$OWNER" "$BOB" "$OWNER_TOKEN_ID" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "treasury bypass transfer while paused"
cast send "$MARKETPLACE_NFT_ADDR" "setTransfersPaused(bool)" false --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner set transfersPaused=false"

cast send "$MARKETPLACE_NFT_ADDR" "transferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$OPERATOR_KEY" >/dev/null
ok "approved operator transfer succeeded"

cast send "$MARKETPLACE_NFT_ADDR" "approve(address,uint256)" "$OPERATOR" "$SAFE_TOKEN_ID" --rpc-url "$RPC" --private-key "$ALICE_KEY" >/dev/null
ok "alice approved operator for token $SAFE_TOKEN_ID"
cast send "$MARKETPLACE_NFT_ADDR" 'safeTransferFrom(address,address,uint256,bytes)' "$ALICE" "$BOB" "$SAFE_TOKEN_ID" 0x6d61726b6574706c616365 --rpc-url "$RPC" --private-key "$OPERATOR_KEY" >/dev/null
ok "approved operator safeTransferFrom succeeded"

OWNER_OF_OWNER_TOKEN=$(cast call "$MARKETPLACE_NFT_ADDR" "ownerOf(uint256)(address)" "$OWNER_TOKEN_ID" --rpc-url "$RPC")
OWNER_OF_ALICE_TOKEN=$(cast call "$MARKETPLACE_NFT_ADDR" "ownerOf(uint256)(address)" "$ALICE_TOKEN_ID" --rpc-url "$RPC")
OWNER_OF_SAFE_TOKEN=$(cast call "$MARKETPLACE_NFT_ADDR" "ownerOf(uint256)(address)" "$SAFE_TOKEN_ID" --rpc-url "$RPC")

echo "owner_of_owner_token($OWNER_TOKEN_ID)=$OWNER_OF_OWNER_TOKEN"
echo "owner_of_alice_token($ALICE_TOKEN_ID)=$OWNER_OF_ALICE_TOKEN"
echo "owner_of_safe_token($SAFE_TOKEN_ID)=$OWNER_OF_SAFE_TOKEN"
