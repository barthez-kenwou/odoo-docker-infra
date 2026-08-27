# Contributing Guide

This repository is run like a real engineering project, even though it started as a personal
DevSecOps lab. Please follow these rules so history stays clean and the pipeline stays green.

## Branching model

- `main` → always deployable, protected, maps to **production**.
- `develop` → integration branch, protected, maps to **staging**.
- `feature/*`, `fix/*`, `chore/*` → short-lived branches cut from `develop`.
- `hotfix/*` → cut from `main` for emergency production fixes, merged back to both `main` and `develop`.

## Commit convention

This repo uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body]
[optional footer(s)]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `perf`, `security`.
Examples:
```
feat(odoo): add read-only filesystem support to odoo container
fix(nginx): correct HSTS header duplication on error pages
security(ci): add trivy exit-code=1 gate on CRITICAL findings
```

Releases are tagged using [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`) and
built automatically by `.github/workflows/build-and-scan.yml` on every push to `main`.

## Pull requests

- Every change to `develop` or `main` goes through a Pull Request. Direct pushes are blocked by
  branch protection (see `docs/security/hardening-checklist.md`).
- At least **one approving review** is required.
- All required status checks must pass: lint, SAST, secret scanning, IaC scanning, container
  scanning, and unit tests (see `.github/workflows/pr-checks.yml`).
- Use the PR template — it asks you to confirm you updated docs/runbooks if behavior changed.

## Local validation before opening a PR

```bash
make lint        # shellcheck, hadolint, tflint, yamllint
make security-scan   # gitleaks + semgrep + trivy config
make test         # unit + integration tests
```

## Code review checklist (what reviewers look for)

- No secret, credential, or private key is introduced (gitleaks should already catch this).
- No `:latest` tag or unpinned dependency introduced.
- Any new container runs as non-root, has resource limits, and a healthcheck.
- Any new Terraform resource has a matching `variables.tf` entry (no hardcoded values) and passes
  `terraform fmt` / `tflint` / `checkov`.
- Documentation (`docs/`) and runbooks are updated when operational behavior changes.

## Reporting a vulnerability

Please do not open a public issue for a security vulnerability found in this lab. Instead, open a
private security advisory (or contact the maintainer directly) so a fix can be prepared before
disclosure.
