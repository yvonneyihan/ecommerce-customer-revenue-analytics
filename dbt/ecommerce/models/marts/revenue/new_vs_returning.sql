-- dbt equivalent of sql/04_revenue_trends.sql's new_vs_returning view.
-- "First purchase month" = earliest Completed order_month per customer (not
-- signup_date -- see notebooks/01 Section 5 and notebooks/02 Section 7 for why).
with first_purchase as (
    select customer_id, min(order_month) as first_purchase_month
    from {{ ref('int_fact_sales_completed') }}
    group by customer_id
)
select
    f.order_month,
    case when f.order_month = fp.first_purchase_month then 'New' else 'Returning' end as customer_type,
    sum(f.revenue) as revenue
from {{ ref('int_fact_sales_completed') }} f
join first_purchase fp on fp.customer_id = f.customer_id
group by f.order_month, customer_type
order by f.order_month, customer_type
