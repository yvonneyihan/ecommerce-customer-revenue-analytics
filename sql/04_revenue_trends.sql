-- ============================================================================
-- 04_revenue_trends.sql
-- Analysis views backing notebooks/02_exploratory_data_analysis.ipynb and the
-- Power BI "Revenue Overview" page. All queries read from fact_sales_completed
-- (03_fact_sales.sql) — Completed orders only. Every view here is pre-
-- aggregated to exactly the shape Power BI needs, so the dashboard build is
-- drag-and-drop with no DAX required — see dashboard/README.md.
-- ============================================================================

-- 1-4: monthly revenue, order volume, AOV, and MoM growth in one table
DROP VIEW IF EXISTS monthly_kpis;
CREATE VIEW monthly_kpis AS
WITH monthly AS (
    SELECT
        order_month,
        SUM(revenue)             AS revenue,
        COUNT(DISTINCT order_id) AS distinct_orders
    FROM fact_sales_completed
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    distinct_orders,
    ROUND(revenue / NULLIF(distinct_orders, 0), 2) AS aov,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0)
    , 1) AS mom_growth_pct
FROM monthly
ORDER BY order_month;

-- 5. Revenue by product category
DROP VIEW IF EXISTS category_revenue;
CREATE VIEW category_revenue AS
SELECT
    category,
    SUM(revenue) AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS share_pct
FROM fact_sales_completed
GROUP BY category
ORDER BY revenue DESC;

-- 6. Revenue by country
DROP VIEW IF EXISTS country_revenue;
CREATE VIEW country_revenue AS
SELECT
    country,
    SUM(revenue) AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS share_pct
FROM fact_sales_completed
GROUP BY country
ORDER BY revenue DESC;

-- 7. New vs. returning revenue by month.
-- "First purchase month" = earliest Completed order_month per customer (not
-- signup_date — see notebooks/01 Section 5 and notebooks/02 Section 7 for why).
-- Long/tall format (one row per month x customer_type) so Power BI can stack
-- it directly without a pivot.
DROP VIEW IF EXISTS new_vs_returning;
CREATE VIEW new_vs_returning AS
WITH first_purchase AS (
    SELECT customer_id, MIN(order_month) AS first_purchase_month
    FROM fact_sales_completed
    GROUP BY customer_id
)
SELECT
    f.order_month,
    CASE WHEN f.order_month = fp.first_purchase_month THEN 'New' ELSE 'Returning' END AS customer_type,
    SUM(f.revenue) AS revenue
FROM fact_sales_completed f
JOIN first_purchase fp ON fp.customer_id = f.customer_id
GROUP BY f.order_month, customer_type
ORDER BY f.order_month, customer_type;

-- 8. Headline KPIs — one row, for Power BI KPI cards (total revenue, AOV,
-- repeat purchase rate, etc.)
DROP VIEW IF EXISTS headline_kpis;
CREATE VIEW headline_kpis AS
WITH orders_per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS n_orders
    FROM fact_sales_completed
    GROUP BY customer_id
)
SELECT
    (SELECT SUM(revenue) FROM fact_sales_completed)             AS total_revenue,
    (SELECT COUNT(DISTINCT order_id) FROM fact_sales_completed) AS total_orders,
    ROUND(
        (SELECT SUM(revenue) FROM fact_sales_completed)
        / NULLIF((SELECT COUNT(DISTINCT order_id) FROM fact_sales_completed), 0)
    , 2)                                                         AS overall_aov,
    (SELECT COUNT(*) FROM orders_per_customer)                   AS total_customers,
    (SELECT COUNT(*) FROM orders_per_customer WHERE n_orders > 1) AS repeat_customers,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM orders_per_customer WHERE n_orders > 1)
        / NULLIF((SELECT COUNT(*) FROM orders_per_customer), 0)
    , 1)                                                         AS repeat_purchase_rate_pct;

-- ----------------------------------------------------------------------------
-- Export to CSV for Power BI (run from the project root; \copy is client-side
-- so this creates the files on YOUR machine, in dashboard/data/).
-- ----------------------------------------------------------------------------
\copy (SELECT * FROM monthly_kpis)    TO 'dashboard/data/monthly_kpis.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM category_revenue) TO 'dashboard/data/category_revenue.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM country_revenue)  TO 'dashboard/data/country_revenue.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM new_vs_returning) TO 'dashboard/data/new_vs_returning.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM headline_kpis)    TO 'dashboard/data/headline_kpis.csv'    WITH (FORMAT csv, HEADER true)
