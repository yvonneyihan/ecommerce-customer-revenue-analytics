-- dbt equivalent of sql/04_revenue_trends.sql's monthly_kpis view.
with monthly as (
    select
        order_month,
        sum(revenue)             as revenue,
        count(distinct order_id) as distinct_orders
    from {{ ref('int_fact_sales_completed') }}
    group by order_month
)
select
    order_month,
    revenue,
    distinct_orders,
    round(revenue / nullif(distinct_orders, 0), 2) as aov,
    round(
        100.0 * (revenue - lag(revenue) over (order by order_month))
        / nullif(lag(revenue) over (order by order_month), 0)
    , 1) as mom_growth_pct
from monthly
order by order_month
