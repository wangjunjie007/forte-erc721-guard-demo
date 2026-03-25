#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$ROOT_DIR/cache"
REPORTS_DIR="$ROOT_DIR/reports"
OUTPUT_JSON="${OUTPUT_JSON:-$REPORTS_DIR/reviewer-pack.json}"
OUTPUT_MD="${OUTPUT_MD:-$REPORTS_DIR/reviewer-pack.md}"
SUMMARY_PATH="${SUMMARY_PATH:-}"
VERIFY_SUMMARY_PATH="${VERIFY_SUMMARY_PATH:-$CACHE_DIR/testnet-marketplace-verify-summary.json}"
LOCAL_SUMMARY_PATH="$CACHE_DIR/marketplace-integration-summary.json"
TESTNET_SUMMARY_PATH="$CACHE_DIR/testnet-marketplace-deployment-summary.json"
EMPTY_JSON_PATH="$CACHE_DIR/.empty-reviewer-pack.json"

mkdir -p "$REPORTS_DIR" "$CACHE_DIR"
printf '{}' > "$EMPTY_JSON_PATH"

relpath() {
  python3 - "$1" "$2" <<'PY'
import os, sys
print(os.path.relpath(sys.argv[1], sys.argv[2]))
PY
}

if [[ -z "$SUMMARY_PATH" ]]; then
  if [[ -f "$TESTNET_SUMMARY_PATH" ]]; then
    SUMMARY_PATH="$TESTNET_SUMMARY_PATH"
  elif [[ -f "$LOCAL_SUMMARY_PATH" ]]; then
    SUMMARY_PATH="$LOCAL_SUMMARY_PATH"
  else
    echo "No reviewer-pack source summary found. Expected one of:" >&2
    echo "  - $TESTNET_SUMMARY_PATH" >&2
    echo "  - $LOCAL_SUMMARY_PATH" >&2
    exit 1
  fi
fi

if [[ ! -f "$SUMMARY_PATH" ]]; then
  echo "Summary file not found: $SUMMARY_PATH" >&2
  exit 1
fi

SOURCE_KIND="local"
if [[ "$SUMMARY_PATH" == *"testnet-marketplace-deployment-summary.json" ]]; then
  SOURCE_KIND="testnet"
fi

VERIFY_SOURCE="$EMPTY_JSON_PATH"
if [[ -f "$VERIFY_SUMMARY_PATH" ]]; then
  VERIFY_SOURCE="$VERIFY_SUMMARY_PATH"
fi

