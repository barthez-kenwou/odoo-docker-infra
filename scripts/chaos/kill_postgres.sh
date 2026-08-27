#!/usr/bin/env bash
# =============================================================================
# Chaos drill: kills the Postgres container without warning and prints a
# timestamp, so you can measure actual detection-to-recovery time against
# the RTO documented in docs/runbooks/disaster-recovery.md. Postgres is
# expected to come back via `restart: unless-stopped`; the point of this
# drill is to verify: (1) Prometheus/Alertmanager actually page within a
# few minutes (PostgresDown alert), and (2) Odoo/PgBouncer recover on their
# own once Postgres is back, with no manual intervention needed.
# =============================================================================
set -euo pipefail
ENVIRONMENT="${1:?usage: kill_postgres.sh <dev|staging|production>}"
PROJECT="odoo-lab-${ENVIRONMENT}"

echo "[chaos] $(date -u +%FT%TZ) killing postgres in ${ENVIRONMENT} — watch Grafana/Alertmanager now"
docker kill "$(docker ps -q -f "name=${PROJECT}.*postgres")"
echo "[chaos] killed. Expected: PostgresDown alert fires within ~1-2 minutes (see monitoring/prometheus/alerts/postgres.rules.yml), container auto-restarts via its restart policy."
