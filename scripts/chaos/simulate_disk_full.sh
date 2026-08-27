#!/usr/bin/env bash
# =============================================================================
# Fills the Postgres data volume to ~95% capacity using a throwaway file, to
# rehearse the DiskAlmostFull alert and the documented response (see
# docs/runbooks/troubleshooting.md#disk-full). ALWAYS removes the filler
# file in a trap, even on Ctrl-C, so this never actually leaves a volume full.
# =============================================================================
set -euo pipefail
ENVIRONMENT="${1:?usage: simulate_disk_full.sh <dev|staging|production>}"
VOLUME_NAME="odoo-lab-${ENVIRONMENT}-postgres-data"
FILLER="/var/lib/postgresql/data/.chaos_filler"

cleanup() {
  echo "[chaos] removing filler file"
  docker run --rm -v "${VOLUME_NAME}:/data" alpine:3.20.2 rm -f "/data/.chaos_filler" || true
}
trap cleanup EXIT INT TERM

echo "[chaos] $(date -u +%FT%TZ) filling ${VOLUME_NAME} to simulate near-full disk"
docker run --rm -v "${VOLUME_NAME}:/data" alpine:3.20.2 sh -c '
  avail=$(df --output=avail /data | tail -1)
  target_kb=$(( avail * 90 / 100 ))
  fallocate -l "${target_kb}K" /data/.chaos_filler
'
echo "[chaos] filler in place. Watch the DiskAlmostFull alert fire, then Ctrl-C or wait — cleanup runs automatically."
sleep 300
