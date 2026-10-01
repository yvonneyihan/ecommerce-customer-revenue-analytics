-- dbt equivalent of sql/04_revenue_trends.sql's headline_kpis view --
-- one row, for Power BI KPI cards.
with orders_per_customer as (
    select customer_id, count(distinct order_id) as n_orders
    from {{ ref('int_fact_sales_completed') }}
    group by customer_id
)
select
    (select sum(revenue) from {{ ref('int_fact_sales_completed') }})             as total_revenue,
    (select count(distinct order_id) from {{ ref('int_fact_sales_completed') }}) as total_orders,
    round(
        (select sum(revenue) from {{ ref('int_fact_sales_completed') }})
        / nullif((select count(distinct order_id) from {{ ref('int_fact_sales_completed') }}), 0)
    , 2)                                                                          as overall_aov,
    (select count(*) from orders_per_customer)                                    as total_customers,
    (select count(*) from orders_per_customer where n_orders > 1)                  as repeat_customers,
    round(
        100.0 * (select count(*) from orders_per_customer where n_orders > 1)
        / nullif((select count(*) from orders_per_customer), 0)
    , 1)                                                                           as repeat_purchase_rate_pct
