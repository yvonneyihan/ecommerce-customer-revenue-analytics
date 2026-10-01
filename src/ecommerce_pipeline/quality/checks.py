"""
Automated data-quality and reconciliation checks.

Ports the manual profiling done once, by hand, in
notebooks/01_data_cleaning_validation.ipynb (Sections 3-8 and 13) into
reusable functions that run as SQL against whatever Postgres database `conn`
points at -- so they can be asserted in pytest (see tests/test_quality.py)
and, later, run as an Airflow task that fails a DAG run on a real anomaly
instead of relying on someone rereading a notebook.

Each function assumes customers/products/orders/order_items are already
loaded (e.g. via sql/01-02 or ecommerce_pipeline.ingestion.load_csv), and
`fact_sales_completed`-dependent checks additionally assume sql/03_fact_sales.sql
has been run.

KNOWN_GOOD holds this dataset's documented, verified values (see
README.md's "Data quality findings" section) -- it's what reconcile()
compares live results against. It is specific to this one dataset snapshot,
not a general-purpose expectation: a genuinely new data drop should update
KNOWN_GOOD deliberately (and explain why), not have reconcile() silently
redefined around it.
"""

from dataclasses import dataclass
from typing import Any, Callable, Dict


def _scalar(conn, sql: str):
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchone()[0]


def count_orphaned_orders(conn) -> int:
    """Orders whose customer_id has no matching row in customers."""
    return _scalar(
        conn,
        """
        SELECT COUNT(*) FROM orders o
        LEFT JOIN customers c ON c.customer_id = o.customer_id
        WHERE c.customer_id IS NULL
        """,
    )


def count_orphaned_order_items_order_id(conn) -> int:
    """order_items whose order_id has no matching row in orders."""
    return _scalar(
        conn,
        """
        SELECT COUNT(*) FROM order_items oi
        LEFT JOIN orders o ON o.order_id = oi.order_id
        WHERE o.order_id IS NULL
        """,
    )


def count_orphaned_order_items_product_id(conn) -> int:
    """order_items whose product_id has no matching row in products."""
    return _scalar(
        conn,
        """
        SELECT COUNT(*) FROM order_items oi
        LEFT JOIN products p ON p.product_id = oi.product_id
        WHERE p.product_id IS NULL
        """,
    )


def count_null_key_fields(conn) -> int:
    """NULLs in any required (non-nullable-by-business-rule) column across all four tables."""
    return _scalar(
        conn,
        """
        SELECT
            (SELECT COUNT(*) FROM customers
                WHERE customer_id IS NULL OR country IS NULL OR signup_date IS NULL) +
            (SELECT COUNT(*) FROM products
                WHERE product_id IS NULL OR product_name IS NULL OR category IS NULL) +
            (SELECT COUNT(*) FROM orders
                WHERE order_id IS NULL OR customer_id IS NULL OR order_date IS NULL OR status IS NULL) +
            (SELECT COUNT(*) FROM order_items
                WHERE order_id IS NULL OR product_id IS NULL OR quantity IS NULL OR price IS NULL)
        """,
    )


def count_duplicate_primary_keys(conn) -> int:
    """Excess rows beyond one-per-key for each table's primary key."""
    return _scalar(
        conn,
        """
        SELECT
            (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM customers) +
            (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM products) +
            (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM orders)
        """,
    )


def count_orders_without_line_items(conn) -> int:
    """Orders with no matching order_items row -- excluded from fact_sales by the join, not silently."""
    return _scalar(
        conn,
        """
        SELECT COUNT(*) FROM orders o
        LEFT JOIN order_items oi ON oi.order_id = o.order_id
        WHERE oi.order_id IS NULL
        """,
    )


def count_duplicate_order_product_pairs(conn) -> int:
    """(order_id, product_id) pairs appearing more than once in order_items -- legitimate separate lines, not an error."""
    return _scalar(
        conn,
        """
        SELECT COUNT(*) FROM (
            SELECT order_id, product_id FROM order_items
            GROUP BY order_id, product_id HAVING COUNT(*) > 1
        ) dupes
        """,
    )


def count_exact_duplicate_order_item_rows(conn) -> int:
    """Fully identical order_items rows (same order_id, product_id, quantity, price) -- would indicate a real load bug."""
    return _scalar(
        conn,
        """
        SELECT COALESCE(SUM(cnt - 1), 0) FROM (
            SELECT COUNT(*) AS cnt FROM order_items
            GROUP BY order_id, product_id, quantity, price HAVING COUNT(*) > 1
        ) dupes
        """,
    )


