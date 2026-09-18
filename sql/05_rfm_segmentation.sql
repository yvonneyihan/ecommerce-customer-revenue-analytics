-- ============================================================================
-- 05_rfm_segmentation.sql
-- SQL equivalent of notebooks/03_rfm_segmentation.ipynb. Scores every customer
-- on Recency, Frequency, and Monetary value and maps them to the same 5 named
-- segments the notebook uses.
--
-- A note on exact reproducibility: R and M are scored here with NTILE(5),
-- Postgres' standard quantile-bucketing function — it splits customers into 5
-- equal-COUNT groups. The notebook instead used pandas' qcut, which splits on
-- equal-VALUE quantiles. The two agree almost everywhere, but can assign a
-- handful of customers sitting exactly on a tie boundary to a different
-- bucket than qcut did. Checked against data/processed/customer_rfm.csv: 4 of
-- 267 customers (1.5%) land in a different segment — At Risk matches exactly
-- (31 customers, $50,578); Champions/Loyal/Potential Loyalists/Lost are each
-- off by 1 customer (e.g. Champions: 9 here vs. 10 in the notebook). Revenue
-- totals per segment differ by well under 1%. Frequency uses the same fixed
-- thresholds as the notebook (not quantile-based either way), so it matches
-- exactly.
-- ============================================================================

-- Drop in dependency order (rfm_segment_summary depends on customer_rfm) so
-- this script can be re-run safely, e.g. after a data refresh.
DROP VIEW IF EXISTS rfm_segment_summary;
DROP VIEW IF EXISTS customer_rfm;
CREATE VIEW customer_rfm AS
WITH snapshot AS (
    SELECT MAX(order_date) + INTERVAL '1 day' AS snapshot_date
    FROM fact_sales_completed
),
raw_rfm AS (
    SELECT
        f.customer_id,
        (s.snapshot_date::date - MAX(f.order_date))          AS recency,
        COUNT(DISTINCT f.order_id)                            AS frequency,
        SUM(f.revenue)                                        AS monetary
    FROM fact_sales_completed f
    CROSS JOIN snapshot s
    GROUP BY f.customer_id, s.snapshot_date
),
scored AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        -- Recency: ordering DESC puts the largest gap (least recent, worst)
        -- first, so NTILE bucket 1 = least recent and bucket 5 = most recent
        -- — already the direction we want, with no extra reversal needed.
        NTILE(5) OVER (ORDER BY recency DESC)                 AS r_score,
        NTILE(5) OVER (ORDER BY monetary ASC)                 AS m_score,
        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency = 4 THEN 4
            ELSE 5
        END                                                    AS f_score
    FROM raw_rfm
)
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    r_score AS "R",
    f_score AS "F",
    m_score AS "M",
    (r_score + f_score + m_score)                            AS rfm_score,
    CASE
        WHEN r_score = 5 AND f_score = 5                     THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                    THEN 'Loyal'
        WHEN r_score >= 3 AND f_score < 3                     THEN 'Potential Loyalists'
        WHEN r_score < 3 AND f_score >= 3                     THEN 'At Risk'
        ELSE 'Lost'
    END                                                        AS segment
FROM scored;

-- Segment-level summary — size and revenue contribution per segment, ready
-- for Power BI KPI cards without needing DAX aggregation over 267 rows.
DROP VIEW IF EXISTS rfm_segment_summary;
CREATE VIEW rfm_segment_summary AS
SELECT
    segment,
    COUNT(*)                                                       AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)             AS pct_of_customers,
    SUM(monetary)                                                  AS total_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1)   AS pct_of_revenue,
    ROUND(AVG(monetary), 2)                                        AS avg_revenue_per_customer,
    ROUND(AVG(recency), 1)                                         AS avg_recency_days,
    ROUND(AVG(frequency), 2)                                       AS avg_frequency
FROM customer_rfm
GROUP BY segment;

-- Sanity check — compare against notebooks/03's customer_rfm.csv segment counts:
-- Champions 10, Loyal 80, Potential Loyalists 70, At Risk 31, Lost 76.
SELECT segment, customers, pct_of_customers, total_revenue, pct_of_revenue
FROM rfm_segment_summary
ORDER BY total_revenue DESC;

-- ----------------------------------------------------------------------------
-- Export to CSV for Power BI (run from the project root).
-- ----------------------------------------------------------------------------
\copy (SELECT * FROM customer_rfm ORDER BY customer_id) TO 'dashboard/data/customer_rfm.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM rfm_segment_summary ORDER BY total_revenue DESC) TO 'dashboard/data/rfm_segment_summary.csv' WITH (FORMAT csv, HEADER true)
