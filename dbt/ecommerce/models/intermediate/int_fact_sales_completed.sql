-- dbt equivalent of sql/03_fact_sales.sql's fact_sales_completed view.
-- Every mart below reads from here, not from int_fact_sales directly --
-- same rule as sql/README.md: "Completed orders only" for revenue analysis.
select *
from {{ ref('int_fact_sales') }}
where is_completed
