"""
Loads data/raw/*.csv into the Postgres schema created by sql/01_schema.sql.

Unlike sql/02_load_data.sql's one-shot \\copy (which only works against an
empty table), this module upserts: customers, products, and orders are
merged by their real source primary key (INSERT ... ON CONFLICT DO UPDATE),
so rerunning ingestion after the source data changes updates existing rows
and inserts new ones, without erroring or duplicating.

order_items is the one exception: the source data has no reliable natural
key (order_item_id is a surrogate SERIAL, and (order_id, product_id) is not
unique -- 33 pairs are legitimate duplicate lines, see notebooks/01 Section 7
/ sql/README.md). Upserting on a non-unique key would silently collapse
those into one row. Until the source provides a real line-item id,
order_items is loaded as an atomic replace instead: idempotent, but at the
table level rather than the row level.

All four tables are loaded in one transaction, so a run either fully
succeeds or leaves the database untouched.
"""

import argparse
import csv
import logging
from decimal import Decimal
from pathlib import Path
from typing import Optional

import psycopg2
from psycopg2.extras import execute_values

from ecommerce_pipeline.config import PROJECT_ROOT, get_database_url

logger = logging.getLogger(__name__)

DEFAULT_CSV_DIR = PROJECT_ROOT / "data" / "raw"


def _read_csv_rows(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def load_customers(conn, csv_dir: Path) -> int:
    rows = _read_csv_rows(csv_dir / "customers.csv")
    values = [(int(r["customer_id"]), r["country"], r["signup_date"]) for r in rows]
    with conn.cursor() as cur:
        execute_values(
            cur,
            """
            INSERT INTO customers (customer_id, country, signup_date)
            VALUES %s
            ON CONFLICT (customer_id) DO UPDATE SET
                country     = EXCLUDED.country,
                signup_date = EXCLUDED.signup_date
            """,
            values,
        )
    return len(values)


def load_products(conn, csv_dir: Path) -> int:
    rows = _read_csv_rows(csv_dir / "products.csv")
    values = [(int(r["product_id"]), r["product_name"], r["category"]) for r in rows]
    with conn.cursor() as cur:
        execute_values(
            cur,
            """
            INSERT INTO products (product_id, product_name, category)
            VALUES %s
            ON CONFLICT (product_id) DO UPDATE SET
                product_name = EXCLUDED.product_name,
                category     = EXCLUDED.category
            """,
            values,
        )
    return len(values)


def load_orders(conn, csv_dir: Path) -> int:
    rows = _read_csv_rows(csv_dir / "orders.csv")
    values = [
        (int(r["order_id"]), int(r["customer_id"]), r["order_date"], r["status"])
        for r in rows
    ]
    with conn.cursor() as cur:
        execute_values(
            cur,
            """
            INSERT INTO orders (order_id, customer_id, order_date, status)
            VALUES %s
            ON CONFLICT (order_id) DO UPDATE SET
                customer_id = EXCLUDED.customer_id,
                order_date  = EXCLUDED.order_date,
                status      = EXCLUDED.status
            """,
            values,
        )
    return len(values)


def load_order_items(conn, csv_dir: Path) -> int:
    rows = _read_csv_rows(csv_dir / "order_items.csv")
    values = [
        (int(r["order_id"]), int(r["product_id"]), int(r["quantity"]), Decimal(r["price"]))
        for r in rows
    ]
    with conn.cursor() as cur:
        cur.execute("DELETE FROM order_items")
        execute_values(
            cur,
            "INSERT INTO order_items (order_id, product_id, quantity, price) VALUES %s",
            values,
        )
    return len(values)


def run_ingestion(csv_dir: Path = DEFAULT_CSV_DIR, database_url: Optional[str] = None) -> dict:
    database_url = database_url or get_database_url()
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            counts = {
                "customers": load_customers(conn, csv_dir),
                "products": load_products(conn, csv_dir),
                "orders": load_orders(conn, csv_dir),
                "order_items": load_order_items(conn, csv_dir),
            }
        logger.info("Ingestion complete: %s", counts)
        return counts
    finally:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Upsert data/raw/*.csv into Postgres (schema must already exist -- see sql/01_schema.sql)."
    )
    parser.add_argument("--csv-dir", type=Path, default=DEFAULT_CSV_DIR)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    print(run_ingestion(csv_dir=args.csv_dir))
