#!/usr/bin/env bash
# Delete every entropy-data CLI connection whose name starts with "demo".
#
# These are LOCAL named connections stored in the entropy-data CLI config
# (~/.config/entropy-data/config.toml) — removing them does not touch any
# remote Entropy Data instance.
#
# Usage:
#   scripts/delete-demo-connections.sh        # prompts for confirmation
#   scripts/delete-demo-connections.sh --yes  # no prompt
#   scripts/delete-demo-connections.sh --dry-run
set -euo pipefail

ASSUME_YES=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Parse the first ("Name") column out of the rich table. COLUMNS is set wide so
# long connection names are not truncated with an ellipsis. (while-read loop
# instead of mapfile for macOS bash 3.2 compatibility.)
names=()
while IFS= read -r line; do
  [[ -n "$line" ]] && names+=("$line")
done < <(
  COLUMNS=400 entropy-data connection list \
    | grep -E '^│' \
    | sed -E 's/^│ *([^ │]+).*/\1/' \
    | grep -E '^demo' || true
)

if [[ ${#names[@]} -eq 0 ]]; then
  echo "No connections matching 'demo*' found. Nothing to do."
  exit 0
fi

echo "The following ${#names[@]} connection(s) match 'demo*':"
printf '  - %s\n' "${names[@]}"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry run — nothing removed)"
  exit 0
fi

if [[ $ASSUME_YES -ne 1 ]]; then
  read -r -p "Remove all of these? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

for name in "${names[@]}"; do
  echo "Removing $name ..."
  entropy-data connection remove "$name"
done

echo "Done. Remaining connections:"
entropy-data connection list
