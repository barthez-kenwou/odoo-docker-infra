#!/usr/bin/env bash
# =============================================================================
# Waits for Postgres's init scripts to have published the shared auth_file
# (see docker/postgres/init/02-create-pgbouncer-auth.sh), renders
# pgbouncer.ini from its template, then execs pgbouncer as PID 1.
# =============================================================================
set -euo pipefail

AUTH_FILE="/pgbouncer-userlist/userlist.txt"
TIMEOUT="${AUTH_FILE_WAIT_TIMEOUT:-60}"

log() { printf '[pgbouncer-entrypoint] %s\n' "$*" >&2; }

waited=0
until [ -s "$AUTH_FILE" ]; do
  waited=$((waited + 1))
  if [ "$waited" -ge "$TIMEOUT" ]; then
    log "ERROR: $AUTH_FILE not populated by postgres after ${TIMEOUT}s"
    exit 1
  fi
  sleep 1
done
log "auth_file ready"

# shellcheck disable=SC2016
envsubst '${ODOO_DB_NAME} ${POSTGRES_HOST}' \
  < /etc/pgbouncer/pgbouncer.ini.template > /tmp/pgbouncer.ini

log "starting pgbouncer"
exec pgbouncer /tmp/pgbouncer.ini
