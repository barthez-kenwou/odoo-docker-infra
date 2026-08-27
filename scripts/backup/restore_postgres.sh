#!/usr/bin/env bash
# =============================================================================
# DESTRUCTIVE: restores the most recent Postgres snapshot over the live
# database for $ENVIRONMENT. Requires typing the environment name back to
# confirm. For a non-destructive dry run, use test_restore.sh instead.
# See docs/runbooks/disaster-recovery.md for the full incident procedure.
# =============================================================================
# shellcheck source=./_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo "!!! This will OVERWRITE the '${ODOO_DB_NAME}' database in '${ENVIRONMENT}' !!!"
read -r -p "Type '${ENVIRONMENT}' to confirm: " CONFIRM
[ "$CONFIRM" = "$ENVIRONMENT" ] || { echo "aborted"; exit 1; }

log "finding latest postgres snapshot"
LATEST_SNAPSHOT_FILE="$(restic snapshots --tag postgres --host odoo-lab --json \
  | python3 -c "import json,sys; s=json.load(sys.stdin); print(sorted(s, key=lambda x: x['time'])[-1]['paths'][0])")"

log "restoring snapshot content to local staging area"
restic restore latest --tag postgres --host odoo-lab --target /backup_source/restore

DUMP_FILE="$(basename "$LATEST_SNAPSHOT_FILE")"
compose cp "${BACKUP_TMP}/restore/backup_source/${DUMP_FILE}" "postgres:/tmp/${DUMP_FILE}"

log "putting the app into maintenance (stopping both odoo colors)"
compose stop odoo-blue odoo-green 2>/dev/null || true

log "dropping and recreating the target database"
compose exec -T postgres psql -U "${POSTGRES_SUPERUSER}" -d postgres -c "DROP DATABASE IF EXISTS ${ODOO_DB_NAME};"
compose exec -T postgres psql -U "${POSTGRES_SUPERUSER}" -d postgres -c "CREATE DATABASE ${ODOO_DB_NAME} OWNER ${ODOO_DB_USER};"

log "restoring the dump"
compose exec -T postgres pg_restore -U "${POSTGRES_SUPERUSER}" -d "${ODOO_DB_NAME}" --no-owner --role="${ODOO_DB_USER}" "/tmp/${DUMP_FILE}"
compose exec -T postgres rm -f "/tmp/${DUMP_FILE}"
rm -rf "${BACKUP_TMP}/restore"

log "restarting the app"
compose up -d odoo-blue

log "restore complete — run smoke_test.sh, then check docs/runbooks/disaster-recovery.md for post-restore validation steps"
