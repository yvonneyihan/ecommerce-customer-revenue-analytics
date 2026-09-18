# Business Findings & Recommendations

**Project:** E-Commerce Customer & Revenue Analytics
**Based on:** `notebooks/01`–`05`, `sql/01`–`04`, and the Power BI Revenue Overview dashboard.

## Business question

> What is driving revenue performance, which customers and products are most valuable, and where should the company focus to improve customer retention and revenue growth?

## Executive summary

2024 revenue was flat (~$311K total, essentially 0% net growth across the year) — but "flat" is hiding a real problem underneath. **New-customer acquisition collapsed steadily all year** (61 new customers in January down to 4 in December), and flat total revenue only held up because existing customers bought more to compensate. Retention itself is not the bottleneck — cohort analysis shows no evidence that customers are being retained worse over time. The clearest, most concrete opportunity for near-term revenue protection is the 31 "At Risk" customers, who are worth nearly as much per customer as the top segment but have gone quiet for ~6 months. The product catalog and revenue base are both well diversified, with no single product, category, or country the business is dangerously dependent on.

## Key metrics at a glance

| Metric | Value | Source |
|---|---|---|
| Total revenue (Completed orders, 2024) | $311,111 | `notebooks/02` |
| Average MoM revenue growth | +0.2% | `notebooks/02` |
| Overall AOV | $447.64 | `notebooks/02` |
| Repeat purchase rate | 73.4% | `notebooks/02` |
| Customers scored (≥1 Completed order) | 267 | `notebooks/03` |
| Revenue from Champions + Loyal (33.7% of customers) | 51.2% | `notebooks/03` |
| New customers acquired, Jan vs. Dec | 61 → 4 | `notebooks/04` |
| Products needed to reach 80% of revenue | 37 of 50 (74%) | `notebooks/05` |

---

## Finding 1 — Flat revenue is masking a collapsing acquisition funnel, not a retention problem

**Observation:** Total revenue held roughly flat all year (+0.2% average MoM growth), but new-customer revenue fell from $30,948 in January to ~$2,000 by November/December, while returning-customer revenue grew to offset it (returning customers' share of monthly revenue rose from 0% to 92%). Cohort analysis confirms the root cause is upstream: the *number* of new customers acquired each month fell steadily and almost monotonically, from 61 in January to just 4 in December. Retention quality itself shows no decline across cohorts — if anything, later (smaller) cohorts showed slightly *higher* first-month retention (22.6% vs. 13.1% for earlier cohorts, though that comparison should be read cautiously given the small cohort sizes involved).

**Recommendation:** Prioritize acquisition-funnel investigation and investment (marketing channel performance, spend levels, conversion funnel diagnostics) over further retention-focused spending — this year's data doesn't support retention as the constraint. Track **new customers acquired per month** as a leading KPI alongside revenue, since revenue alone is currently masking this trend.

## Finding 2 — A small, high-value "At Risk" segment is the clearest near-term revenue-protection opportunity

**Observation:** RFM segmentation shows Champions + Loyal customers (33.7% of the 267 scored customers) generate 51.2% of revenue — a meaningful but not extreme concentration. The segment that stands out is **At Risk**: only 31 customers (11.6%), but they average $1,631.55 in revenue each — nearly as much as Champions ($2,758.10) — and were fairly frequent buyers (3.68 orders on average) before going quiet for ~6 months on average (178.5 days).

**Recommendation:** Run a targeted win-back campaign aimed specifically at these 31 customers (personalized outreach, a reactivation offer) rather than a broad-based retention program — the potential revenue at stake (~$50,578, the segment's current annual total) is concentrated enough to make a small, high-touch campaign worthwhile. Separately, a lightweight recognition/loyalty perk for the 10 Champions customers helps protect the highest-value segment.

## Finding 3 — A large group of recently active, low-frequency customers hasn't built a purchase habit yet

**Observation:** Potential Loyalists (70 customers, 26.2% of the base) are recently active (53.9 days average recency) but have only ordered ~1.7 times on average, contributing a modest 16.7% of revenue. This is the largest segment by potential upside — more customers than Champions and At Risk combined — but currently under-monetized relative to Loyal customers.

**Recommendation:** Introduce an automated second-purchase incentive (time-limited discount or bundle offer) triggered 30–45 days after a customer's first order, aimed at converting this segment into repeat buyers before they drift toward At Risk or Lost.

## Finding 4 — The product catalog is unusually well-diversified; Body outperforms on a per-product basis

**Observation:** Revenue is spread far more evenly across the 50-product catalog than is typical — it takes 37 products (74%) to reach 80% of revenue, essentially the inverse of a standard 80/20 pattern, and all 50 products sold at least once. At the category level, Hair leads in total revenue (32.7%) mainly because it has the most SKUs (17); Body has the fewest SKUs (10) but the highest average revenue per product ($7,601 vs. Hair's $5,979).

**Recommendation:** There's no small set of "hero" products to protect or over-index marketing spend on — the existing broad, even allocation across the catalog is appropriate given how flat the distribution already is. Body is worth a closer look for catalog expansion, since it's the most revenue-efficient category per product carried.

## Finding 5 — Regional and category revenue are both well-balanced, which is a strength worth preserving

**Observation:** No single country or product category dominates revenue. The five countries range from Italy (22.7%) to Germany (15.9%) — a spread of under 7 points — and the four categories range from Hair (32.7%) to Skin (16.8%).

**Recommendation:** No urgent action needed here. As the business scales or adds new markets/categories, this diversification is a structural strength worth deliberately preserving rather than over-concentrating future growth investment in whichever region or category happens to be performing best in a given quarter.

---

## Limitations and caveats

- **Synthetic dataset:** product names are placeholders (`Product_1`, `Product_2`, ...), and the dataset was very likely generated rather than sourced from real transactions (see the main `README.md`'s Source data section). Findings describe patterns *in this dataset*, not a verified real business.
- **Single year of data (2024):** trends described as "flat" or "declining" are observed within one year with no prior-year baseline — genuine seasonality or multi-year trends can't be distinguished from this data alone.
- **Small segment sample sizes:** several RFM segments (e.g. Champions, 10 customers) and later cohort months (e.g. December, 4 customers) are small enough that individual customers can swing a percentage noticeably. Directional conclusions are reasonably solid; precise percentages for the smallest groups should be treated as approximate.
- **Right-censored cohort data:** later cohorts (e.g. November, December) haven't had as many months to show retention as the January cohort has — the cohort comparisons in Finding 1 account for this (see `notebooks/04`'s methodology), but it's a structural limit on how far that comparison can be pushed.

## Sources

| Notebook | Contribution |
|---|---|
| `notebooks/01_data_cleaning_validation.ipynb` | Data cleaning, validation, and the `fact_sales` / `fact_sales_completed` tables everything else builds on |
| `notebooks/02_exploratory_data_analysis.ipynb` | Revenue trends, MoM growth, AOV, category/region mix, new vs. returning |
| `notebooks/03_rfm_segmentation.ipynb` | RFM scoring and the 5 customer segments |
| `notebooks/04_cohort_retention.ipynb` | Acquisition cohorts and the retention matrix |
| `notebooks/05_product_performance.ipynb` | Product- and category-level revenue/volume analysis |
