#!/usr/bin/env bash
# =============================================================================
# Pins envs/production.env's *_IMAGE variables to the exact digests that were
# built once and validated in staging (see .github/workflows/promote-production.yml
# and docs/adr/0004-build-once-promote-strategy.md). Never rebuilds anything.
# =============================================================================
set -euo pipefail

DIGESTS_DIR="${1:-digests}"
ENV_FILE="envs/production.env"
REGISTRY_BASE="${REGISTRY_BASE:-ghcr.io/example-org/odoo-lab}"

[ -d "$DIGESTS_DIR" ] || { echo "digests directory '$DIGESTS_DIR' not found (run after downloading build-and-scan.yml artifacts)" >&2; exit 1; }

for component in odoo nginx postgres pgbouncer; do
  digest_file="${DIGESTS_DIR}/digest-${component}/${component}.digest"
  [ -f "$digest_file" ] || { echo "missing digest file for ${component}: ${digest_file}" >&2; exit 1; }
  digest="$(cat "$digest_file")"
  var_name="$(echo "$component" | tr '[:lower:]' '[:upper:]')_IMAGE"
  new_ref="${REGISTRY_BASE}/${component}@${digest}"
  echo "[promote] ${var_name} -> ${new_ref}"
  if grep -q "^${var_name}=" "$ENV_FILE"; then
    sed -i.bak "s|^${var_name}=.*|${var_name}=${new_ref}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
  else
    echo "${var_name}=${new_ref}" >> "$ENV_FILE"
  fi
done

echo "[promote] envs/production.env now pins the exact staging-validated digests"
