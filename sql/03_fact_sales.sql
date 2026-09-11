-- ============================================================================
-- 03_fact_sales.sql
-- Analysis-ready view, SQL equivalent of the fact_sales / fact_sales_completed
-- tables built in notebooks/01_data_cleaning_validation.ipynb (Sections 9-10).
--
-- Grain: one row per order line item, enriched with customer/product/order
-- attributes and a derived `revenue` column. Every later analysis SQL script
-- (revenue trends, RFM, cohort, product performance) selects from
-- fact_sales_completed rather than re-joining the base tables.
-- ============================================================================

CREATE OR REPLACE VIEW fact_sales AS
SELECT
    oi.order_item_id,
    o.order_id,
    o.order_date,
    DATE_TRUNC('month', o.order_date)::date AS order_month,
    EXTRACT(YEAR FROM o.order_date)::int    AS order_year,
    o.status,
    (o.status = 'Completed')                AS is_completed,
    c.customer_id,
    c.country,
    c.signup_date,
    p.product_id,
    p.product_name,
    p.category,
    oi.quantity,
    oi.price,
    (oi.quantity * oi.price)::numeric(12,2) AS revenue
FROM order_items oi
JOIN orders    o ON o.order_id    = oi.order_id
JOIN customers c ON c.customer_id = o.customer_id
JOIN products  p ON p.product_id  = oi.product_id;

CREATE OR REPLACE VIEW fact_sales_completed AS
SELECT *
FROM fact_sales
WHERE is_completed;

-- Sanity check — should match notebooks/01 Section 10 exactly:
--   rows = 1625, distinct order_ids = 695, total revenue = 311111.00
SELECT
    COUNT(*)                         AS line_items,
    COUNT(DISTINCT order_id)         AS distinct_orders,
    SUM(revenue)                     AS total_revenue
FROM fact_sales_completed;
