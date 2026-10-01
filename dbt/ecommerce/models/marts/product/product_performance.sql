-- dbt equivalent of sql/07_product_performance.sql's product_performance view.
with product_agg as (
    select
        product_id,
        product_name,
        category,
        sum(revenue)             as revenue,
        sum(quantity)            as quantity_sold,
        count(distinct order_id) as orders,
        round(avg(price), 2)     as avg_price
    from {{ ref('int_fact_sales_completed') }}
    group by product_id, product_name, category
)
select
    product_id,
    product_name,
    category,
    revenue,
    quantity_sold,
    orders,
    avg_price,
    round(100.0 * revenue / sum(revenue) over (), 2) as revenue_share_pct,
    row_number() over (order by revenue desc)         as product_rank,
    round(
        100.0 * sum(revenue) over (order by revenue desc
                                    rows between unbounded preceding and current row)
        / sum(revenue) over ()
    , 1) as cumulative_revenue_pct
from product_agg
