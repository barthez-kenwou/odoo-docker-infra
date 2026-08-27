# Compliance & standards mapping

This lab is not certified against anything (no auditor has reviewed it) —
this document maps implemented controls to well-known standards/frameworks
for reference and self-assessment, and is honest about what's a full
mapping versus a partial one.

## OWASP ASVS (Application Security Verification Standard) — Level 1 posture
| ASVS area                     | Status | Notes |
|--------------------------------|--------|-------|
| V1 Architecture                | ✅ | Documented in `docs/ARCHITECTURE.md` + ADRs |
| V2 Authentication               | ⚠️ Partial | Odoo's built-in auth + rate limiting; MFA available in Odoo but not enforced by default (see Threat Model gaps) |
| V4 Access Control               | ✅ | DB least privilege, Odoo ACL/record rules, RBAC on hosts |
| V5 Validation/Encoding          | ➖ Not assessed | Delegated to Odoo core (out of this repo's scope); custom addon code should follow Odoo's ORM (parameterized queries by default) |
| V7 Error handling/logging       | ✅ | Centralized via Loki, `log_level=warn` in production avoids leaking stack traces |
| V9 Communications (TLS)         | ✅ | TLS 1.2/1.3 only, HSTS, auto-renewal |
| V10 Malicious code              | ✅ | SAST (Semgrep) + SCA (pip-audit) on custom addon code |
| V14 Configuration               | ✅ | No `latest` tags, resource limits, hardened defaults, IaC-managed |

## OWASP Top 10 (2021)
| Risk                                      | Mitigation |
|---------------------------------------------|--------------|
| A01 Broken Access Control                  | Least-privilege DB roles, Odoo ACL, blocked `/web/database/manager` |
| A02 Cryptographic Failures                 | TLS everywhere, SOPS-encrypted secrets, S3 SSE-KMS |
| A03 Injection                              | Parameterized queries via Odoo ORM (addon code review checklist in `CONTRIBUTING.md`) |
| A04 Insecure Design                        | Threat model (`docs/THREAT_MODEL.md`), ADRs documenting security trade-offs |
| A05 Security Misconfiguration              | IaC (no manual config drift), Checkov/tflint/Conftest gates, no default credentials |
| A06 Vulnerable/Outdated Components         | Dependabot + Trivy/Grype + nightly re-scan |
| A07 Identification/Auth Failures           | Rate-limited login, SSH key-only, no shared admin accounts |
| A08 Software/Data Integrity Failures       | cosign signing + verification before every deploy, SBOM attestation |
| A09 Security Logging/Monitoring Failures   | Prometheus/Alertmanager/Loki/auditd, documented incident-response runbook |
| A10 Server-Side Request Forgery            | ➖ Not specifically assessed — relevant if custom addons ever fetch user-supplied URLs; flag in code review |

## CIS Benchmarks
- **CIS Docker Benchmark**: non-root containers, `cap_drop: ALL`,
  `no-new-privileges`, resource limits, health checks, image scanning —
  implemented per-service in `compose/docker-compose.base.yml`.
- **CIS Ubuntu Linux 24.04 Benchmark**: SSH hardening, UFW, auditd, AppArmor,
  unattended upgrades, filesystem permissions, sysctl hardening — implemented
  in `ansible/roles/hardening`. This is a *baseline subset* of the full CIS
  benchmark (dozens of additional checks exist), not a complete CIS
  certification — treat it as a strong starting point, run a real CIS
  scanner (e.g. `cis-cat` or `lynis`) before claiming full compliance.

## NIST Cybersecurity Framework (CSF)
| Function | Example controls in this repo |
|-----------|----------------------------------|
| Identify | Threat model, asset inventory (Threat Model "Assets" table) |
| Protect  | Network segmentation, least privilege, encryption, hardening |
| Detect   | Prometheus/Alertmanager, Loki, auditd, nightly vuln re-scan |
| Respond  | `docs/runbooks/incident-response.md`, severity levels, escalation |
| Recover  | Backup/restore + DR runbooks, tested restore drills |

## ISO 27001 (concepts, not certification)
Relevant Annex A themes covered at a control level: A.9 (access control),
A.10 (cryptography — SOPS, TLS), A.12 (operations security — logging,
backup, vulnerability management), A.14 (secure development — SAST/SCA
gates), A.17 (business continuity — DR runbook). This repo implements
*controls consistent with* these themes; ISO 27001 certification itself
requires a formal ISMS, risk assessment process, and external audit that are
organizational, not code-level, and out of scope here.

## Core principles applied throughout
- **Least privilege:** every credential/role in this repo is scoped to the
  minimum it needs (see `docs/security/hardening-checklist.md` table).
- **Defense in depth:** 8 layers, see `docs/diagrams/security-layers.mmd`.
- **Zero trust between tiers:** no network segment implicitly trusts another;
  every cross-tier call is explicit and minimal.
- **Data retention:** Loki logs 30 days, restic backups follow 30d/8w/12m
  generations — tune both to your actual regulatory requirements before
  relying on these defaults for real business/customer data.
- **Auditability:** Git history (code + IaC + encrypted secrets diffs) +
  auditd + centralized logs together form the audit trail; there is no
  single "audit log" system, that's a conscious trade-off for a lab this
  size (a real compliance program would likely centralize this further).
