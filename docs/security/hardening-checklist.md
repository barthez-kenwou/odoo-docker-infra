# Hardening checklist & control mapping

This is the single reference for "what's the actual security control, where
is it implemented, and which standard does it map to" — used by PRs
touching security-sensitive code and by the compliance mapping in
`docs/COMPLIANCE.md`.

## Fixed network map (keep every reference below in sync if this changes)
| Network    | CIDR             | Members                                    | Internet egress |
|------------|------------------|----------------------------------------------|-------------------|
| public     | 172.28.0.0/24    | nginx                                         | yes (published ports) |
| private    | 172.28.1.0/24    | nginx, odoo-blue, odoo-green, nginx-exporter, blackbox-exporter | via private's gateway |
| database   | 172.28.2.0/24    | odoo-blue, odoo-green, pgbouncer, postgres, postgres-exporter | **no** (`internal: true`) |

Referenced in: `terraform/modules/network/main.tf` (source of truth),
`docker/postgres/pg_hba.conf`, `docker/nginx/conf.d/odoo.conf.template`
(stub_status allow-list), `policy/opa/terraform_plan.rego`.

## GitHub branch protection (codified in `scripts/setup/configure_branch_protection.sh`)
- `main` and `develop`: required PR + 1 approval, dismiss stale reviews,
  required status checks (`lint`, `iac-scan`, `secret-scan`, `sast`, `sca`,
  `unit-tests`, `build-check`), no direct pushes (including admins).
- `production` GitHub Environment: required reviewer(s), deploys restricted
  to protected branches only.

## Control -> implementation -> standard
| Control                                   | Implementation                                                | Standard reference |
|--------------------------------------------|-----------------------------------------------------------------|----------------------|
| Least privilege (DB)                      | `odoo_app` role: no SUPERUSER/CREATEDB; `pg_exporter`: `pg_monitor` only | OWASP ASVS V4, CIS |
| Least privilege (containers)              | `cap_drop: ALL` + explicit `cap_add` per service                | CIS Docker Benchmark 5.3 |
| No plaintext secrets                      | SOPS + age (`secrets/README.md`)                                | OWASP ASVS V6, NIST CSF PR.DS-1 |
| Defense in depth (network)                | 3-tier segmented networks, `database` tier `internal=true`      | NIST CSF PR.AC-5 |
| Defense in depth (transport)              | TLS 1.2/1.3 only, HSTS, cert auto-renewal                        | OWASP ASVS V9 |
| Input/endpoint hardening                  | `dbfilter`, `list_db=False`, `/web/database/manager` blocked, rate limiting | OWASP Top 10 A05:2021 |
| Supply chain integrity                    | Pinned versions, Trivy+Grype scanning, SBOM, cosign sign+verify   | SLSA, NIST SSDF |
| Non-repudiation / audit                   | `auditd` rules, Loki centralized logs, Git as audit trail for secrets/IaC | ISO 27001 A.12.4 |
| Vulnerability management                  | Dependabot + nightly Trivy re-scan + security-gated PR pipeline  | NIST CSF ID.RA |
| Zero trust (no implicit inter-tier trust) | Every network hop is explicit; DB tier has no default route out | Zero Trust principles |
| Backup & recovery                         | restic (encrypted, versioned, 3-2-1), tested restores            | ISO 27001 A.12.3, NIST CSF RC |

## Secrets rotation cadence
Every 90 days or immediately on suspected exposure — see
`secrets/README.md#rotation` for the exact procedure per credential.

## Reviewing a PR that touches this area
- Does the diff introduce a new credential-shaped string? (gitleaks should
  already have caught it — don't rely on that alone.)
- Does a new/changed container run as non-root, drop all capabilities, set
  resource limits, and have a healthcheck?
- Does a new network path cross a tier boundary that wasn't there before?
  If so, is it justified and documented here?
