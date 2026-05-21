#!/usr/bin/env bash
# Reset the shelf-warmers demo to a clean state by running both maintenance
# scripts under scripts/:
#
#   1. scripts/delete-demo-connections.sh    — remove local "demo*" CLI connections
#   2. scripts/drop-shelf-warmers-brand-column.sh — drop the stray BRAND column
#
# Also deletes this project's Claude Code memory directory under
# ~/.claude/projects/, whose name is derived from the repo's absolute path
# (slashes and underscores replaced with dashes).
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
echo "==> Deleting Claude Code project memory"
ASSUME_YES=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
  esac
done

PROJECT_SLUG="$(printf '%s' "$DIR" | tr '/_' '--')"
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_SLUG"
if [ ! -d "$MEMORY_DIR" ]; then
  echo "No memory directory at $MEMORY_DIR (nothing to remove)"
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] Would remove $MEMORY_DIR"
else
  proceed=$ASSUME_YES
  if [ "$proceed" -ne 1 ]; then
    read -r -p "Remove $MEMORY_DIR? [y/N] " reply
    case "$reply" in
      y|Y|yes|YES) proceed=1 ;;
    esac
  fi
  if [ "$proceed" -eq 1 ]; then
    echo "Removing $MEMORY_DIR"
    rm -rf "$MEMORY_DIR"
  else
    echo "Skipped."
  fi
fi

echo
echo "Reset complete."
