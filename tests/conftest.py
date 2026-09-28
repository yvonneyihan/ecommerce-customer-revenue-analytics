import subprocess

import psycopg2
import pytest

from ecommerce_pipeline.config import PROJECT_ROOT, get_database_url


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


def run_sql_file(relative_path: str) -> None:
    result = subprocess.run(
        ["psql", get_database_url(), "-v", "ON_ERROR_STOP=1", "-f", relative_path],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"{relative_path} failed:\n{result.stderr}"


@pytest.fixture
def fresh_schema():
    """Drops and recreates customers/products/orders/order_items from sql/01_schema.sql."""
    run_sql_file("sql/01_schema.sql")
