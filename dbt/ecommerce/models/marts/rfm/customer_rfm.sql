-- dbt equivalent of sql/05_rfm_segmentation.sql's customer_rfm view.
--
-- A note on exact reproducibility (carried over from sql/05_rfm_segmentation.sql):
-- R and M are scored here with NTILE(5), Postgres' standard quantile-bucketing
-- function -- it splits customers into 5 equal-COUNT groups. notebooks/03
-- instead used pandas' qcut, which splits on equal-VALUE quantiles. The two
-- agree almost everywhere, but can assign a handful of customers sitting
-- exactly on a tie boundary to a different bucket than qcut did: 4 of 267
-- customers (1.5%) land in a different segment; revenue totals per segment
-- differ by well under 1%. Frequency uses the same fixed thresholds as the
-- notebook either way, so it matches exactly.
with snapshot as (
    select max(order_date) + interval '1 day' as snapshot_date
    from {{ ref('int_fact_sales_completed') }}
),
raw_rfm as (
    select
        f.customer_id,
        (s.snapshot_date::date - max(f.order_date)) as recency,
        count(distinct f.order_id)                  as frequency,
        sum(f.revenue)                               as monetary
    from {{ ref('int_fact_sales_completed') }} f
    cross join snapshot s
    group by f.customer_id, s.snapshot_date
),
scored as (
    select
        customer_id,
        recency,
        frequency,
        monetary,
        -- Recency: ordering DESC puts the largest gap (least recent, worst)
        -- first, so NTILE bucket 1 = least recent and bucket 5 = most recent
        -- -- already the direction we want, with no extra reversal needed.
        ntile(5) over (order by recency desc) as r_score,
        ntile(5) over (order by monetary asc)  as m_score,
        case
            when frequency = 1 then 1
            when frequency = 2 then 2
            when frequency = 3 then 3
            when frequency = 4 then 4
            else 5
        end as f_score
    from raw_rfm
)
select
    customer_id,
    recency,
    frequency,
    monetary,
    r_score as "R",
    f_score as "F",
    m_score as "M",
    (r_score + f_score + m_score) as rfm_score,
    case
        when r_score = 5 and f_score = 5  then 'Champions'
        when r_score >= 3 and f_score >= 3 then 'Loyal'
        when r_score >= 3 and f_score < 3  then 'Potential Loyalists'
        when r_score < 3 and f_score >= 3  then 'At Risk'
        else 'Lost'
    end as segment
from scored
