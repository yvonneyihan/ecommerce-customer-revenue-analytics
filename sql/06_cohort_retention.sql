-- ============================================================================
-- 06_cohort_retention.sql
-- SQL equivalent of notebooks/04_cohort_retention.ipynb. Assigns every
-- customer to a cohort month (their first Completed order month), computes
-- months-since-acquisition for every order, and builds the retention matrix.
--
-- Exported in LONG format (one row per cohort x period), not the wide
-- pivoted matrix the notebook displays — Power BI's Matrix visual pivots
-- long-format data natively (drag period_number to Columns, cohort_month to
-- Rows, retention_pct to Values), so no manual SQL pivot is needed here.
-- ============================================================================

-- Drop in dependency order (cohort_sizes and cohort_retention_long both
-- depend on customer_cohort) so this script can be re-run safely.
DROP VIEW IF EXISTS cohort_retention_long;
DROP VIEW IF EXISTS cohort_sizes;
DROP VIEW IF EXISTS customer_cohort;
CREATE VIEW customer_cohort AS
SELECT
    customer_id,
    MIN(order_month) AS cohort_month
FROM fact_sales_completed
GROUP BY customer_id;

DROP VIEW IF EXISTS cohort_sizes;
CREATE VIEW cohort_sizes AS
SELECT
    cohort_month,
    COUNT(*) AS cohort_size
FROM customer_cohort
GROUP BY cohort_month;

DROP VIEW IF EXISTS cohort_retention_long;
CREATE VIEW cohort_retention_long AS
WITH orders_with_cohort AS (
    SELECT
        f.customer_id,
        f.order_month,
        c.cohort_month,
        (
            (EXTRACT(YEAR FROM f.order_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
            + (EXTRACT(MONTH FROM f.order_month) - EXTRACT(MONTH FROM c.cohort_month))
        )::int AS period_number
    FROM fact_sales_completed f
    JOIN customer_cohort c ON c.customer_id = f.customer_id
),
activity AS (
    SELECT
        cohort_month,
        period_number,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM orders_with_cohort
    GROUP BY cohort_month, period_number
)
SELECT
    a.cohort_month,
    a.period_number,
    a.active_customers,
    s.cohort_size,
    ROUND(100.0 * a.active_customers / s.cohort_size, 1) AS retention_pct
FROM activity a
JOIN cohort_sizes s ON s.cohort_month = a.cohort_month
ORDER BY a.cohort_month, a.period_number;

-- Sanity check — compare against notebooks/04's cohort sizes:
-- Jan 61, Feb 36, Mar 41, Apr 23, May 24, Jun 18, Jul 13, Aug 16, Sep 14,
-- Oct 11, Nov 6, Dec 4. Every cohort's period_number = 0 row should show
-- retention_pct = 100.0 by construction.
SELECT cohort_month, cohort_size FROM cohort_sizes ORDER BY cohort_month;

-- ----------------------------------------------------------------------------
-- Export to CSV for Power BI (run from the project root).
-- ----------------------------------------------------------------------------
\copy (SELECT * FROM cohort_retention_long) TO 'dashboard/data/cohort_retention_long.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cohort_sizes ORDER BY cohort_month) TO 'dashboard/data/cohort_sizes.csv' WITH (FORMAT csv, HEADER true)
