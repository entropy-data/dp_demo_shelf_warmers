-- The inferred last_sale_timestamp must never be in the future. If it is, the
-- staging / inferred-sale logic is computing a sale event that hasn't happened
-- yet — likely a clock-skew or join bug.

select sku, last_sale_timestamp
from {{ ref('shelf_warmers') }}
where last_sale_timestamp > current_timestamp()
