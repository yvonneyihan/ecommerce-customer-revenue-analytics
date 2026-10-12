# Extends the official Airflow image with:
#   - the postgresql client (psql, for sql/01_schema.sql via BashOperator)
#   - a SEPARATE virtualenv for dbt (/opt/dbt-venv), not installed into
#     Airflow's own site-packages.
#
# Why a separate venv: dbt-core pins its own versions of click/jinja2/etc.
# that routinely conflict with Airflow's own pinned dependency set --
# `pip install dbt-postgres` directly into the Airflow image is a common way
# to quietly break the webserver/scheduler. Isolating dbt in its own venv
# and invoking it as a subprocess (see dags/ecommerce_elt_dag.py) is the
# standard fix, and avoids pulling in heavier alternatives (a separate
# dbt container, KubernetesPodOperator) that this project doesn't need yet.
FROM apache/airflow:2.10.3-python3.12

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/dbt-venv \
    && chown airflow:root /opt/dbt-venv

USER airflow
RUN python -m venv /opt/dbt-venv \
    && /opt/dbt-venv/bin/pip install --no-cache-dir "dbt-postgres>=1.8" psycopg2-binary
