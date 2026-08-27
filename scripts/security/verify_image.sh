#!/usr/bin/env bash
# =============================================================================
# Supply-chain gate run before EVERY deploy (staging and production): refuses
# to pull/run an image whose cosign signature and SBOM attestation don't
# verify. This is what actually enforces "only artifacts that passed our own
# pipeline can run in this environment" — a pulled image with a missing or
# invalid signature stops the deploy here, not after it's already running.
# =============================================================================
set -euo pipefail
ENVIRONMENT="${1:?usage: verify_image.sh <staging|production>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/envs/${ENVIRONMENT}.env"
CERT_IDENTITY_REGEXP="^https://github.com/example-org/odoo-devsecops-lab/"
CERT_OIDC_ISSUER="https://token.actions.githubusercontent.com"

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

for var in ODOO_IMAGE NGINX_IMAGE POSTGRES_IMAGE PGBOUNCER_IMAGE; do
  ref="${!var}"
  [ "$ref" = "" ] && continue
  echo "==> verifying signature: ${ref}"
  COSIGN_EXPERIMENTAL=1 cosign verify "$ref" \
    --certificate-identity-regexp "$CERT_IDENTITY_REGEXP" \
    --certificate-oidc-issuer "$CERT_OIDC_ISSUER" \
    > /dev/null

  echo "==> verifying SBOM attestation: ${ref}"
  COSIGN_EXPERIMENTAL=1 cosign verify-attestation "$ref" \
    --type spdxjson \
    --certificate-identity-regexp "$CERT_IDENTITY_REGEXP" \
    --certificate-oidc-issuer "$CERT_OIDC_ISSUER" \
    > /dev/null

  echo "    OK: ${ref}"
done

echo "all image signatures and SBOM attestations verified for ${ENVIRONMENT}"
