"""
Orchestrates the full ELT pipeline: create schema -> ingest -> dbt build -> reconcile.

Runs inside the airflow-scheduler container (see docker-compose.yml), where
sql/, data/, dbt/, and src/ are bind-mounted at /opt/airflow/project/{...}.
POSTGRES_HOST/PORT/DATABASE_URL are set by docker-compose.yml's
airflow-common-env to point at the `postgres` service's in-network address
(postgres:5432) -- NOT the host-facing localhost:5433 from .env, since this
DAG runs inside the compose network, not on the host.

dbt runs via the separate /opt/dbt-venv virtualenv built in airflow/Dockerfile
(kept apart from Airflow's own dependencies -- see that file's comment).
"""

import pendulum
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

PROJECT_ROOT = "/opt/airflow/project"
DBT_PROJECT_DIR = f"{PROJECT_ROOT}/dbt/ecommerce"
DBT_VENV_DBT = "/opt/dbt-venv/bin/dbt"


def _run_ingestion():
    import sys
    from pathlib import Path

    sys.path.insert(0, f"{PROJECT_ROOT}/src")
    from ecommerce_pipeline.ingestion.load_csv import run_ingestion

    counts = run_ingestion(csv_dir=Path(f"{PROJECT_ROOT}/data/raw"))
    print(f"Ingested: {counts}")


def _reconcile():
    import sys

    sys.path.insert(0, f"{PROJECT_ROOT}/src")
    import psycopg2
    from ecommerce_pipeline.config import get_database_url
    from ecommerce_pipeline.quality.checks import reconcile

    conn = psycopg2.connect(get_database_url())
    try:
        # This pipeline builds intermediate.int_fact_sales_completed via dbt,
        # not the legacy public.fact_sales_completed view from sql/03 --
        # reconcile() defaults to the latter, so it's overridden here.
        issues = reconcile(conn, fact_sales_table="intermediate.int_fact_sales_completed")
    finally:
        conn.close()
    if issues:
        raise ValueError(f"Reconciliation failed: {issues}")
    print("Reconciliation OK")


with DAG(
    dag_id="ecommerce_elt",
    description="create schema -> ingest CSVs -> dbt build -> reconcile",
    schedule=None,  # triggered manually -- the source dataset is a static snapshot, not a live feed
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    tags=["ecommerce", "elt"],
) as dag:

    create_schema = BashOperator(
        task_id="create_schema",
        bash_command=f'psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f {PROJECT_ROOT}/sql/01_schema.sql',
    )

    ingest_data = PythonOperator(
        task_id="ingest_data",
        python_callable=_run_ingestion,
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"{DBT_VENV_DBT} build --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}",
    )

    reconcile_data = PythonOperator(
        task_id="reconcile",
        python_callable=_reconcile,
    )

    create_schema >> ingest_data >> dbt_build >> reconcile_data
