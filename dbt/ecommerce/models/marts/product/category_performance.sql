-- dbt equivalent of sql/07_product_performance.sql's category_performance view.
select
    category,
    count(*)                                                   as products,
    sum(revenue)                                               as revenue,
    round(100.0 * sum(revenue) / sum(sum(revenue)) over (), 1) as revenue_share_pct,
    round(sum(revenue) / count(*), 2)                          as avg_revenue_per_product,
    round(100.0 * max(revenue) / sum(revenue), 1)              as top_product_share_of_category_pct
from {{ ref('product_performance') }}
group by category
order by revenue desc
