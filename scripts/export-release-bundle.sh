#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$ROOT_DIR/reports"
CACHE_DIR="$ROOT_DIR/cache"
BUNDLE_DIR="$REPORTS_DIR/release-bundle"
BUNDLE_NAME="${BUNDLE_NAME:-forte-erc721-review-bundle}"
BUNDLE_TGZ="${BUNDLE_TGZ:-$REPORTS_DIR/${BUNDLE_NAME}.tgz}"
REVIEWER_JSON="$REPORTS_DIR/reviewer-pack.json"
REVIEWER_MD="$REPORTS_DIR/reviewer-pack.md"
LOCAL_SUMMARY="$CACHE_DIR/marketplace-integration-summary.json"
TESTNET_DEPLOY_SUMMARY="$CACHE_DIR/testnet-marketplace-deployment-summary.json"
TESTNET_VERIFY_SUMMARY="$CACHE_DIR/testnet-marketplace-verify-summary.json"
MANIFEST_JSON="$BUNDLE_DIR/manifest.json"

mkdir -p "$REPORTS_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/docs" "$BUNDLE_DIR/reports" "$BUNDLE_DIR/cache"

copy_if_exists() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
  fi
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

require_file "$REVIEWER_JSON"
require_file "$REVIEWER_MD"

cp "$REVIEWER_JSON" "$BUNDLE_DIR/reports/reviewer-pack.json"
cp "$REVIEWER_MD" "$BUNDLE_DIR/reports/reviewer-pack.md"
copy_if_exists "$LOCAL_SUMMARY" "$BUNDLE_DIR/cache/marketplace-integration-summary.json"
copy_if_exists "$TESTNET_DEPLOY_SUMMARY" "$BUNDLE_DIR/cache/testnet-marketplace-deployment-summary.json"
copy_if_exists "$TESTNET_VERIFY_SUMMARY" "$BUNDLE_DIR/cache/testnet-marketplace-verify-summary.json"
copy_if_exists "$ROOT_DIR/README.md" "$BUNDLE_DIR/README.md"
copy_if_exists "$ROOT_DIR/docs/MARKETPLACE_EXAMPLE.md" "$BUNDLE_DIR/docs/MARKETPLACE_EXAMPLE.md"
copy_if_exists "$ROOT_DIR/docs/TESTNET_ROUTE.md" "$BUNDLE_DIR/docs/TESTNET_ROUTE.md"
copy_if_exists "$ROOT_DIR/docs/DEMO.md" "$BUNDLE_DIR/docs/DEMO.md"

jq -n \
  --arg bundleName "$BUNDLE_NAME" \
  --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg headCommit "$(git -C "$ROOT_DIR" rev-parse --short HEAD)" \
  --arg reviewerJson "reports/reviewer-pack.json" \
  --arg reviewerMd "reports/reviewer-pack.md" \
  --arg readme "README.md" \
  --arg marketplaceExample "docs/MARKETPLACE_EXAMPLE.md" \
  --arg testnetRoute "docs/TESTNET_ROUTE.md" \
  --arg demoDoc "docs/DEMO.md" \
  --arg localSummaryExists "$(if [[ -f "$LOCAL_SUMMARY" ]]; then echo yes; else echo no; fi)" \
  --arg testnetDeployExists "$(if [[ -f "$TESTNET_DEPLOY_SUMMARY" ]]; then echo yes; else echo no; fi)" \
  --arg testnetVerifyExists "$(if [[ -f "$TESTNET_VERIFY_SUMMARY" ]]; then echo yes; else echo no; fi)" \
  '{
    bundleName: $bundleName,
    createdAt: $createdAt,
    headCommit: $headCommit,
    included: {
      reviewerJson: $reviewerJson,
      reviewerMd: $reviewerMd,
      readme: $readme,
      marketplaceExample: $marketplaceExample,
      testnetRoute: $testnetRoute,
      demoDoc: $demoDoc,
      localMarketplaceSummaryIncluded: ($localSummaryExists == "yes"),
      testnetDeploymentSummaryIncluded: ($testnetDeployExists == "yes"),
      testnetVerifySummaryIncluded: ($testnetVerifyExists == "yes")
    }
  }' > "$MANIFEST_JSON"

rm -f "$BUNDLE_TGZ"
tar -C "$REPORTS_DIR" -czf "$BUNDLE_TGZ" "$(basename "$BUNDLE_DIR")"

echo "RELEASE_BUNDLE_OK"
echo "BUNDLE_DIR=$BUNDLE_DIR"
echo "BUNDLE_TGZ=$BUNDLE_TGZ"
