-- dbt test convention: a query that returns 0 rows passes. Fails (returns a
-- row) if int_fact_sales_completed's aggregate numbers drift from the
-- documented known-good values for this dataset (see README.md "Data
-- quality findings" / ecommerce_pipeline.quality.checks.KNOWN_GOOD).
with agg as (
    select
        count(*)                 as line_items,
        count(distinct order_id) as distinct_orders,
        sum(revenue)              as total_revenue
    from {{ ref('int_fact_sales_completed') }}
)
select *
from agg
where line_items <> 1625
   or distinct_orders <> 695
   or round(total_revenue, 2) <> 311111.00
