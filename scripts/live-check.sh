#!/usr/bin/env bash
set -euo pipefail

if [[ -f "$HOME/.zshenv" ]]; then
  source "$HOME/.zshenv"
fi
source ./.env

RPC="$RPC_URL"
NFT="$NFT_ADDRESS"
ORACLE="$BLACKLIST_ORACLE_ADDRESS"
OWNER_KEY="$PRIV_KEY"
OWNER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ALICE="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
ALICE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
BOB="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

ok(){ echo "[PASS] $1"; }
fail(){ echo "[FAIL] $1"; exit 1; }
expect_revert(){
  local name="$1"; shift
  set +e
  "$@" >/tmp/forte_nft_cmd_out.txt 2>/tmp/forte_nft_cmd_err.txt
  local code=$?
  set -e
  if [ $code -eq 0 ]; then
    echo "---- stdout ----"; cat /tmp/forte_nft_cmd_out.txt || true
    echo "---- stderr ----"; cat /tmp/forte_nft_cmd_err.txt || true
    fail "$name (expected revert but succeeded)"
  else
    ok "$name"
  fi
}

OWNER_TOKEN_ID=$(cast call "$NFT" "nextTokenId()(uint256)" --rpc-url "$RPC")
cast send "$NFT" "mint(address)(uint256)" "$OWNER" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner minted token $OWNER_TOKEN_ID to treasury"

ALICE_TOKEN_ID=$(cast call "$NFT" "nextTokenId()(uint256)" --rpc-url "$RPC")
cast send "$NFT" "mint(address)(uint256)" "$ALICE" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner minted token $ALICE_TOKEN_ID to alice"

expect_revert "alice cannot transfer while paused" cast send "$NFT" "setTransfersPaused(bool)" true --rpc-url "$RPC" --private-key "$ALICE_KEY"

cast send "$NFT" "setTransfersPaused(bool)" true --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner set transfersPaused=true"
expect_revert "pause blocks alice transfer" cast send "$NFT" "transferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$ALICE_KEY"

cast send "$NFT" "transferFrom(address,address,uint256)" "$OWNER" "$BOB" "$OWNER_TOKEN_ID" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "treasury bypass transfer while paused"

cast send "$NFT" "setTransfersPaused(bool)" false --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "owner set transfersPaused=false"

cast send "$ORACLE" "setBlacklisted(address,bool)" "$BOB" true --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "set bob blacklisted=true"
expect_revert "blacklist blocks alice transfer" cast send "$NFT" "transferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$ALICE_KEY"

cast send "$ORACLE" "setBlacklisted(address,bool)" "$BOB" false --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "set bob blacklisted=false"

NOW=$(cast block latest --rpc-url "$RPC" | awk '/timestamp/{print $2}')
UNLOCK=$((NOW+3600))
cast send "$NFT" "setTokenUnlockTime(uint256,uint256)" "$ALICE_TOKEN_ID" "$UNLOCK" --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "set token $ALICE_TOKEN_ID unlock future"
expect_revert "lockup blocks alice transfer" cast send "$NFT" "transferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$ALICE_KEY"

cast send "$NFT" "setTokenUnlockTime(uint256,uint256)" "$ALICE_TOKEN_ID" 0 --rpc-url "$RPC" --private-key "$OWNER_KEY" >/dev/null
ok "unlock token $ALICE_TOKEN_ID"
cast send "$NFT" "safeTransferFrom(address,address,uint256)" "$ALICE" "$BOB" "$ALICE_TOKEN_ID" --rpc-url "$RPC" --private-key "$ALICE_KEY" >/dev/null
ok "alice safeTransferFrom token $ALICE_TOKEN_ID after unlock"

OWNER_OF_OWNER_TOKEN=$(cast call "$NFT" "ownerOf(uint256)(address)" "$OWNER_TOKEN_ID" --rpc-url "$RPC")
OWNER_OF_ALICE_TOKEN=$(cast call "$NFT" "ownerOf(uint256)(address)" "$ALICE_TOKEN_ID" --rpc-url "$RPC")
echo "owner_of_owner_token($OWNER_TOKEN_ID)=$OWNER_OF_OWNER_TOKEN"
echo "owner_of_alice_token($ALICE_TOKEN_ID)=$OWNER_OF_ALICE_TOKEN"
