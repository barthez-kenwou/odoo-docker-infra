# Custom addons

Everything under this directory is baked into the Odoo image at build time
(see `docker/odoo/Dockerfile`) and is subject to the same CI gates as the
infrastructure code: unit tests, SAST (Semgrep/Bandit-equivalent via
Semgrep's Python ruleset), and code review.

## Conventions

- One addon per business capability, own `__manifest__.py`, own tests.
- Every model that grants access must ship an explicit `ir.model.access.csv`
  row — Odoo's default is deny, keep it that way (least privilege / ACL
  checklist item).
- Every addon ships `tests/` and is expected to pass
  `odoo -d $DB --test-enable --stop-after-init -i <addon>` before merge (see
  `.github/workflows/pr-checks.yml`).
- Addons are versioned independently in their manifest (`"version": "18.0.1.0.0"`)
  following Odoo's `<odoo_series>.<major>.<minor>.<patch>` convention, so a
  migration/compatibility matrix (see `docs/`) can track what shipped when.

## `lab_demo_module`

A deliberately small addon that exists to prove the whole pipeline end to
end (build → test → scan → deploy) rather than to demonstrate real business
logic. Replace it with real addons for an actual deployment; keep the
scaffolding (manifest shape, ACL file, test layout) as the template.
