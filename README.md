# E-Commerce Customer & Revenue Analytics

An end-to-end analytics project on a synthetic e-commerce dataset (customers,
orders, order line items, products), built to demonstrate SQL, Python/pandas,
data cleaning, exploratory analysis, KPI design, cohort analysis, RFM
customer segmentation, and BI dashboard readiness.

## Business objective

> **What is driving revenue performance, which customers and products are
> most valuable, and where should the company focus to improve customer
> retention and revenue growth?**

The analysis is organized around five questions:

1. **Revenue trends** — monthly revenue, MoM growth, order volume, average
   order value, revenue by product/category/region
2. **Customer behavior** — new vs. returning customers, repeat purchase
   rate, purchase frequency, customer lifetime revenue, customer
   concentration
3. **RFM segmentation** — Recency / Frequency / Monetary scoring into
   segments (Champions, Loyal, Potential Loyalists, At Risk, Lost)
4. **Cohort retention** — acquisition-month cohorts and a retention matrix
5. **Product performance** — top products/categories by revenue and volume,
   revenue contribution, concentration

Findings are written up as explicit **observations vs. recommendations** in
[`reports/findings.md`](reports/findings.md).

## Key findings so far

From `notebooks/02_exploratory_data_analysis.ipynb` (full detail in that notebook's Section 9):

<p>
  <img src="reports/figures/01_monthly_revenue.png" alt="Monthly revenue, Jan–Dec 2024" width="420">
  <img src="reports/figures/07_new_vs_returning.png" alt="New vs returning customer revenue by month" width="420">
</p>

- **Total revenue is flat for 2024** (~$23K–$31K/month, +0.2% average MoM growth) — no sustained growth or decline.
- **That flat total is hiding a real problem:** new-customer revenue falls almost every month, from $30,948 in January to ~$2,000 by November/December, while returning-customer revenue grows to compensate. Flat revenue is currently being propped up by the existing customer base, not new acquisition.
- **Repeat purchase behavior is strong** — 73.4% of customers placed 2+ completed orders (avg. 2.60 orders/customer) — so the retention side isn't the issue; the acquisition funnel is the more likely place to investigate.
- Revenue is well balanced across product categories (Hair 32.7% down to Skin 16.8%) and countries (Italy 22.7% down to Germany 15.9%) — no single category or market the business is overexposed to.

From `notebooks/03_rfm_segmentation.ipynb`:

- **Champions + Loyal customers (33.7% of the base) drive 51.2% of revenue.** Champions alone (10 customers, 3.7%) average $2,758 each.
- **At Risk is the clearest win-back opportunity:** only 31 customers (11.6%), but averaging $1,631.55 each — nearly Champions-level value — and quiet for ~6 months on average.

From `notebooks/04_cohort_retention.ipynb`:

- **New-customer acquisition collapsed steadily all year** — 61 new customers in January down to just 4 in December — which is the direct, concrete cause of the declining new-customer revenue found in `notebooks/02`.
- **Retention itself is not the problem:** cohort analysis shows no evidence retention quality declined over time; average period-1 retention across all cohorts is 17.9%.

**Power BI:** the same KPIs and charts, live in Power BI Service — see [`dashboard/README.md`](dashboard/README.md).

<img src="dashboard/screenshots/Revenue_Overview.png" alt="Power BI Revenue Overview dashboard page" width="800">

<img src="dashboard/screenshots/RFM_Analysis.png" alt="Power BI RFM Analysis dashboard page" width="800">

<img src="dashboard/screenshots/Cohort_Retention.png" alt="Power BI Cohort Retention dashboard page" width="800">

## Project status

This repo is being built in phases. Current state:

- [x] Project scaffolding, `.gitignore`, `requirements.txt`
- [x] Data profiling, validation, and cleaning (`notebooks/01`)
- [x] SQL schema, load scripts, and a `fact_sales` view (`sql/01`–`03`)
- [x] Revenue trend EDA (`notebooks/02`)
- [x] RFM segmentation (`notebooks/03`)
- [x] Cohort retention (`notebooks/04`)
- [x] Product performance (`notebooks/05`)
- [x] SQL exports for RFM / cohort / product performance (`sql/05`–`07`)
- [x] Business recommendations write-up (`reports/findings.md`)
- [x] Power BI dashboard — Revenue Overview page (`dashboard/`)
- [x] Power BI dashboard — RFM Analysis page (`dashboard/`)
- [x] Power BI dashboard — Cohort Retention page (`dashboard/`)
- [ ] Power BI dashboard — Product Performance page

**Data Engineering upgrade** (in progress — see `.env.example`, `docker-compose.yml`, `tests/`):

- [x] Dockerized Postgres + `.env`-based config (`docker-compose.yml`, `.env.example`, `src/ecommerce_pipeline/config.py`)
- [x] pytest suite: config unit tests + a DB-backed reconciliation test against the known-good numbers above
- [ ] dbt Core models (staging/intermediate/marts) replacing the hand-written `sql/03`–`07` views
- [ ] Automated ingestion (local CSV / S3 → Postgres, incremental loading)
- [ ] Data quality/reconciliation checks wired into the pipeline (not just notebook narrative)
- [ ] Apache Airflow DAG orchestrating ingestion → transform → test
- [ ] GitHub Actions CI running pytest + dbt on every PR

## Tech stack

Python (pandas, matplotlib) in Jupyter · PostgreSQL-compatible SQL · Power BI
· Git/GitHub. No machine learning — this project is scoped to demonstrate
analytics and business reasoning, not predictive modeling.

## Repository structure

```
data/
  raw/                     original source CSVs (not modified)
  processed/               cleaned tables written by notebooks/01, read by
                            everything downstream (SQL loads, later
                            notebooks, Power BI)
notebooks/
  01_data_cleaning_validation.ipynb   profiling, validation, cleaning rules,
                                       builds fact_sales / fact_sales_completed
  02_exploratory_data_analysis.ipynb  revenue trend, MoM growth, order volume,
                                       AOV, category/region mix, new vs returning
  03_rfm_segmentation.ipynb           R/F/M scoring, 5 customer segments
  04_cohort_retention.ipynb           acquisition cohorts, retention matrix
  05_product_performance.ipynb        product/category revenue, volume, Pareto
sql/
  01_schema.sql            table definitions + constraints
  02_load_data.sql         \copy load script + row-count sanity check
  03_fact_sales.sql        fact_sales / fact_sales_completed views
  04_revenue_trends.sql    pre-aggregated exports feeding the Power BI Revenue
                            Overview page
  05_rfm_segmentation.sql  per-customer R/F/M scores and segments
  06_cohort_retention.sql  cohort retention matrix (long format)
  07_product_performance.sql  product/category revenue, Pareto ranking
reports/
  figures/                 exported chart images
  findings.md              5 findings, observations vs. recommendations
dashboard/
  README.md                Power BI page write-ups
  data/                    CSV/xlsx exports uploaded to Power BI Service
  screenshots/             dashboard page screenshots
src/
  ecommerce_pipeline/      config.py — env-driven DATABASE_URL, more to come
tests/
  test_config.py           unit tests for config.py (no DB needed)
  test_postgres_pipeline.py  runs sql/01-03 against Postgres, checks known-good numbers
docker-compose.yml          Postgres service for local/Docker development
.env.example                template for required env vars (copy to .env, gitignored)
```

## Source data

**Dataset:** [E-Commerce Sales & Customer Analytics Dataset](https://www.kaggle.com/datasets/maramsa/e-commerce-sales-and-customer-analytics-dataset) by [maramsa](https://www.kaggle.com/maramsa) on Kaggle, licensed under [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

Downloaded from Kaggle and used unmodified in `data/raw/`. Product names in the source data are
placeholders (`Product_1`, `Product_2`, ...), which suggests this is a
synthetically generated dataset rather than real transaction records — that
doesn't affect its usefulness for demonstrating the analytics workflow here,
but it's worth knowing findings describe the dataset's patterns, not an
actual company's.

Provided as five CSVs under `data/raw/`:

| File | Grain | Key columns |
|---|---|---|
| `customers.csv` | 1 row / customer (300 rows) | `customer_id`, `country`, `signup_date` |
| `products.csv` | 1 row / product (50 rows) | `product_id`, `product_name`, `category` |
| `orders.csv` | 1 row / order (1,000 rows) | `order_id`, `customer_id`, `order_date`, `status` |
| `order_items.csv` | 1 row / order line (2,000 rows) | `order_id`, `product_id`, `quantity`, `price` |
| `sales_cleaned.csv` | pre-joined reference extract | used only as an external sanity check in `notebooks/01`, not as a pipeline input |

`status` ∈ `{Completed, Cancelled, Returned}`. Revenue analysis throughout
this project uses **Completed orders only**; Cancelled/Returned are tracked
separately as operational metrics. See `notebooks/01`, Section 8, for the
full rationale.

### Data quality findings (from `notebooks/01`)

- 139 of 1,000 orders (13.9%) have no matching line items — excluded from the
  line-level fact table, called out explicitly rather than silently dropped.
- 33 duplicate `(order_id, product_id)` pairs in `order_items` — kept as
  separate legitimate lines (no exact duplicate rows found).
- 55 orders have an `order_date` earlier than the customer's `signup_date` —
  flagged as a data anomaly to keep in mind, not corrected (no reliable way
  to infer the "true" date from the data available).
- No orphaned foreign keys, no null key fields, no duplicate primary keys in
  any of the four raw tables.
- The rebuilt `fact_sales_completed` table matches `sales_cleaned.csv`
  exactly: 1,625 line items, 695 distinct orders, $311,111 total revenue.

## Reproducing this project

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 1. Run all 5 notebooks in order (01 must run first — it builds fact_sales)
for nb in notebooks/0*.ipynb; do
  jupyter nbconvert --to notebook --execute --inplace "$nb"
done

# 2. (optional) load the same data into PostgreSQL and rebuild the Power BI exports
#
# Option A — Docker (no local Postgres install needed):
cp .env.example .env
docker compose up -d postgres
set -a && source .env && set +a
for f in sql/0*.sql; do psql "$DATABASE_URL" -f "$f"; done
#
# Option B — a local Postgres install:
createdb ecommerce_analytics
for f in sql/0*.sql; do psql -d ecommerce_analytics -f "$f"; done
```

See `sql/README.md` for SQL-specific notes (including running against DuckDB
if you don't have a local or Docker Postgres available).

### Running the test suite

```bash
pip install -r requirements-dev.txt
pytest tests/            # config tests always run; DB tests auto-skip if postgres isn't up
```

The DB-backed tests in `tests/test_postgres_pipeline.py` run `sql/01`–`03`
against whichever Postgres `DATABASE_URL` points at and assert the result
matches the known-good numbers above (1,625 line items, 695 orders, $311,111
revenue) — a regression check that the schema/load/fact-view layer still
reproduces the notebook's numbers exactly.

## License

The code in this repository (notebooks, SQL, docs) is licensed under the
[MIT License](LICENSE). The dataset in `data/raw/` is separately licensed by
its original author under Apache 2.0 — see [Source data](#source-data) above.

## Author

Yvonne
