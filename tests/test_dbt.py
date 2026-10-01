"""
Runs the dbt project (dbt/ecommerce) end-to-end and checks the resulting
marts.headline_kpis matches the same known-good numbers the SQL/notebook
layers produce (see README.md "Data quality findings").

Requires Postgres reachable and dbt installed (dbt-core/dbt-postgres are in
requirements-dev.txt). Skipped automatically if Postgres isn't reachable.
"""

import subprocess
import sys
from pathlib import Path

import psycopg2
import pytest

from ecommerce_pipeline.config import PROJECT_ROOT, get_database_url
from tests.conftest import requires_postgres

DBT_PROJECT_DIR = PROJECT_ROOT / "dbt" / "ecommerce"
DBT_BIN = Path(sys.executable).parent / "dbt"


@requires_postgres
def test_dbt_build_succeeds_and_reconciles(loaded_database):
    result = subprocess.run(
        [
            str(DBT_BIN),
            "build",
            "--project-dir", str(DBT_PROJECT_DIR),
            "--profiles-dir", str(DBT_PROJECT_DIR),
        ],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"dbt build failed:\n{result.stdout}\n{result.stderr}"

    conn = psycopg2.connect(get_database_url())
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT total_revenue, total_orders, overall_aov, repeat_purchase_rate_pct
                FROM marts.headline_kpis
                """
            )
            total_revenue, total_orders, overall_aov, repeat_rate = cur.fetchone()
            assert float(total_revenue) == pytest.approx(311111.00, abs=0.01)
            assert total_orders == 695
            assert float(overall_aov) == pytest.approx(447.64, abs=0.01)
            assert float(repeat_rate) == pytest.approx(73.4, abs=0.1)
    finally:
        conn.close()
