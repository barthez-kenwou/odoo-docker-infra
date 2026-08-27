#!/usr/bin/env bash
# =============================================================================
# Backs up Odoo's filestore (attachments, uploaded documents — everything
# that lives on disk rather than in Postgres). Tarred from the named Docker
# volume via a throwaway alpine container, then pushed to restic just like
# the database dump, under a shared tag so `restore_filestore.sh` and
# `test_restore.sh` can find the matching pair for a given timestamp.
# =============================================================================
# shellcheck source=./_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

restic_init_if_needed

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE_NAME="odoo_filestore_${ENVIRONMENT}_${TIMESTAMP}.tar.gz"
VOLUME_NAME="${VOLUME_ODOO_FILESTORE}"

log "archiving filestore volume '${VOLUME_NAME}'"
docker run --rm \
  -v "${VOLUME_NAME}:/source:ro" \
  -v "${BACKUP_TMP}:/dest" \
  alpine:3.20.2 \
  tar -czf "/dest/${ARCHIVE_NAME}" -C /source .

log "pushing to restic repository"
restic backup "/backup_source/${ARCHIVE_NAME}" --tag filestore --tag "${ENVIRONMENT}" --host odoo-lab

log "applying retention policy"
restic forget --tag filestore --host odoo-lab --keep-daily 30 --keep-weekly 8 --keep-monthly 12 --prune

log "cleaning up local archive"
rm -f "${BACKUP_TMP}/${ARCHIVE_NAME}"

log "backup complete: ${ARCHIVE_NAME}"
