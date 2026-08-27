#!/bin/sh
# =============================================================================
# Sets up PgBouncer's `auth_query` authentication path, which is the
# recommended way to run PgBouncer against SCRAM-authenticated Postgres
# without ever storing every application user's password hash in a static
# file (see https://www.pgbouncer.org/config.html#auth_query).
#
# 1. Create a dedicated, unprivileged `pgbouncer_auth` role.
# 2. Give it a SECURITY DEFINER lookup function instead of direct SELECT on
#    pg_shadow (pg_shadow is only readable by superusers; the function runs
#    with the privileges of its owner, not its caller).
# 3. Because *this* role's own hash can't itself come from an auth_query
#    (chicken-and-egg), write it once, here, at DB-init time, into a small
#    shared volume that the pgbouncer container mounts read-only as its
#    `auth_file`. The plaintext password is never written to disk anywhere.
# =============================================================================
set -eu

: "${PGBOUNCER_AUTH_PASSWORD:?PGBOUNCER_AUTH_PASSWORD must be set}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
    CREATE ROLE pgbouncer_auth WITH LOGIN PASSWORD '${PGBOUNCER_AUTH_PASSWORD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

    CREATE SCHEMA IF NOT EXISTS pgbouncer AUTHORIZATION postgres;

    CREATE OR REPLACE FUNCTION pgbouncer.user_lookup(in i_username text, out uname text, out phash text)
    RETURNS record AS \$\$
    BEGIN
        SELECT usename, passwd FROM pg_shadow WHERE usename = i_username INTO uname, phash;
        RETURN;
    END;
    \$\$ LANGUAGE plpgsql SECURITY DEFINER;

    REVOKE ALL ON FUNCTION pgbouncer.user_lookup(text) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION pgbouncer.user_lookup(text) TO pgbouncer_auth;
EOSQL

# One-time export of pgbouncer_auth's own SCRAM secret so pgbouncer can
# authenticate itself before it's able to run auth_query for everyone else.
mkdir -p /pgbouncer-userlist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -tAc \
    "SELECT '\"pgbouncer_auth\" \"' || passwd || '\"' FROM pg_shadow WHERE usename='pgbouncer_auth'" \
    > /pgbouncer-userlist/userlist.txt
chmod 0600 /pgbouncer-userlist/userlist.txt

echo "[init] pgbouncer auth_query role + shared userlist.txt provisioned"
