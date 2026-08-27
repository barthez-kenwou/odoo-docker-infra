#!/usr/bin/env bash
# =============================================================================
# Logical (pg_dump, custom format) backup of the Odoo database, pushed into
# the restic repository: encrypted client-side, deduplicated, versioned, and
# (once terraform/modules/object_storage is applied) stored on an
# Object-Lock-eligible immutable S3 bucket. Run daily via cron/systemd timer
# (see docs/runbooks/backup-restore.md for the unit files) or `make backup`.
# =============================================================================
# shellcheck source=./_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

restic_init_if_needed

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DUMP_NAME="odoo_${ENVIRONMENT}_${TIMESTAMP}.dump"

log "dumping database '${ODOO_DB_NAME}' (custom format, compressed)"
compose exec -T postgres pg_dump -U "${ODOO_DB_USER}" -d "${ODOO_DB_NAME}" -F c -Z 6 -f "/tmp/${DUMP_NAME}"

log "copying dump out of the container"
compose cp "postgres:/tmp/${DUMP_NAME}" "${BACKUP_TMP}/${DUMP_NAME}"
compose exec -T postgres rm -f "/tmp/${DUMP_NAME}"

log "pushing to restic repository"
restic backup "/backup_source/${DUMP_NAME}" --tag postgres --tag "${ENVIRONMENT}" --host odoo-lab

log "applying retention policy (3-2-1: 30 daily / 8 weekly / 12 monthly)"
restic forget --tag postgres --host odoo-lab --keep-daily 30 --keep-weekly 8 --keep-monthly 12 --prune

log "cleaning up local plaintext dump"
shred -u "${BACKUP_TMP}/${DUMP_NAME}" 2>/dev/null || rm -f "${BACKUP_TMP}/${DUMP_NAME}"

log "checking repository integrity (cheap check, no full data read)"
restic check

log "backup complete: ${DUMP_NAME}"
