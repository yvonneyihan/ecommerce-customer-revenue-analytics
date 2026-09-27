"""
Integration test for the Dockerized Postgres service.

Verifies that:
  1. The `postgres` service from docker-compose.yml is reachable.
  2. sql/01-03 can be run against it end-to-end (schema, load, fact views).
  3. The resulting fact_sales_completed numbers match the known-good values
     documented in sql/README.md and reports/findings.md (1,625 line items,
     695 distinct orders, $311,111 total revenue).

Requires `docker compose up -d postgres` to be running first. Skipped
automatically if the database is not reachable, so a plain `pytest tests/`
run without Docker still passes.
"""

import subprocess

import psycopg2
import pytest

from ecommerce_pipeline.config import PROJECT_ROOT, get_database_url

SQL_SCRIPTS = [
    "sql/01_schema.sql",
    "sql/02_load_data.sql",
    "sql/03_fact_sales.sql",
]


def _database_available() -> bool:
    try:
        conn = psycopg2.connect(get_database_url(), connect_timeout=3)
        conn.close()
        return True
    except psycopg2.OperationalError:
        return False


requires_postgres = pytest.mark.skipif(
    not _database_available(),
    reason="Postgres is not reachable — run `docker compose up -d postgres` first",
)


@pytest.fixture(scope="module")
def loaded_database():
    for script in SQL_SCRIPTS:
        result = subprocess.run(
            ["psql", get_database_url(), "-v", "ON_ERROR_STOP=1", "-f", script],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"{script} failed:\n{result.stderr}"
    yield


@requires_postgres
def test_raw_table_row_counts(loaded_database):
    conn = psycopg2.connect(get_database_url())
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM customers")
            assert cur.fetchone()[0] == 300
            cur.execute("SELECT COUNT(*) FROM products")
            assert cur.fetchone()[0] == 50
            cur.execute("SELECT COUNT(*) FROM orders")
            assert cur.fetchone()[0] == 1000
            cur.execute("SELECT COUNT(*) FROM order_items")
            assert cur.fetchone()[0] == 2000
    finally:
        conn.close()


@requires_postgres
def test_fact_sales_completed_matches_known_good_numbers(loaded_database):
    conn = psycopg2.connect(get_database_url())
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COUNT(*),
                    COUNT(DISTINCT order_id),
                    SUM(revenue)
                FROM fact_sales_completed
                """
            )
            line_items, distinct_orders, total_revenue = cur.fetchone()
            assert line_items == 1625
            assert distinct_orders == 695
            assert total_revenue == pytest.approx(311111.00, abs=0.01)
    finally:
        conn.close()
