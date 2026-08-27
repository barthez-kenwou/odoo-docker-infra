## What changed and why

<!-- Summarize the change. Link the issue/ticket if there is one. -->

## Type of change

- [ ] `feat` — new capability
- [ ] `fix` — bug fix
- [ ] `security` — vulnerability fix / hardening
- [ ] `ci` / `chore` / `docs` / `refactor` / `test`

## Checklist

- [ ] `make lint` and `make security-scan` pass locally
- [ ] Unit/integration tests updated or added (`make test`)
- [ ] No secret, credential, or private key introduced (gitleaks will also check)
- [ ] No `:latest` tag / unpinned dependency introduced
- [ ] New/changed containers: non-root user, resource limits, healthcheck set
- [ ] Docs/runbooks updated if operational behavior changed
- [ ] If this touches `terraform/`: `terraform plan` output reviewed and attached/linked

## Rollback plan

<!-- How do we undo this if it breaks staging/production? Usually
"redeploy the previous image digest via `make rollback`", but call out
anything unusual (e.g. an irreversible DB migration). -->
