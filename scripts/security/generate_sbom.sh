#!/usr/bin/env bash
# Generates an SPDX-format SBOM for every component image using Syft, and
# drops the results in sbom/ (gitignored — CI uploads these as build
# artifacts and attaches them as cosign attestations; see
# .github/workflows/build-and-scan.yml).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
mkdir -p sbom

for component in odoo nginx postgres pgbouncer; do
  echo "==> SBOM for ${component}"
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$(pwd)/sbom:/out" \
    anchore/syft:v1.13.0 "odoo-lab/${component}:local" -o "spdx-json=/out/${component}.spdx.json"
done

echo "SBOMs written to ./sbom/"
