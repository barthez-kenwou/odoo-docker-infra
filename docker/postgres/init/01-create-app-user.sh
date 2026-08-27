#!/bin/sh
# =============================================================================
# Runs once, on first initialization of an empty data directory, as the
# bootstrap superuser (POSTGRES_USER, default "postgres"). Creates a
# dedicated, least-privilege role for Odoo instead of letting the app talk to
# the database as a superuser.
# =============================================================================
set -eu

: "${ODOO_DB_USER:?ODOO_DB_USER must be set}"
: "${ODOO_DB_PASSWORD:?ODOO_DB_PASSWORD must be set}"
: "${ODOO_DB_NAME:?ODOO_DB_NAME must be set}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
    -- Dedicated login role for Odoo. Deliberately NOT a superuser and
    -- deliberately NOT CREATEDB: the single application database is
    -- pre-created below and dbfilter in odoo.conf pins Odoo to it, so Odoo
    -- never needs the privilege to create/drop arbitrary databases.
    CREATE ROLE "${ODOO_DB_USER}" WITH LOGIN PASSWORD '${ODOO_DB_PASSWORD}'
        NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 200;

    CREATE DATABASE "${ODOO_DB_NAME}" OWNER "${ODOO_DB_USER}" ENCODING 'UTF8';

    REVOKE ALL PRIVILEGES ON DATABASE "${ODOO_DB_NAME}" FROM PUBLIC;
    GRANT ALL PRIVILEGES ON DATABASE "${ODOO_DB_NAME}" TO "${ODOO_DB_USER}";
EOSQL

echo "[init] dedicated role '${ODOO_DB_USER}' and database '${ODOO_DB_NAME}' created"
