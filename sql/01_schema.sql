-- ============================================================================
-- 01_schema.sql
-- E-Commerce Customer & Revenue Analytics
--
-- PostgreSQL-compatible schema for the four raw source tables. Column choices
-- and constraints mirror the cleaning decisions documented in
-- notebooks/01_data_cleaning_validation.ipynb (Section 8).
-- ============================================================================

DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    customer_id   INTEGER      PRIMARY KEY,
    country       TEXT         NOT NULL,
    signup_date   DATE         NOT NULL
);

CREATE TABLE products (
    product_id    INTEGER      PRIMARY KEY,
    product_name  TEXT         NOT NULL,
    category      TEXT         NOT NULL
);

CREATE TABLE orders (
    order_id      INTEGER      PRIMARY KEY,
    customer_id   INTEGER      NOT NULL REFERENCES customers (customer_id),
    order_date    DATE         NOT NULL,
    status        TEXT         NOT NULL CHECK (status IN ('Completed', 'Cancelled', 'Returned'))
);

CREATE TABLE order_items (
    order_item_id SERIAL       PRIMARY KEY,
    order_id      INTEGER      NOT NULL REFERENCES orders (order_id),
    product_id    INTEGER      NOT NULL REFERENCES products (product_id),
    quantity      INTEGER      NOT NULL CHECK (quantity > 0),
    price         NUMERIC(10,2) NOT NULL CHECK (price > 0)
);

CREATE INDEX idx_orders_customer_id   ON orders (customer_id);
CREATE INDEX idx_orders_order_date    ON orders (order_date);
CREATE INDEX idx_orders_status        ON orders (status);
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
CREATE INDEX idx_order_items_product  ON order_items (product_id);

COMMENT ON TABLE customers    IS 'One row per customer. Grain: customer_id.';
COMMENT ON TABLE products     IS 'One row per product. Grain: product_id.';
COMMENT ON TABLE orders       IS 'One row per order (header). Grain: order_id. Not every order has line items — see notebooks/01 Section 7.';
COMMENT ON TABLE order_items  IS 'One row per order line. Grain: order_item_id. revenue is derived (quantity * price), not stored here — see 03_fact_sales.sql.';
