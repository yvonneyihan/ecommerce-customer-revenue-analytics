-- dbt equivalent of sql/06_cohort_retention.sql's cohort_retention_long view.
-- Long format (one row per cohort x period) -- Power BI's Matrix visual
-- pivots this natively, no manual SQL pivot needed.
with orders_with_cohort as (
    select
        f.customer_id,
        f.order_month,
        c.cohort_month,
        (
            (extract(year from f.order_month) - extract(year from c.cohort_month)) * 12
            + (extract(month from f.order_month) - extract(month from c.cohort_month))
        )::int as period_number
    from {{ ref('int_fact_sales_completed') }} f
    join {{ ref('customer_cohort') }} c on c.customer_id = f.customer_id
),
activity as (
    select
        cohort_month,
        period_number,
        count(distinct customer_id) as active_customers
    from orders_with_cohort
    group by cohort_month, period_number
)
select
    a.cohort_month,
    a.period_number,
    a.active_customers,
    s.cohort_size,
    round(100.0 * a.active_customers / s.cohort_size, 1) as retention_pct
from activity a
join {{ ref('cohort_sizes') }} s on s.cohort_month = a.cohort_month
order by a.cohort_month, a.period_number
