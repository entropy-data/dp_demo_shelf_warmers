{{ config(materialized='table', schema='op_v1') }}

-- Governed by snowflake_fulfillment_shelf_warmers.odcs.yaml (ODCS id: snowflake_fulfillment_shelf_warmers)
--
-- STOCK_UPDATES records stock-level snapshots per (SKU, LOCATION, TIMESTAMP). AMOUNT is
-- always non-negative (contract: minimum 0), so a "sale" is inferred as an event whose
-- AMOUNT is lower than the previous snapshot at the same (SKU, LOCATION).
--
-- A shelf warmer is then: an article that is still in stock (sum of latest per-location
-- snapshots > 0) AND whose most recent inferred sale is older than 6 months, OR that has
-- never had an inferred sale.

with stock_events as (
    select SKU, LOCATION, AMOUNT, TIMESTAMP
    from {{ source('stock-update-events_snowflake_fulfillment_stock_update_events', 'STOCK_UPDATES') }}
),

with_prev_amount as (
    select
        SKU,
        LOCATION,
        AMOUNT,
        TIMESTAMP,
        lag(AMOUNT) over (partition by SKU, LOCATION order by TIMESTAMP) as prev_amount
    from stock_events
),

inferred_sales as (
    select SKU, TIMESTAMP
    from with_prev_amount
    where prev_amount is not null
      and AMOUNT < prev_amount
),

last_sale_per_sku as (
    select SKU, max(TIMESTAMP) as last_sale_ts
    from inferred_sales
    group by SKU
),

latest_per_location as (
    select SKU, LOCATION, AMOUNT,
           row_number() over (partition by SKU, LOCATION order by TIMESTAMP desc) as rn
    from stock_events
),

current_stock_per_sku as (
    select SKU, sum(AMOUNT) as current_stock
    from latest_per_location
    where rn = 1
    group by SKU
)

select
    cast(articles.SKU              as varchar)      as SKU,
    cast(articles.NAME             as varchar)      as ARTICLE_NAME,
    cast(ls.last_sale_ts           as timestamp_tz) as LAST_SALE_TIMESTAMP,
    cast(current_timestamp()       as timestamp_tz) as PROCESSING_TIMESTAMP,
    cast(articles.BRAND_NAME       as varchar)      as BRAND
from {{ source('articles-latest_snowflake_articles_latest', 'ARTICLES') }} as articles
join current_stock_per_sku as cs on cs.SKU = articles.SKU
left join last_sale_per_sku as ls on ls.SKU = articles.SKU
where cs.current_stock > 0
  and (
        ls.last_sale_ts is null
        or ls.last_sale_ts < dateadd(month, -6, current_timestamp())
      )
