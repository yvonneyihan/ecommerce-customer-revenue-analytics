-- dbt equivalent of sql/04_revenue_trends.sql's category_revenue view.
select
    category,
    sum(revenue) as revenue,
    round(100.0 * sum(revenue) / sum(sum(revenue)) over (), 1) as share_pct
from {{ ref('int_fact_sales_completed') }}
group by category
order by revenue desc
