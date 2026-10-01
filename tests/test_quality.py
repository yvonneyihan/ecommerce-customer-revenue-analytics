"""
Tests for ecommerce_pipeline.quality.checks — asserts each automated DQ
check reproduces the figures documented in README.md's "Data quality
findings" section (originally found by hand in notebooks/01, Section 8/13),
and that reconcile() reports a clean pass end-to-end.

Requires Postgres reachable — run `docker compose up -d postgres` first.
Skipped automatically otherwise.
"""

import psycopg2
import pytest

from ecommerce_pipeline.config import get_database_url
from ecommerce_pipeline.quality import checks
from tests.conftest import requires_postgres


@pytest.fixture
def conn(loaded_database):
    connection = psycopg2.connect(get_database_url())
    yield connection
    connection.close()


@requires_postgres
def test_no_orphaned_foreign_keys(conn):
    assert checks.count_orphaned_orders(conn) == 0
    assert checks.count_orphaned_order_items_order_id(conn) == 0
    assert checks.count_orphaned_order_items_product_id(conn) == 0


@requires_postgres
def test_no_null_key_fields_or_duplicate_primary_keys(conn):
    assert checks.count_null_key_fields(conn) == 0
    assert checks.count_duplicate_primary_keys(conn) == 0


@requires_postgres
def test_orders_without_line_items_matches_known_value(conn):
    # 139 of 1,000 orders have no matching line items — expected, not a bug;
    # they're excluded from fact_sales by the join. A different count here
    # would mean the raw data or the load changed.
    assert checks.count_orders_without_line_items(conn) == 139


@requires_postgres
def test_duplicate_order_product_pairs_matches_known_value(conn):
    # 33 legitimate duplicate (order_id, product_id) pairs — real separate
    # order lines, not a data error. count_exact_duplicate_order_item_rows
    # confirms none of them are *fully* identical rows (which would be).
    assert checks.count_duplicate_order_product_pairs(conn) == 33
    assert checks.count_exact_duplicate_order_item_rows(conn) == 0


@requires_postgres
def test_orders_before_signup_matches_known_value(conn):
    # 55 orders predate the customer's signup_date — a known data anomaly,
    # not corrected (see notebooks/01 Section 8 for why).
    assert checks.count_orders_before_signup(conn) == 55


@requires_postgres
def test_fact_sales_completed_summary_matches_known_good_numbers(conn):
    summary = checks.fact_sales_completed_summary(conn)
    assert summary.line_items == 1625
    assert summary.distinct_orders == 695
    assert summary.total_revenue == pytest.approx(311111.00, abs=0.01)


@requires_postgres
def test_reconcile_reports_no_discrepancies(conn):
    assert checks.reconcile(conn) == []
