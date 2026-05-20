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

Set the Entropy Data host and API key for OpenLineage transport. `openlineage.yml` intentionally omits the URL so this repo works against any deployment (cloud, self-hosted, local) — these env vars are the source of truth:

```bash
export OPENLINEAGE__TRANSPORT__URL=<your-entropy-data-host>          # e.g. https://demo.entropy-data.com
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
datacontract test datacontracts/shelf_warmers_v1.odcs.yaml --server production --logs
```

## Layout

```
.
├── dbt_project.yml
├── shelf-warmers.odps.yaml          # Data product metadata
├── datacontracts/                   # Output port data contracts
│   └── shelf_warmers_v1.odcs.yaml
├── models/
│   ├── input_ports/                 # Sources read from other data products
│   │   └── sources.yml
│   ├── staging/                     # Internal: cleaning + normalization
│   ├── intermediate/                # Internal: business logic
│   └── output_ports/                # Published output port models
│       ├── shelf_warmers.sql
│       └── shelf_warmers.yml
└── tests/                           # dbt data tests
```

Layout follows [Building Data Products with dbt](https://www.entropy-data.com/learn/data-products-with-dbt).

## Publishing

CI in `.github/workflows/data-product.yml` runs `dbt-ol run`, `dbt test`, publishes the ODPS + ODCS to Entropy Data, and runs the data contract test.
