# SQL layer

PostgreSQL-compatible scripts. Run in order against an empty database:

```bash
createdb ecommerce_analytics
psql -d ecommerce_analytics -f sql/01_schema.sql
psql -d ecommerce_analytics -f sql/02_load_data.sql
psql -d ecommerce_analytics -f sql/03_fact_sales.sql
```

Run from the **project root** (not from inside `sql/`) — the `\copy` paths in
`02_load_data.sql` are relative to the project root.

No local Postgres? `sql/01`–`03` also run unmodified against
[DuckDB](https://duckdb.org/) (`duckdb ecommerce_analytics.duckdb` then
`.read sql/01_schema.sql`, swapping `\copy ... FROM 'file' WITH (...)` for
DuckDB's `COPY ... FROM 'file' (...)` syntax — the one syntax difference
between the two).

| File | Purpose |
|---|---|
| `01_schema.sql` | Creates `customers`, `products`, `orders`, `order_items` with PK/FK constraints and check constraints mirroring the cleaning rules in [`notebooks/01_data_cleaning_validation.ipynb`](../notebooks/01_data_cleaning_validation.ipynb). |
| `02_load_data.sql` | Loads `data/raw/*.csv` via `\copy`, then prints row counts as a load sanity check. |
| `03_fact_sales.sql` | Creates `fact_sales` / `fact_sales_completed` views — the SQL equivalent of the notebook's cleaned fact table. Every later analysis script queries these views, not the base tables. |

These three scripts were executed against a live PostgreSQL instance during
development and reproduced the notebook's numbers exactly (1,625 completed
line items, 695 distinct orders, $311,111 total revenue).

Analysis queries (revenue trends, RFM, cohort retention, product performance)
will be added here as `04`–`07`, each alongside its matching notebook in
`notebooks/`.
