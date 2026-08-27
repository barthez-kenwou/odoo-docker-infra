#!/usr/bin/env bash
# =============================================================================
# Post-deploy smoke test: hits the public URL through nginx (real TLS, real
# rate limiting, real headers) and asserts on status code + a couple of
# security headers. Deliberately black-box — no shortcuts through the
# internal network — so it validates exactly what an end user would see.
# =============================================================================
set -euo pipefail

ENVIRONMENT="${1:-dev}"
case "$ENVIRONMENT" in
  dev) BASE_URL="${BASE_URL:-https://localhost}" ;;
  staging) BASE_URL="${BASE_URL:-https://staging-odoo.example.com}" ;;
  production) BASE_URL="${BASE_URL:-https://odoo.example.com}" ;;
  *) echo "unknown environment: $ENVIRONMENT" >&2; exit 2 ;;
esac

CURL_OPTS=(-sS -o /dev/null -w '%{http_code}')
[ "$ENVIRONMENT" = "dev" ] && CURL_OPTS+=(-k)   # self-signed cert locally

echo "[smoke-test] GET ${BASE_URL}/web/login"
STATUS="$(curl "${CURL_OPTS[@]}" "${BASE_URL}/web/login")"
if [ "$STATUS" != "200" ]; then
  echo "[smoke-test] FAILED: expected 200, got ${STATUS}" >&2
  exit 1
fi

echo "[smoke-test] GET ${BASE_URL}/healthz"
STATUS="$(curl "${CURL_OPTS[@]}" "${BASE_URL}/healthz")"
[ "$STATUS" = "200" ] || { echo "[smoke-test] healthz FAILED (${STATUS})" >&2; exit 1; }

echo "[smoke-test] checking security headers"
HEADERS="$(curl -sSI "${BASE_URL}/web/login" $([ "$ENVIRONMENT" = "dev" ] && echo -k))"
for h in "Strict-Transport-Security" "X-Content-Type-Options" "X-Frame-Options"; do
  echo "$HEADERS" | grep -qi "$h" || { echo "[smoke-test] missing header: $h" >&2; exit 1; }
done

echo "[smoke-test] all checks passed for ${ENVIRONMENT}"
