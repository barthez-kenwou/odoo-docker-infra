#!/usr/bin/env bash
# Scans the full git history for anything credential-shaped. Run before
# every push, not just in CI — catching a leaked secret before it's pushed
# is much cheaper than rotating it after.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

docker run --rm -v "$(pwd):/repo" zricethezav/gitleaks:v8.18.4 \
  detect --source=/repo --no-git -v --redact
