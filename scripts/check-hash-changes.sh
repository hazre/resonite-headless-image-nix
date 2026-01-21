#!/usr/bin/env bash
# Check if hashes.json has changed and output info for CI
#
# Outputs (for GitHub Actions):
#   has_changes=true/false
#   new_versions=comma-separated list of new versions
#
# Exit codes:
#   0 - success (check has_changes output for result)
#   1 - error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HASHES_FILE="$PROJECT_DIR/hashes.json"

# Check if hashes.json has uncommitted changes
if git -C "$PROJECT_DIR" diff --quiet "$HASHES_FILE" 2>/dev/null; then
  echo "No changes to hashes.json"

  # Output for GitHub Actions
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "has_changes=false" >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

echo "hashes.json has been updated"

# Extract new version numbers from the diff
new_versions=$(git -C "$PROJECT_DIR" diff "$HASHES_FILE" | grep '^+.*"2[0-9]\{3\}\.' | sed 's/.*"\(2[^"]*\)".*/\1/' | head -5 | tr '\n' ', ' | sed 's/,$//')

echo "New versions: $new_versions"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "has_changes=true" >> "$GITHUB_OUTPUT"
  echo "new_versions=$new_versions" >> "$GITHUB_OUTPUT"
fi
