#!/usr/bin/env bash
# Drop the BRAND column from the Snowflake output-port table:
#
#   DP_SHELF_WARMERS.OP_SHELF_WARMERS_V1.SHELF_WARMERS
#
# BRAND is not part of the ODCS contract
# (models/output_ports/v1/shelf-warmers-v1.odcs.yaml) and a stray lowercase
# `brand` has been making `datacontract test` fail. This drops the physical
# column so the table matches the contract again.
#
# Credentials are read from the dbt `dp_shelf_warmers` profile
# (~/.dbt/profiles.yml, target `dev`). The fully-qualified output-port table
# (database + schema) is read from the data contract's servers[0] so the
# script keeps working when the dbt profile schema (the internal layer) and
# the output-port schema diverge (per the schema='op_v1' override).
#
# Usage:
#   scripts/drop-shelf-warmers-brand-column.sh        # prompts for confirmation
#   scripts/drop-shelf-warmers-brand-column.sh --yes  # no prompt
set -euo pipefail

ASSUME_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && ASSUME_YES=1

PROFILE="${DBT_PROFILE:-dp_shelf_warmers}"
TARGET="${DBT_TARGET:-dev}"
CONTRACT="${CONTRACT:-models/output_ports/v1/shelf-warmers-v1.odcs.yaml}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CONTRACT_PATH="${REPO_ROOT}/${CONTRACT}"

# Credentials from the dbt profile. One value per line so paths may contain
# spaces. Supports either password or key-pair (private_key_path) auth.
{
  read -r ACCOUNT
  read -r USER
  read -r ROLE
  read -r WAREHOUSE
  read -r PASSWORD
  read -r PRIVATE_KEY_PATH
} < <(
  python3 - "$PROFILE" "$TARGET" <<'PY'
import sys, yaml, pathlib
profile, target = sys.argv[1], sys.argv[2]
cfg = yaml.safe_load(pathlib.Path.home().joinpath(".dbt", "profiles.yml").read_text())
o = cfg[profile]["outputs"][target]
print(o["account"])
print(o["user"])
print(o["role"])
print(o["warehouse"])
print(o.get("password", ""))
print(o.get("private_key_path", ""))
PY
)

# Output-port database + schema from the contract.
read -r DATABASE SCHEMA < <(
  python3 - "$CONTRACT_PATH" <<'PY'
import sys, yaml, pathlib
contract = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
s = contract["servers"][0]
print(s["database"], s["schema"])
PY
)

FQTN="${DATABASE}.${SCHEMA}.SHELF_WARMERS"
SQL="ALTER TABLE ${FQTN} DROP COLUMN IF EXISTS BRAND;"

# Build auth flags: prefer key-pair (private_key_path) over password.
AUTH_FLAGS=()
if [[ -n "$PRIVATE_KEY_PATH" ]]; then
  AUTH_FLAGS=(--authenticator SNOWFLAKE_JWT --private-key-file "${PRIVATE_KEY_PATH/#\~/$HOME}")
  AUTH_DESC="key-pair (${PRIVATE_KEY_PATH})"
elif [[ -n "$PASSWORD" ]]; then
  AUTH_FLAGS=(--password "$PASSWORD")
  AUTH_DESC="password"
else
  echo "Error: profile '${PROFILE}' target '${TARGET}' has neither 'password' nor 'private_key_path'." >&2
  exit 1
fi

echo "Target table : ${FQTN}"
echo "Account/role : ${ACCOUNT} / ${ROLE}"
echo "Auth         : ${AUTH_DESC}"
echo "Statement    : ${SQL}"
echo
echo "WARNING: dropping a column is irreversible and deletes its data."

if [[ $ASSUME_YES -ne 1 ]]; then
  read -r -p "Proceed? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

snow sql --temporary-connection \
  --account "$ACCOUNT" \
  --user "$USER" \
  "${AUTH_FLAGS[@]}" \
  --role "$ROLE" \
  --warehouse "$WAREHOUSE" \
  --database "$DATABASE" \
  --schema "$SCHEMA" \
  --query "$SQL"

echo "Done. Column BRAND dropped from ${FQTN}."
