"""
Integration tests for the CSV ingestion module (tests/conftest.py's
`fresh_schema` fixture rebuilds the schema from sql/01_schema.sql before
each test, so every test starts from a known-empty database).

Requires Postgres reachable — run `docker compose up -d postgres` first.
Skipped automatically otherwise.
"""

import csv
import shutil

import psycopg2
import pytest

from ecommerce_pipeline.config import PROJECT_ROOT, get_database_url
from ecommerce_pipeline.ingestion.load_csv import run_ingestion
from tests.conftest import requires_postgres

RAW_CSV_DIR = PROJECT_ROOT / "data" / "raw"


@requires_postgres
def test_ingestion_loads_expected_row_counts(fresh_schema):
    counts = run_ingestion(csv_dir=RAW_CSV_DIR)
    assert counts == {
        "customers": 300,
        "products": 50,
        "orders": 1000,
        "order_items": 2000,
    }


@requires_postgres
def test_ingestion_is_idempotent(fresh_schema):
    run_ingestion(csv_dir=RAW_CSV_DIR)
    run_ingestion(csv_dir=RAW_CSV_DIR)  # rerun must not error or duplicate rows

    conn = psycopg2.connect(get_database_url())
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM customers")
            assert cur.fetchone()[0] == 300
            cur.execute("SELECT COUNT(*) FROM orders")
            assert cur.fetchone()[0] == 1000
            cur.execute("SELECT COUNT(*) FROM order_items")
            assert cur.fetchone()[0] == 2000  # legitimate duplicate pairs preserved
    finally:
        conn.close()


@requires_postgres
def test_ingestion_upserts_changed_rows(tmp_path, fresh_schema):
    tmp_csv_dir = tmp_path / "raw"
    shutil.copytree(RAW_CSV_DIR, tmp_csv_dir)
    run_ingestion(csv_dir=tmp_csv_dir)

    customers_path = tmp_csv_dir / "customers.csv"
    rows = list(csv.DictReader(customers_path.open()))
    changed_country = "Wonderland" if rows[0]["country"] != "Wonderland" else "Atlantis"
    rows[0]["country"] = changed_country
    with customers_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    run_ingestion(csv_dir=tmp_csv_dir)  # second load should update, not duplicate

    conn = psycopg2.connect(get_database_url())
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT country FROM customers WHERE customer_id = %s",
                (rows[0]["customer_id"],),
            )
            assert cur.fetchone()[0] == changed_country
            cur.execute("SELECT COUNT(*) FROM customers")
            assert cur.fetchone()[0] == 300
    finally:
        conn.close()
