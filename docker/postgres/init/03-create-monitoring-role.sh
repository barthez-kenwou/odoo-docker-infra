#!/bin/sh
# =============================================================================
# Least-privilege role for postgres_exporter: PostgreSQL's built-in
# `pg_monitor` predefined role grants read access to monitoring views only
# (pg_stat_activity, pg_stat_statements, etc.) — no data access whatsoever.
# =============================================================================
set -eu
: "${PG_EXPORTER_PASSWORD:?PG_EXPORTER_PASSWORD must be set}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
    CREATE ROLE pg_exporter WITH LOGIN PASSWORD '${PG_EXPORTER_PASSWORD}' NOSUPERUSER NOCREATEDB NOCREATEROLE CONNECTION LIMIT 5;
    GRANT pg_monitor TO pg_exporter;
EOSQL

echo "[init] pg_exporter monitoring role created (pg_monitor, read-only views)"
