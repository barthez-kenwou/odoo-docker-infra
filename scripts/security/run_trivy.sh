#!/usr/bin/env bash
# Usage: run_trivy.sh <fs|config|image> <target>
set -euo pipefail
MODE="${1:?usage: run_trivy.sh <fs|config|image> <target>}"
TARGET="${2:?target required}"

docker run --rm -v "$(pwd):/work" -w /work aquasec/trivy:0.55.2 \
  "$MODE" --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed "$TARGET"
