# Sourced by every script in this directory — not executable on its own.
# Loads the right env file, wires up `compose()` and `restic()` helpers.
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:?set ENVIRONMENT=dev|staging|production}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/envs/${ENVIRONMENT}.env"
COMPOSE_DIR="${REPO_ROOT}/compose"
PROJECT="odoo-lab-${ENVIRONMENT}"
BACKUP_TMP="${REPO_ROOT}/backups/tmp"
RESTIC_IMAGE="restic/restic:0.17.1"

[ -f "$ENV_FILE" ] || { echo "missing ${ENV_FILE} — see envs/README.md" >&2; exit 1; }
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
mkdir -p "$BACKUP_TMP"

compose() {
  docker compose --env-file "$ENV_FILE" -p "$PROJECT" \
    -f "${COMPOSE_DIR}/docker-compose.base.yml" \
    -f "${COMPOSE_DIR}/docker-compose.${ENVIRONMENT}.yml" \
    "$@"
}

restic() {
  : "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY not set in envs/${ENVIRONMENT}.env}"
  : "${RESTIC_PASSWORD:?RESTIC_PASSWORD not set in envs/${ENVIRONMENT}.env}"
  docker run --rm \
    -e RESTIC_REPOSITORY="$RESTIC_REPOSITORY" \
    -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
    -v "${BACKUP_TMP}:/backup_source" \
    "$RESTIC_IMAGE" "$@"
}

restic_init_if_needed() {
  restic snapshots >/dev/null 2>&1 || { echo "[backup] initializing new restic repository"; restic init; }
}

log() { printf '[backup:%s] %s\n' "$ENVIRONMENT" "$*"; }
