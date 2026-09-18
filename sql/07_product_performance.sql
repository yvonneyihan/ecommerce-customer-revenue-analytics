-- ============================================================================
-- 07_product_performance.sql
-- SQL equivalent of notebooks/05_product_performance.ipynb. Product-level
-- revenue/volume metrics, a Pareto (cumulative revenue share) ranking via
-- window functions, and a category-level rollup.
-- ============================================================================

DROP VIEW IF EXISTS product_performance;
CREATE VIEW product_performance AS
WITH product_agg AS (
    SELECT
        product_id,
        product_name,
        category,
        SUM(revenue)                AS revenue,
        SUM(quantity)                AS quantity_sold,
        COUNT(DISTINCT order_id)     AS orders,
        ROUND(AVG(price), 2)         AS avg_price
    FROM fact_sales_completed
    GROUP BY product_id, product_name, category
)
SELECT
    product_id,
    product_name,
    category,
    revenue,
    quantity_sold,
    orders,
    avg_price,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)                       AS revenue_share_pct,
    ROW_NUMBER() OVER (ORDER BY revenue DESC)                              AS product_rank,
    ROUND(
        100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / SUM(revenue) OVER ()
    , 1)                                                                    AS cumulative_revenue_pct
FROM product_agg;

-- Category-level rollup — revenue, product count, and how concentrated each
-- category's revenue is within its own top product.
DROP VIEW IF EXISTS category_performance;
CREATE VIEW category_performance AS
SELECT
    category,
    COUNT(*)                                                          AS products,
    SUM(revenue)                                                      AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)        AS revenue_share_pct,
    ROUND(SUM(revenue) / COUNT(*), 2)                                 AS avg_revenue_per_product,
    ROUND(100.0 * MAX(revenue) / SUM(revenue), 1)                     AS top_product_share_of_category_pct
FROM product_performance
GROUP BY category
ORDER BY revenue DESC;

-- Sanity check — compare against notebooks/05's product_performance.csv:
-- 50 products, top product Product_16 (Makeup) $9,732 / 3.13% share; 37 of 50
-- products needed to reach 80% cumulative revenue.
SELECT product_rank, product_name, category, revenue, revenue_share_pct, cumulative_revenue_pct
FROM product_performance
ORDER BY product_rank
LIMIT 5;

-- "Products needed to reach 80%" = the rank of the first product whose
-- cumulative revenue share reaches or crosses 80% (not a COUNT of rows
-- <= 80, which would stop one product short, at the row just before the
-- threshold is actually crossed).
SELECT MIN(product_rank) AS products_needed_for_80pct
FROM product_performance
WHERE cumulative_revenue_pct >= 80;

-- ----------------------------------------------------------------------------
-- Export to CSV for Power BI (run from the project root).
-- ----------------------------------------------------------------------------
\copy (SELECT * FROM product_performance ORDER BY product_rank) TO 'dashboard/data/product_performance.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM category_performance) TO 'dashboard/data/category_performance.csv' WITH (FORMAT csv, HEADER true)
