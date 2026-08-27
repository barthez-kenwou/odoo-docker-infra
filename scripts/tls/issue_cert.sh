#!/usr/bin/env bash
# =============================================================================
# Issues (or renews) the TLS certificate for one environment.
#   dev            -> self-signed cert, no external dependency
#   staging/prod   -> Let's Encrypt via the `certbot` compose service
#                     (HTTP-01 challenge, served by nginx from the shared
#                     certbot_webroot volume — see compose/docker-compose.*.yml)
# =============================================================================
set -euo pipefail
ENVIRONMENT="${1:?usage: issue_cert.sh <dev|staging|production>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/envs/${ENVIRONMENT}.env"
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

COMPOSE_DIR="${REPO_ROOT}/compose"
compose() {
  docker compose --env-file "$ENV_FILE" -p "odoo-lab-${ENVIRONMENT}" \
    -f "${COMPOSE_DIR}/docker-compose.base.yml" \
    -f "${COMPOSE_DIR}/docker-compose.${ENVIRONMENT}.yml" \
    "$@"
}

if [ "$ENVIRONMENT" = "dev" ]; then
  echo "==> generating a self-signed certificate for ${SERVER_NAME:-localhost}"
  TMP="$(mktemp -d)"
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout "${TMP}/privkey.pem" -out "${TMP}/fullchain.pem" \
    -subj "/CN=${SERVER_NAME:-localhost}" \
    -addext "subjectAltName=DNS:${SERVER_NAME:-localhost}"
  docker run --rm -v "${TMP}:/src:ro" -v "odoo-lab-dev-nginx-certs:/dst" alpine:3.20.2 \
    sh -c "cp /src/* /dst/"
  rm -rf "$TMP"
  echo "==> self-signed certificate installed into the nginx_certs volume"
else
  echo "==> requesting/renewing a Let's Encrypt certificate for ${SERVER_NAME}"
  compose --profile tls run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    -d "${SERVER_NAME}" \
    --email "ops@${SERVER_NAME#*-}" --agree-tos --non-interactive
  compose exec -T nginx nginx -s reload
  echo "==> certificate issued/renewed; nginx reloaded"
fi
