#!/usr/bin/env bash
# =============================================================================
# Flip nginx back to the previously active color. Fast — no image pull, no
# migration — because the old color's container was deliberately kept warm
# by deploy.sh instead of being torn down immediately.
# =============================================================================
set -euo pipefail

ENVIRONMENT="${1:?usage: rollback.sh <dev|staging|production>}"
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../compose" && pwd)"
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../envs" && pwd)/${ENVIRONMENT}.env"
PROJECT="odoo-lab-${ENVIRONMENT}"

compose() {
  docker compose --env-file "$ENV_FILE" -p "$PROJECT" \
    -f "${COMPOSE_DIR}/docker-compose.base.yml" \
    -f "${COMPOSE_DIR}/docker-compose.${ENVIRONMENT}.yml" \
    "$@"
}

PREVIOUS_FILE="/tmp/odoo-lab-${ENVIRONMENT}-previous-color"
if [ ! -f "$PREVIOUS_FILE" ]; then
  echo "[rollback:${ENVIRONMENT}] no recorded previous color — check docs/runbooks/rollback.md for the manual procedure" >&2
  exit 1
fi
PREVIOUS_COLOR="$(cat "$PREVIOUS_FILE")"

echo "[rollback:${ENVIRONMENT}] rolling back to '${PREVIOUS_COLOR}'"
compose up -d "odoo-${PREVIOUS_COLOR}"
sleep 5
compose exec -T nginx sh -c "printf 'upstream odoo_active {\n    server odoo-${PREVIOUS_COLOR}:8069;\n}\n' > /etc/nginx/active/active_upstream.conf"
compose exec -T nginx nginx -s reload

echo "[rollback:${ENVIRONMENT}] rolled back to '${PREVIOUS_COLOR}'. Investigate the failed deploy before trying again — see docs/runbooks/incident-response.md."
