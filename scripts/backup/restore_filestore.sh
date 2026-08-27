#!/usr/bin/env bash
# =============================================================================
# DESTRUCTIVE: restores the most recent filestore archive over the live
# volume for $ENVIRONMENT. Run restore_postgres.sh in the same maintenance
# window so the DB and filestore stay consistent with each other (checklist
# item: "Vérification de cohérence PostgreSQL + filestore").
# =============================================================================
# shellcheck source=./_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo "!!! This will OVERWRITE the Odoo filestore volume in '${ENVIRONMENT}' !!!"
read -r -p "Type '${ENVIRONMENT}' to confirm: " CONFIRM
[ "$CONFIRM" = "$ENVIRONMENT" ] || { echo "aborted"; exit 1; }

log "restoring latest filestore snapshot to local staging area"
restic restore latest --tag filestore --host odoo-lab --target /backup_source/restore

ARCHIVE_PATH="$(find "${BACKUP_TMP}/restore" -name 'odoo_filestore_*.tar.gz' | sort | tail -1)"
[ -n "$ARCHIVE_PATH" ] || { echo "no filestore archive found in the restored snapshot" >&2; exit 1; }

log "wiping and repopulating the filestore volume '${VOLUME_ODOO_FILESTORE}'"
docker run --rm \
  -v "${VOLUME_ODOO_FILESTORE}:/target" \
  -v "$(dirname "$ARCHIVE_PATH"):/source:ro" \
  alpine:3.20.2 \
  sh -c "rm -rf /target/* && tar -xzf /source/$(basename "$ARCHIVE_PATH") -C /target"

rm -rf "${BACKUP_TMP}/restore"

log "restart odoo to pick up the restored filestore"
compose restart odoo-blue

log "filestore restore complete"
