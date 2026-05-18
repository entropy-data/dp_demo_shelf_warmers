#!/usr/bin/env bash
# Reset the shelf-warmers demo to a clean state by running both maintenance
# scripts under scripts/:
#
#   1. scripts/delete-demo-connections.sh    — remove local "demo*" CLI connections
#   2. scripts/drop-shelf-warmers-brand-column.sh — drop the stray BRAND column
#
# Any arguments (e.g. --yes / -y, --dry-run) are forwarded to both scripts.
#
# Usage:
#   ./reset.sh        # prompts for confirmation in each step
#   ./reset.sh --yes  # no prompts
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Deleting demo connections"
"$DIR/scripts/delete-demo-connections.sh" "$@"

echo
echo "==> Dropping shelf-warmers BRAND column"
"$DIR/scripts/drop-shelf-warmers-brand-column.sh" "$@"

echo
echo "Reset complete."
