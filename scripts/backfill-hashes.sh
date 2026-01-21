#!/usr/bin/env bash
# Backfill hashes.json with NAR hashes for all historical versions
#
# Requires: STEAM_USERNAME, STEAM_PASSWORD, STEAM_BETA_PASSWORD
# Run with: nix-shell -p depotdownloader jq --run ./scripts/backfill-hashes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HASHES_FILE="$PROJECT_DIR/hashes.json"
VERSIONS_FILE="$PROJECT_DIR/references/resonite-version-monitor/data/versions.json"

APP_ID="2519830"
DEPOT_ID="2519832"
BRANCH="headless"

if [ -z "${STEAM_USERNAME:-}" ] || [ -z "${STEAM_PASSWORD:-}" ]; then
  echo "Error: STEAM_USERNAME and STEAM_PASSWORD must be set"
  exit 1
fi

# Load existing hashes
if [ -f "$HASHES_FILE" ]; then
  hashes=$(cat "$HASHES_FILE")
else
  hashes="{}"
fi

# Get all headless versions
versions=$(jq -c '.headless[]' "$VERSIONS_FILE")
total=$(jq '.headless | length' "$VERSIONS_FILE")
count=0

echo "Backfilling hashes for $total versions..."
echo ""

while read -r version; do
  count=$((count + 1))
  manifest_id=$(echo "$version" | jq -r '.manifestId')
  game_version=$(echo "$version" | jq -r '.gameVersion')

  # Check if we already have this version (with hash)
  existing=$(echo "$hashes" | jq -r --arg v "$game_version" '.[$v].hash // empty')
  if [ -n "$existing" ]; then
    echo "[$count/$total] $game_version: already have hash, skipping"
    continue
  fi

  echo "[$count/$total] $game_version (manifest: $manifest_id)"

  # Create temp directory
  work_dir=$(mktemp -d)
  trap "rm -rf $work_dir" EXIT

  echo "  Downloading..."
  DepotDownloader \
    -app "$APP_ID" \
    -depot "$DEPOT_ID" \
    -manifest "$manifest_id" \
    -beta "$BRANCH" \
    -betapassword "${STEAM_BETA_PASSWORD:-}" \
    -username "$STEAM_USERNAME" \
    -password "$STEAM_PASSWORD" \
    -dir "$work_dir" \
    -max-downloads 32 \
    2>&1 | grep -E "^\[" || true

  echo "  Computing hash..."
  hash=$(nix-hash --type sha256 --sri "$work_dir")
  echo "  Hash: $hash"

  # Update hashes with manifestId and hash
  hashes=$(echo "$hashes" | jq --arg v "$game_version" --arg m "$manifest_id" --arg h "$hash" \
    '. + {($v): {manifestId: $m, hash: $h}}')

  # Save progress (sorted by version number)
  echo "$hashes" | jq 'to_entries | sort_by(.key | split(".") | map(tonumber)) | from_entries' > "$HASHES_FILE"
  echo "  Saved"

  # Cleanup
  rm -rf "$work_dir"
  trap - EXIT
  echo ""
done <<< "$versions"

echo "Done! Hashes saved to $HASHES_FILE"
