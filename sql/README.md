# SQL layer

PostgreSQL-compatible scripts. Run in order against an empty database:

```bash
createdb ecommerce_analytics
psql -d ecommerce_analytics -f sql/01_schema.sql
psql -d ecommerce_analytics -f sql/02_load_data.sql
psql -d ecommerce_analytics -f sql/03_fact_sales.sql
psql -d ecommerce_analytics -f sql/04_revenue_trends.sql
psql -d ecommerce_analytics -f sql/05_rfm_segmentation.sql
psql -d ecommerce_analytics -f sql/06_cohort_retention.sql
psql -d ecommerce_analytics -f sql/07_product_performance.sql
```

Run from the **project root** (not from inside `sql/`) — every `\copy` path
in these scripts is relative to the project root, and each script's `\copy`
exports land in `dashboard/data/` for Power BI.

No local Postgres? `01`–`03` (the schema/load/fact-table layer) also run
unmodified against [DuckDB](https://duckdb.org/) (`duckdb
ecommerce_analytics.duckdb` then `.read sql/01_schema.sql`, swapping `\copy
... FROM 'file' WITH (...)` for DuckDB's `COPY ... FROM 'file' (...)` syntax
— the one syntax difference between the two). `04`–`07` use `NTILE`, window
functions, and other standard analytic SQL that DuckDB also supports, but
they haven't been tested there directly.

| File | Purpose |
|---|---|
| `01_schema.sql` | Creates `customers`, `products`, `orders`, `order_items` with PK/FK constraints and check constraints mirroring the cleaning rules in [`notebooks/01_data_cleaning_validation.ipynb`](../notebooks/01_data_cleaning_validation.ipynb). |
| `02_load_data.sql` | Loads `data/raw/*.csv` via `\copy`, then prints row counts as a load sanity check. |
| `03_fact_sales.sql` | Creates `fact_sales` / `fact_sales_completed` views — the SQL equivalent of the notebook's cleaned fact table. Every later analysis script queries these views, not the base tables. |
| `04_revenue_trends.sql` | Monthly KPIs, category/country revenue, new-vs-returning, headline KPIs — feeds the Power BI Revenue Overview page. Equivalent of `notebooks/02`. |
| `05_rfm_segmentation.sql` | Per-customer R/F/M scores and the 5 named segments, plus a segment-summary rollup. Equivalent of `notebooks/03` — see the file's header comment for a documented, checked discrepancy in exact segment counts (Postgres `NTILE` vs. pandas `qcut` tie-breaking; 4 of 267 customers land in a different segment, revenue totals differ by well under 1%). |
| `06_cohort_retention.sql` | Cohort assignment and the retention matrix, exported in long format for Power BI's Matrix visual. Equivalent of `notebooks/04` — verified to match the notebook's numbers exactly. |
| `07_product_performance.sql` | Product-level revenue/volume metrics with a Pareto ranking via window functions, plus a category rollup. Equivalent of `notebooks/05` — verified to match the notebook's numbers exactly. |

All seven scripts were executed together against a live PostgreSQL instance
during development (`01`→`07` in sequence, on a fresh database) with no
errors, and each analysis script (`04`–`07`) was individually checked against
its matching notebook's saved output — see each file's header comment for
specifics on what was verified.
