#!/usr/bin/env bash
# Drop the BRAND column from the Snowflake output-port table:
#
#   DP_SHELF_WARMERS.OP_SHELF_WARMERS_V1.SHELF_WARMERS
#
# BRAND is not part of the ODCS contract
# (models/output_ports/v1/snowflake_fulfillment_shelf_warmers.odcs.yaml) and a
# stray lowercase `brand` has been making `datacontract test` fail. This drops
# the physical column so the table matches the contract again.
#
# Credentials are read from the dbt `shelf_warmers` profile (~/.dbt/profiles.yml,
# target `dev`) and passed to the Snowflake CLI via a temporary connection.
#
# Usage:
#   scripts/drop-shelf-warmers-brand-column.sh        # prompts for confirmation
#   scripts/drop-shelf-warmers-brand-column.sh --yes  # no prompt
set -euo pipefail

ASSUME_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && ASSUME_YES=1

PROFILE="${DBT_PROFILE:-shelf_warmers}"
TARGET="${DBT_TARGET:-dev}"

read -r ACCOUNT USER PASSWORD ROLE WAREHOUSE DATABASE SCHEMA < <(
  python3 - "$PROFILE" "$TARGET" <<'PY'
import sys, yaml, pathlib
profile, target = sys.argv[1], sys.argv[2]
cfg = yaml.safe_load(pathlib.Path.home().joinpath(".dbt", "profiles.yml").read_text())
o = cfg[profile]["outputs"][target]
print(o["account"], o["user"], o["password"], o["role"],
      o["warehouse"], o["database"], o["schema"])
PY
)

FQTN="${DATABASE}.${SCHEMA}.SHELF_WARMERS"
SQL="ALTER TABLE ${FQTN} DROP COLUMN BRAND;"

echo "Target table : ${FQTN}"
echo "Account/role : ${ACCOUNT} / ${ROLE}"
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
  --password "$PASSWORD" \
  --role "$ROLE" \
  --warehouse "$WAREHOUSE" \
  --database "$DATABASE" \
  --schema "$SCHEMA" \
  --query "$SQL"

echo "Done. Column BRAND dropped from ${FQTN}."
