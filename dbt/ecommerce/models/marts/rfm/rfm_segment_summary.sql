-- dbt equivalent of sql/05_rfm_segmentation.sql's rfm_segment_summary view.
select
    segment,
    count(*)                                                     as customers,
    round(100.0 * count(*) / sum(count(*)) over (), 1)           as pct_of_customers,
    sum(monetary)                                                as total_revenue,
    round(100.0 * sum(monetary) / sum(sum(monetary)) over (), 1) as pct_of_revenue,
    round(avg(monetary), 2)                                      as avg_revenue_per_customer,
    round(avg(recency), 1)                                       as avg_recency_days,
    round(avg(frequency), 2)                                      as avg_frequency
from {{ ref('customer_rfm') }}
group by segment
