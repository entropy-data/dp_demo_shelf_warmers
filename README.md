# Shelf Warmers

dbt data product `shelf-warmers` on Snowflake. Published to [Entropy Data](https://entropy-data.com).

Source: <https://github.com/entropy-data/dp_demo_shelf_warmers>

## Install

```bash
uv venv
source .venv/bin/activate
uv pip install dbt-core dbt-snowflake openlineage-dbt 'datacontract-cli[snowflake]' entropy-data
```

## Configure

Copy `profiles.yml.example` to `~/.dbt/profiles.yml` (or merge it in) and fill in your Snowflake credentials.

Set the Entropy Data API key for OpenLineage transport:

```bash
export OPENLINEAGE__TRANSPORT__AUTH__APIKEY=<your-entropy-data-api-key>
```

Set the Data Contract CLI credentials for Snowflake (the CLI reads `DATACONTRACT_SNOWFLAKE_*` env vars, not `~/.dbt/profiles.yml`):

```bash
export DATACONTRACT_SNOWFLAKE_USERNAME=<your-snowflake-user>
export DATACONTRACT_SNOWFLAKE_PASSWORD=<your-snowflake-password>
export DATACONTRACT_SNOWFLAKE_ROLE=<your-snowflake-role>
export DATACONTRACT_SNOWFLAKE_WAREHOUSE=<your-snowflake-warehouse>
```

## Run

```bash
source .venv/bin/activate
dbt-ol run    # runs dbt and ships OpenLineage to Entropy Data
dbt test
CONTRACT=models/output_ports/v1/snowflake_fulfillment_shelf_warmers.odcs.yaml
datacontract test "$CONTRACT" --server "$(yq '.servers[0].server' "$CONTRACT")" --logs
```

## Layout

```
models/
├── input_ports/      # external sources you read from
├── staging/          # 1:1 cleaned views over input ports
├── intermediate/     # joined / shaped views
└── output_ports/v1/  # published tables — one per output port, ODCS contract alongside
```

## Publishing

CI in `.github/workflows/data-product.yml` runs `dbt-ol run`, `dbt test`, publishes the ODPS + ODCS to Entropy Data, and runs the data contract test.
