#!/usr/bin/env bash
# Kills whichever Odoo color is currently active, to rehearse both the
# container-level auto-restart AND, if it doesn't come back healthy in
# time, the manual rollback/failover procedure in docs/runbooks/incident-response.md.
set -euo pipefail
ENVIRONMENT="${1:?usage: kill_odoo.sh <dev|staging|production>}"
PROJECT="odoo-lab-${ENVIRONMENT}"

TARGET="$(docker ps -q -f "name=${PROJECT}.*odoo-blue")"
[ -n "$TARGET" ] || TARGET="$(docker ps -q -f "name=${PROJECT}.*odoo-green")"
[ -n "$TARGET" ] || { echo "no running odoo container found for ${ENVIRONMENT}" >&2; exit 1; }

echo "[chaos] $(date -u +%FT%TZ) killing $(docker inspect -f '{{.Name}}' "$TARGET") in ${ENVIRONMENT}"
docker kill "$TARGET"
echo "[chaos] killed. Watch: OdooDown / OdooContainerRestartLoop alerts, and whether nginx correctly serves 502s (not silent hangs) while it's down."
