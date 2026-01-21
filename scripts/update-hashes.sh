#!/usr/bin/env bash
# Update hashes.json with any new versions from resonite-version-monitor
#
# Requires: STEAM_USERNAME, STEAM_PASSWORD, STEAM_BETA_PASSWORD
# Run with: nix-shell -p depotdownloader jq --run ./scripts/update-hashes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HASHES_FILE="$PROJECT_DIR/hashes.json"
VERSIONS_URL="https://raw.githubusercontent.com/resonite-love/resonite-version-monitor/master/data/versions.json"

APP_ID="2519830"
DEPOT_ID="2519832"
BRANCH="headless"

if [ -z "${STEAM_USERNAME:-}" ] || [ -z "${STEAM_PASSWORD:-}" ]; then
  echo "Error: STEAM_USERNAME and STEAM_PASSWORD must be set"
  exit 1
fi

# Fetch latest versions from resonite-version-monitor
echo "Fetching versions from resonite-version-monitor..."
versions_json=$(curl -sf "$VERSIONS_URL") || {
  echo "Error: Failed to fetch versions.json"
  exit 1
}

# Load existing hashes
if [ -f "$HASHES_FILE" ]; then
  hashes=$(cat "$HASHES_FILE")
else
  hashes="{}"
fi

# Get all headless versions from remote
remote_versions=$(echo "$versions_json" | jq -r '.headless[].gameVersion' | sort -V)
local_versions=$(echo "$hashes" | jq -r 'keys[]' | sort -V)

# Find versions in remote but not in local
new_versions=$(comm -23 <(echo "$remote_versions") <(echo "$local_versions"))

if [ -z "$new_versions" ]; then
  echo "No new versions found"
  exit 0
fi

echo "New versions found:"
echo "$new_versions"
echo ""

updated=false

while read -r game_version; do
  [ -z "$game_version" ] && continue

  echo "Processing $game_version..."

  # Get manifest ID from versions.json
  manifest_id=$(echo "$versions_json" | jq -r --arg v "$game_version" '.headless[] | select(.gameVersion == $v) | .manifestId')

  if [ -z "$manifest_id" ] || [ "$manifest_id" = "null" ]; then
    echo "  Could not find manifest ID for $game_version, skipping"
    continue
  fi

  echo "  Manifest ID: $manifest_id"

  # Create temp directory for download
  work_dir=$(mktemp -d)
  trap "rm -rf $work_dir" EXIT

  echo "  Downloading depot..."
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
    2>&1 | grep -E "^\[|Downloaded" || true

  echo "  Computing NAR hash..."
  hash=$(nix-hash --type sha256 --sri "$work_dir")
  echo "  Hash: $hash"

  # Update hashes object
  hashes=$(echo "$hashes" | jq --arg v "$game_version" --arg m "$manifest_id" --arg h "$hash" \
    '. + {($v): {manifestId: $m, hash: $h}}')

  # Save progress (sorted by version number)
  echo "$hashes" | jq 'to_entries | sort_by(.key | split(".") | map(tonumber)) | from_entries' > "$HASHES_FILE"
  echo "  Saved"

  # Cleanup
  rm -rf "$work_dir"
  trap - EXIT

  updated=true
  echo ""
done <<< "$new_versions"

if [ "$updated" = true ]; then
  echo "Done! hashes.json has been updated"
else
  echo "No updates made"
fi
