#!/usr/bin/env bash
# =============================================================================
# Codifies the branch protection rules described in
# docs/security/hardening-checklist.md, using the GitHub CLI, so they're
# reproducible instead of "someone once clicked the right checkboxes".
# Run once per repo (idempotent — safe to re-run after any manual drift).
# =============================================================================
set -euo pipefail
REPO="${1:?usage: configure_branch_protection.sh <owner/repo>}"

protect() {
  local branch="$1"
  shift
  gh api -X PUT "repos/${REPO}/branches/${branch}/protection" \
    -H "Accept: application/vnd.github+json" \
    -f "required_status_checks[strict]=true" \
    -f "enforce_admins=true" \
    -f "required_pull_request_reviews[required_approving_review_count]=1" \
    -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
    -f "restrictions=null" \
    "$@"
}

echo "==> protecting main"
protect main \
  -f "required_status_checks[contexts][]=lint" \
  -f "required_status_checks[contexts][]=iac-scan" \
  -f "required_status_checks[contexts][]=secret-scan" \
  -f "required_status_checks[contexts][]=sast" \
  -f "required_status_checks[contexts][]=sca" \
  -f "required_status_checks[contexts][]=unit-tests" \
  -f "required_status_checks[contexts][]=build-check"

echo "==> protecting develop"
protect develop \
  -f "required_status_checks[contexts][]=lint" \
  -f "required_status_checks[contexts][]=iac-scan" \
  -f "required_status_checks[contexts][]=secret-scan" \
  -f "required_status_checks[contexts][]=sast" \
  -f "required_status_checks[contexts][]=sca" \
  -f "required_status_checks[contexts][]=unit-tests" \
  -f "required_status_checks[contexts][]=build-check"

echo "==> creating the 'production' GitHub Environment with a required reviewer"
gh api -X PUT "repos/${REPO}/environments/production" \
  -f "deployment_branch_policy[protected_branches]=true"
echo "    NOTE: add the actual required reviewer(s) in Settings > Environments >"
echo "    production > Required reviewers — the API needs a real user/team ID,"
echo "    intentionally not hardcoded here."

echo "done."
