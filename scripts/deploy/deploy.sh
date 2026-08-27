#!/usr/bin/env bash
# =============================================================================
# Blue/green deploy for one environment. See docs/adr/0005 for the design
# rationale. Steps:
#   1. Figure out which color is currently active (from nginx's active
#      upstream file) and which is idle.
#   2. Start the idle color with the new image/config, wait for its
#      healthcheck to go green.
#   3. Run smoke tests against the idle color directly (bypassing nginx).
#   4. Flip nginx's upstream to the idle color and reload (zero downtime).
#   5. Run smoke tests again through nginx, at the public URL.
#   6. Stop the now-idle (old) color. Keep it stoppable-but-present for a
#      fast rollback window (see rollback.sh) rather than removing it.
# =============================================================================
set -euo pipefail

ENVIRONMENT="${1:?usage: deploy.sh <dev|staging|production>}"
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../compose" && pwd)"
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../envs" && pwd)/${ENVIRONMENT}.env"
PROJECT="odoo-lab-${ENVIRONMENT}"

# shellcheck disable=SC1090
compose() {
  docker compose --env-file "$ENV_FILE" -p "$PROJECT" \
    -f "${COMPOSE_DIR}/docker-compose.base.yml" \
    -f "${COMPOSE_DIR}/docker-compose.${ENVIRONMENT}.yml" \
    "$@"
}

log() { printf '[deploy:%s] %s\n' "$ENVIRONMENT" "$*"; }

current_color() {
  # Reads which color nginx currently proxies to, from inside the running
  # container (source of truth, not our own memory of a previous deploy).
  compose exec -T nginx cat /etc/nginx/active/active_upstream.conf 2>/dev/null \
    | grep -oE 'odoo-(blue|green)' | head -1 | sed 's/odoo-//' || echo "blue"
}

idle_of() { [ "$1" = "blue" ] && echo "green" || echo "blue"; }

wait_healthy() {
  local service="$1" timeout="${2:-120}" waited=0
  until [ "$(compose ps -q "$service" | xargs -r docker inspect -f '{{.State.Health.Status}}' 2>/dev/null)" = "healthy" ]; do
    waited=$((waited + 5))
    if [ "$waited" -ge "$timeout" ]; then
      log "ERROR: $service did not become healthy within ${timeout}s"
      return 1
    fi
    sleep 5
  done
}

ACTIVE="$(current_color)"
IDLE="$(idle_of "$ACTIVE")"
log "active color is '${ACTIVE}', deploying to idle color '${IDLE}'"

log "pulling images (or building locally for dev)"
if [ "$ENVIRONMENT" = "dev" ]; then
  compose build "odoo-${IDLE}"
else
  compose pull "odoo-${IDLE}" nginx postgres pgbouncer
fi

log "starting postgres/pgbouncer (idempotent — no-op if already running)"
compose up -d postgres pgbouncer
wait_healthy pgbouncer 60

log "starting idle color: odoo-${IDLE}"
compose --profile green up -d "odoo-${IDLE}"
wait_healthy "odoo-${IDLE}" 120

log "running database migrations against the idle color (see docs/runbooks/deployment.md)"
compose exec -T "odoo-${IDLE}" odoo -d "${ODOO_DB_NAME:-odoo}" -u lab_demo_module --stop-after-init

log "smoke-testing the idle color directly (bypassing nginx)"
compose exec -T "odoo-${IDLE}" curl -fsS "http://localhost:8069/web/login" -o /dev/null

log "flipping nginx to point at odoo-${IDLE}"
compose exec -T nginx sh -c "printf 'upstream odoo_active {\n    server odoo-${IDLE}:8069;\n}\n' > /etc/nginx/active/active_upstream.conf"
compose exec -T nginx nginx -s reload

log "post-flip smoke test through nginx"
"$(dirname "${BASH_SOURCE[0]}")/smoke_test.sh" "$ENVIRONMENT"

log "deploy succeeded — ${IDLE} is now active, ${ACTIVE} kept warm for fast rollback"
echo "$ACTIVE" > "/tmp/odoo-lab-${ENVIRONMENT}-previous-color"

log "done."
