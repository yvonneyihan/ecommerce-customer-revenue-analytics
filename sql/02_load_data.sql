-- ============================================================================
-- 02_load_data.sql
-- Loads the raw CSVs into the tables created by 01_schema.sql.
--
-- Uses psql's client-side \copy, which reads the file from the machine running
-- psql (not the server), so it works with a local Postgres, a remote one, or
-- Docker Postgres alike. Run from the PROJECT ROOT so the relative paths below
-- resolve, e.g.:
--
--   createdb ecommerce_analytics
--   psql -d ecommerce_analytics -f sql/01_schema.sql
--   psql -d ecommerce_analytics -f sql/02_load_data.sql
--
-- Note: source is data/raw/ (not data/processed/), because the raw column
-- layout maps 1:1 onto the table definitions below. notebooks/01 profiled
-- these files and found zero duplicate rows, zero orphaned foreign keys, and
-- zero null key fields (see its Section 13 summary) — so loading straight
-- from raw is equivalent to loading the cleaned CSVs for this dataset. The
-- derived columns added during cleaning (is_completed, revenue, order_item_id)
-- are recomputed in SQL by 03_fact_sales.sql instead of being loaded.
-- ============================================================================

\copy customers   (customer_id, country, signup_date)          FROM 'data/raw/customers.csv'   WITH (FORMAT csv, HEADER true)
\copy products     (product_id, product_name, category)        FROM 'data/raw/products.csv'    WITH (FORMAT csv, HEADER true)
\copy orders       (order_id, customer_id, order_date, status)  FROM 'data/raw/orders.csv'      WITH (FORMAT csv, HEADER true)
\copy order_items  (order_id, product_id, quantity, price)      FROM 'data/raw/order_items.csv' WITH (FORMAT csv, HEADER true)

-- order_item_id is SERIAL and is populated automatically by the column list above.

-- Quick post-load sanity check (row counts should match data/raw/*.csv exactly:
-- 300 customers, 50 products, 1000 orders, 2000 order_items).
SELECT 'customers'   AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'products',     COUNT(*) FROM products
UNION ALL SELECT 'orders',       COUNT(*) FROM orders
UNION ALL SELECT 'order_items',  COUNT(*) FROM order_items;
