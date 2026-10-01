-- dbt equivalent of sql/03_fact_sales.sql's fact_sales view. Grain: one row
-- per order line item, enriched with customer/product/order attributes and
-- a derived `revenue` column.
select
    oi.order_item_id,
    o.order_id,
    o.order_date,
    date_trunc('month', o.order_date)::date as order_month,
    extract(year from o.order_date)::int    as order_year,
    o.status,
    (o.status = 'Completed')                as is_completed,
    c.customer_id,
    c.country,
    c.signup_date,
    p.product_id,
    p.product_name,
    p.category,
    oi.quantity,
    oi.price,
    (oi.quantity * oi.price)::numeric(12, 2) as revenue
from {{ ref('stg_order_items') }} oi
join {{ ref('stg_orders') }}    o on o.order_id    = oi.order_id
join {{ ref('stg_customers') }} c on c.customer_id = o.customer_id
join {{ ref('stg_products') }}  p on p.product_id  = oi.product_id