jq -n \
  --arg sourceKind "$SOURCE_KIND" \
  --arg summaryPath "$SUMMARY_PATH" \
  --arg verifySummaryPath "$VERIFY_SUMMARY_PATH" \
  --slurpfile summary "$SUMMARY_PATH" \
  --slurpfile verify "$VERIFY_SOURCE" \
  '
  def firstOrEmpty(arr): if (arr|length) > 0 then arr[0] else {} end;
  def src: firstOrEmpty($summary);
  def vrf: firstOrEmpty($verify);
  def isTestnet: $sourceKind == "testnet";
  {
    sourceKind: $sourceKind,
    sourceSummaryPath: $summaryPath,
    verifySummaryPath: (if (vrf == {}) then null else $verifySummaryPath end),
    network: src.network,
    rulesEngine: {
      diamondAddress: (src.rulesEngine.diamondAddress // src.rulesEngineAddress // null)
    },
    contracts: (if isTestnet then {
      blacklistOracle: src.contracts.blacklistOracle,
      operatorRegistry: src.contracts.operatorRegistry,
      marketplaceNft: src.contracts.marketplaceNft
    } else {
      blacklistOracle: src.demoContracts.blacklistOracle,
      operatorRegistry: src.demoContracts.operatorRegistry,
      marketplaceNft: src.demoContracts.marketplaceNft
    } end),
    actors: src.actors,
    policy: {
      appliedPolicyId: (src.policy.appliedPolicyId // null),
      policyType: (src.policy.policyType // null),
      policyPath: (src.policy.path // null),
      applyResult: (src.policy.applyResult // null),
      verify: (if vrf == {} then null else vrf.policy end)
    },
    validation: (if isTestnet then {
      wiringVerified: (vrf != {}),
      verifySummary: (if vrf == {} then null else vrf end)
    } else src.validation end),
    txHashes: (if isTestnet then (src.txHashes // null) else null end)
  }' > "$OUTPUT_JSON"

NETWORK_NAME="$(jq -r '.network.name // .network.chainName // "unknown"' "$OUTPUT_JSON")"
CHAIN_ID="$(jq -r '.network.chainId // "unknown"' "$OUTPUT_JSON")"
RULES_ENGINE_ADDRESS="$(jq -r '.rulesEngine.diamondAddress // "n/a"' "$OUTPUT_JSON")"
BLACKLIST_ORACLE="$(jq -r '.contracts.blacklistOracle // "n/a"' "$OUTPUT_JSON")"
OPERATOR_REGISTRY="$(jq -r '.contracts.operatorRegistry // "n/a"' "$OUTPUT_JSON")"
MARKETPLACE_NFT="$(jq -r '.contracts.marketplaceNft // "n/a"' "$OUTPUT_JSON")"
POLICY_ID="$(jq -r '.policy.appliedPolicyId // "n/a"' "$OUTPUT_JSON")"
POLICY_PATH_VALUE="$(jq -r '.policy.policyPath // "n/a"' "$OUTPUT_JSON")"
TREASURY_ADDRESS="$(jq -r '.actors.treasury // "n/a"' "$OUTPUT_JSON")"
SOURCE_KIND_VALUE="$(jq -r '.sourceKind' "$OUTPUT_JSON")"
VERIFY_PRESENT="$(jq -r 'if .validation.verifySummary? then "yes" else "no" end' "$OUTPUT_JSON")"
JSON_REL="$(relpath "$OUTPUT_JSON" "$ROOT_DIR")"
MD_REL="$(relpath "$OUTPUT_MD" "$ROOT_DIR")"
SUMMARY_REL="$(relpath "$SUMMARY_PATH" "$ROOT_DIR")"
VERIFY_REL="$(relpath "$VERIFY_SUMMARY_PATH" "$ROOT_DIR")"

cat > "$OUTPUT_MD" <<EOF
# Reviewer Pack

## Overview

- Source kind: **$SOURCE_KIND_VALUE**
- Network: **$NETWORK_NAME**
- Chain ID: **$CHAIN_ID**
- Rules Engine diamond: \`$RULES_ENGINE_ADDRESS\`
- Marketplace NFT: \`$MARKETPLACE_NFT\`
- Policy ID: \`$POLICY_ID\`
- Policy path: \`$POLICY_PATH_VALUE\`

## Contract Addresses

- BlacklistOracle: \`$BLACKLIST_ORACLE\`
- OperatorRegistry: \`$OPERATOR_REGISTRY\`
- ForteMarketplaceGuardedNFT: \`$MARKETPLACE_NFT\`
- Treasury: \`$TREASURY_ADDRESS\`

## Validation Snapshot
EOF

if [[ "$SOURCE_KIND_VALUE" == "local" ]]; then
  jq -r '.validation | to_entries[] | "- \(.key): \(.value)"' "$OUTPUT_JSON" >> "$OUTPUT_MD"
else
  echo "- wiring verified: $VERIFY_PRESENT" >> "$OUTPUT_MD"
  if [[ "$VERIFY_PRESENT" == "yes" ]]; then
    echo "- verify summary: \`$VERIFY_REL\`" >> "$OUTPUT_MD"
  fi
fi

cat >> "$OUTPUT_MD" <<EOF

## Artifacts

- JSON pack: \`$JSON_REL\`
- Markdown pack: \`$MD_REL\`
- Source summary: \`$SUMMARY_REL\`
EOF

if [[ "$VERIFY_PRESENT" == "yes" ]]; then
  echo "- Verify summary: \`$VERIFY_REL\`" >> "$OUTPUT_MD"
fi

echo "REVIEWER_PACK_OK"
echo "OUTPUT_JSON=$OUTPUT_JSON"
echo "OUTPUT_MD=$OUTPUT_MD"
