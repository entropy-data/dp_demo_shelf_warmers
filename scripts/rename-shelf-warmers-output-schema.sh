#!/usr/bin/env bash
# Rename the output-port Snowflake schema:
#
#   DP_SHELF_WARMERS.DP_SHELF_WARMERS_OP_V1  →  DP_SHELF_WARMERS.OP_SHELF_WARMERS_V1
#
# Per dataproduct-builder-dbt's dataproduct-dbt convention, output-port schemas
# are named `op_<output_port_id>_v<N>` (not `<profile_schema>_op_v<N>`). This is
# a one-shot migration to bring the existing Snowflake state in line with the
# convention now used by the contract, dbt config, and entropy-data demo seeds.
#
# `ALTER SCHEMA ... RENAME TO ...` keeps every table, view, grant, and constraint
# under the schema intact; only the schema identifier changes. The SHELF_WARMERS
# table data and column definitions are preserved.
#
# Credentials are read from the dbt `dp_shelf_warmers` profile
# (~/.dbt/profiles.yml, target `dev`). The database is read from the data
# contract's servers[0] so the script keeps working if the database is renamed
# in the future.
#
# Usage:
#   scripts/rename-shelf-warmers-output-schema.sh        # prompts for confirmation
#   scripts/rename-shelf-warmers-output-schema.sh --yes  # no prompt
#
# After running:
#   - `datacontract test models/output_ports/v1/shelf-warmers-v1.odcs.yaml` should pass
#   - `dbt-ol run --target prod` will materialize the table into the new schema
#   - The next platform Snowflake re-ingest picks up the rename
set -euo pipefail

ASSUME_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && ASSUME_YES=1

PROFILE="${DBT_PROFILE:-dp_shelf_warmers}"
TARGET="${DBT_TARGET:-dev}"
CONTRACT="${CONTRACT:-models/output_ports/v1/shelf-warmers-v1.odcs.yaml}"
OLD_SCHEMA="${OLD_SCHEMA:-DP_SHELF_WARMERS_OP_V1}"
NEW_SCHEMA="${NEW_SCHEMA:-OP_SHELF_WARMERS_V1}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CONTRACT_PATH="${REPO_ROOT}/${CONTRACT}"

read -r ACCOUNT USER PASSWORD ROLE WAREHOUSE < <(
  python3 - "$PROFILE" "$TARGET" <<'PY'
import sys, yaml, pathlib
profile, target = sys.argv[1], sys.argv[2]
cfg = yaml.safe_load(pathlib.Path.home().joinpath(".dbt", "profiles.yml").read_text())
o = cfg[profile]["outputs"][target]
print(o["account"], o["user"], o["password"], o["role"], o["warehouse"])
PY
)

DATABASE=$(
  python3 - "$CONTRACT_PATH" <<'PY'
import sys, yaml, pathlib
contract = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
print(contract["servers"][0]["database"])
PY
)

SQL="ALTER SCHEMA ${DATABASE}.${OLD_SCHEMA} RENAME TO ${NEW_SCHEMA};"

echo "Database     : ${DATABASE}"
echo "From schema  : ${OLD_SCHEMA}"
echo "To schema    : ${NEW_SCHEMA}"
echo "Account/role : ${ACCOUNT} / ${ROLE}"
echo "Statement    : ${SQL}"
echo
echo "Renaming a schema preserves all tables/views/grants under it. Roles or"
echo "external integrations that reference the old name by string will need to"
echo "be updated separately."

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
  --query "$SQL"

echo "Done. Schema renamed: ${DATABASE}.${OLD_SCHEMA} → ${DATABASE}.${NEW_SCHEMA}."
