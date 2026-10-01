-- dbt equivalent of sql/06_cohort_retention.sql's cohort_sizes view.
select
    cohort_month,
    count(*) as cohort_size
from {{ ref('customer_cohort') }}
group by cohort_month
