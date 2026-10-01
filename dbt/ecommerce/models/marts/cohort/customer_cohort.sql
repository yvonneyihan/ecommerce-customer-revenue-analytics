-- dbt equivalent of sql/06_cohort_retention.sql's customer_cohort view.
select
    customer_id,
    min(order_month) as cohort_month
from {{ ref('int_fact_sales_completed') }}
group by customer_id
