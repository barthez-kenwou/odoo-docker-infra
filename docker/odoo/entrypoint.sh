#!/usr/bin/env bash
# =============================================================================
# Entrypoint for the custom Odoo image.
#
# Responsibilities:
#   1. Wait for the database layer (PgBouncer -> Postgres) to accept connections.
#   2. Render /etc/odoo/odoo.conf from the checked-in template using envsubst,
#      so the image itself never bakes in an environment or a secret.
#   3. Exec Odoo as PID 1 (via `exec`) so it receives signals correctly and
#      Docker/Kubernetes can stop it gracefully.
# =============================================================================
set -euo pipefail

DB_HOST="${ODOO_DB_HOST:-pgbouncer}"
DB_PORT="${ODOO_DB_PORT:-6432}"
WAIT_TIMEOUT="${DB_WAIT_TIMEOUT:-60}"

log() { printf '[entrypoint] %s\n' "$*" >&2; }

wait_for_db() {
  log "waiting for database at ${DB_HOST}:${DB_PORT} (timeout: ${WAIT_TIMEOUT}s)"
  local waited=0
  until (echo > "/dev/tcp/${DB_HOST}/${DB_PORT}") >/dev/null 2>&1; do
    waited=$((waited + 1))
    if [ "${waited}" -ge "${WAIT_TIMEOUT}" ]; then
      log "ERROR: database not reachable after ${WAIT_TIMEOUT}s, aborting"
      exit 1
    fi
    sleep 1
  done
  log "database is reachable"
}

render_config() {
  log "rendering /etc/odoo/odoo.conf from template"
  # Only substitute variables we explicitly whitelist, so a stray "$" in a
  # password (unlikely, but let's be defensive) can't accidentally reference
  # an unrelated environment variable.
  # shellcheck disable=SC2016
  envsubst '${ODOO_DB_HOST} ${ODOO_DB_PORT} ${ODOO_DB_USER} ${ODOO_DB_PASSWORD} ${ODOO_DB_NAME} ${ODOO_ADMIN_PASSWD} ${ODOO_WORKERS} ${ODOO_MAX_CRON_THREADS} ${ODOO_LIMIT_MEMORY_SOFT} ${ODOO_LIMIT_MEMORY_HARD} ${ODOO_LIMIT_TIME_CPU} ${ODOO_LIMIT_TIME_REAL} ${ODOO_LIST_DB} ${ODOO_PROXY_MODE} ${ODOO_LOG_LEVEL}' \
    < /etc/odoo/odoo.conf.template > /tmp/odoo.conf
  # /etc/odoo is read-only at runtime (see docker-compose read_only + tmpfs),
  # so the rendered file lives in the writable /tmp overlay and is passed
  # explicitly via -c instead of relying on the default lookup path.
}

wait_for_db
render_config

log "starting odoo"
exec odoo -c /tmp/odoo.conf "$@"