def count_orders_before_signup(conn) -> int:
    """Orders whose order_date predates the customer's signup_date -- a known data anomaly, not corrected."""
    return _scalar(
        conn,
        """
        SELECT COUNT(*) FROM orders o
        JOIN customers c ON c.customer_id = o.customer_id
        WHERE o.order_date < c.signup_date
        """,
    )


@dataclass
class FactSalesSummary:
    line_items: int
    distinct_orders: int
    total_revenue: float


def fact_sales_completed_summary(conn) -> FactSalesSummary:
    """Requires fact_sales_completed (sql/03_fact_sales.sql) to already exist."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*), COUNT(DISTINCT order_id), SUM(revenue)
            FROM fact_sales_completed
            """
        )
        line_items, distinct_orders, total_revenue = cur.fetchone()
    return FactSalesSummary(line_items, distinct_orders, float(total_revenue))


# Documented, verified values for this dataset -- see README.md "Data quality
# findings" and reports/findings.md.
KNOWN_GOOD: Dict[str, Any] = {
    "orphaned_orders": 0,
    "orphaned_order_items_order_id": 0,
    "orphaned_order_items_product_id": 0,
    "null_key_fields": 0,
    "duplicate_primary_keys": 0,
    "orders_without_line_items": 139,
    "duplicate_order_product_pairs": 33,
    "exact_duplicate_order_item_rows": 0,
    "orders_before_signup": 55,
}

_SCALAR_CHECKS: Dict[str, Callable[[Any], int]] = {
    "orphaned_orders": count_orphaned_orders,
    "orphaned_order_items_order_id": count_orphaned_order_items_order_id,
    "orphaned_order_items_product_id": count_orphaned_order_items_product_id,
    "null_key_fields": count_null_key_fields,
    "duplicate_primary_keys": count_duplicate_primary_keys,
    "orders_without_line_items": count_orders_without_line_items,
    "duplicate_order_product_pairs": count_duplicate_order_product_pairs,
    "exact_duplicate_order_item_rows": count_exact_duplicate_order_item_rows,
    "orders_before_signup": count_orders_before_signup,
}


@dataclass
class Discrepancy:
    check: str
    expected: Any
    actual: Any


def reconcile(conn, include_fact_sales: bool = True) -> list:
    """
    Runs every check and compares against KNOWN_GOOD (plus the
    fact_sales_completed summary, if include_fact_sales). Returns a list of
    Discrepancy for anything that didn't match -- empty list means a clean
    reconciliation.
    """
    discrepancies = []
    for name, check_fn in _SCALAR_CHECKS.items():
        actual = check_fn(conn)
        expected = KNOWN_GOOD[name]
        if actual != expected:
            discrepancies.append(Discrepancy(name, expected, actual))

    if include_fact_sales:
        summary = fact_sales_completed_summary(conn)
        expected_fact_sales = {
            "fact_sales_completed_line_items": 1625,
            "fact_sales_completed_distinct_orders": 695,
            "fact_sales_completed_total_revenue": 311111.00,
        }
        actual_fact_sales = {
            "fact_sales_completed_line_items": summary.line_items,
            "fact_sales_completed_distinct_orders": summary.distinct_orders,
            "fact_sales_completed_total_revenue": summary.total_revenue,
        }
        for name, expected in expected_fact_sales.items():
            actual = actual_fact_sales[name]
            if isinstance(expected, float):
                if abs(actual - expected) > 0.01:
                    discrepancies.append(Discrepancy(name, expected, actual))
            elif actual != expected:
                discrepancies.append(Discrepancy(name, expected, actual))

    return discrepancies


if __name__ == "__main__":
    import psycopg2

    from ecommerce_pipeline.config import get_database_url

    conn = psycopg2.connect(get_database_url())
    try:
        issues = reconcile(conn)
    finally:
        conn.close()

    if not issues:
        print("Reconciliation OK — all checks match known-good values.")
    else:
        print(f"Reconciliation FAILED — {len(issues)} discrepancy(ies):")
        for d in issues:
            print(f"  {d.check}: expected {d.expected!r}, got {d.actual!r}")
        raise SystemExit(1)
