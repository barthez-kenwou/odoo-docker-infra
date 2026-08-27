#!/usr/bin/env bash
# =============================================================================
# Signs a locally built image with cosign. In CI (build-and-scan.yml) this
# happens keylessly via GitHub OIDC/Sigstore — no key management needed
# there. Locally (e.g. testing the release process end to end) a
# self-managed key pair is used instead.
# =============================================================================
set -euo pipefail
IMAGE_REF="${1:?usage: sign_image.sh <image-ref>}"

if [ -n "${CI:-}" ]; then
  echo "==> keyless signing via Sigstore/OIDC"
  COSIGN_EXPERIMENTAL=1 cosign sign --yes "$IMAGE_REF"
else
  echo "==> local key-based signing (cosign.key must exist — generate once with 'cosign generate-key-pair', keep cosign.key OUT of git)"
  [ -f cosign.key ] || { echo "cosign.key not found. Run: cosign generate-key-pair" >&2; exit 1; }
  cosign sign --key cosign.key "$IMAGE_REF"
fi
