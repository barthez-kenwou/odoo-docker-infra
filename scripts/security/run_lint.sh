#!/usr/bin/env bash
# Local equivalent of the `lint` job in .github/workflows/pr-checks.yml —
# run this before pushing so CI doesn't have to tell you what you already
# knew you'd get wrong.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

echo "==> shellcheck"
find scripts -name '*.sh' -print0 | xargs -0 shellcheck -S warning

echo "==> hadolint"
for f in docker/odoo/Dockerfile docker/nginx/Dockerfile docker/postgres/Dockerfile docker/pgbouncer/Dockerfile monitoring/alertmanager/Dockerfile; do
  echo "--- $f"
  hadolint "$f"
done

echo "==> yamllint"
yamllint -d "{extends: default, rules: {line-length: disable}}" compose/ monitoring/ .github/workflows/ ansible/

echo "==> terraform fmt -check"
terraform -chdir=terraform fmt -check -recursive

echo "==> tflint"
(cd terraform && tflint --init >/dev/null && tflint --config=.tflint.hcl)

echo "all lint checks passed"
