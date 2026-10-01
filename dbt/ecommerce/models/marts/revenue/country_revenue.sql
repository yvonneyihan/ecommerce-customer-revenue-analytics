-- dbt equivalent of sql/04_revenue_trends.sql's country_revenue view.
select
    country,
    sum(revenue) as revenue,
    round(100.0 * sum(revenue) / sum(sum(revenue)) over (), 1) as share_pct
from {{ ref('int_fact_sales_completed') }}
group by country
order by revenue desc
