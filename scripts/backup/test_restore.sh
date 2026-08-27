#!/usr/bin/env bash
# =============================================================================
# NON-DESTRUCTIVE restore drill: restores the latest Postgres snapshot into
# a completely disposable, throwaway Postgres container (different name,
# different port, different volume — never touches the real environment)
# and runs a couple of sanity queries. This is the script the
# "Tests automatiques de restauration" checklist item and the monthly DR
# drill (docs/runbooks/disaster-recovery.md) actually run.
# =============================================================================
# shellcheck source=./_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

THROWAWAY_NAME="odoo-lab-restore-drill-$(date +%s)"
THROWAWAY_PORT=55432

cleanup() {
  log "tearing down the throwaway restore-drill container"
  docker rm -f "$THROWAWAY_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "restoring latest snapshot to local staging area"
restic restore latest --tag postgres --host odoo-lab --target /backup_source/restore
DUMP_PATH="$(find "${BACKUP_TMP}/restore" -name '*.dump' | sort | tail -1)"
[ -n "$DUMP_PATH" ] || { echo "no dump found in latest snapshot" >&2; exit 1; }
log "found dump: $(basename "$DUMP_PATH")"

log "starting a disposable Postgres to restore into"
docker run -d --name "$THROWAWAY_NAME" \
  -e POSTGRES_PASSWORD=throwaway \
  -p "127.0.0.1:${THROWAWAY_PORT}:5432" \
  postgres:16.4-alpine3.20 >/dev/null

log "waiting for it to accept connections"
for _ in $(seq 1 30); do
  docker exec "$THROWAWAY_NAME" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done

log "validating dump structure (pg_restore --list, no data touched yet)"
docker cp "$DUMP_PATH" "${THROWAWAY_NAME}:/tmp/dump.dump"
docker exec "$THROWAWAY_NAME" pg_restore --list /tmp/dump.dump > /dev/null

log "restoring into the throwaway instance"
docker exec "$THROWAWAY_NAME" psql -U postgres -c "CREATE DATABASE restore_drill;"
docker exec "$THROWAWAY_NAME" pg_restore -U postgres -d restore_drill --no-owner /tmp/dump.dump

log "sanity query: row count of a core Odoo table"
ROWS="$(docker exec "$THROWAWAY_NAME" psql -U postgres -d restore_drill -tAc "SELECT count(*) FROM res_users;")"
log "res_users row count in restored dump: ${ROWS}"
if [ "${ROWS:-0}" -lt 1 ]; then
  echo "[test-restore] SUSPICIOUS: restored dump has no users — investigate before trusting this backup" >&2
  exit 1
fi

rm -rf "${BACKUP_TMP}/restore"
log "restore drill PASSED — backup is restorable and structurally sane"
