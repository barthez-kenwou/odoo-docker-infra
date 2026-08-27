# Threat Model (STRIDE)

## Scope
The Odoo application stack (Nginx/Odoo/PostgreSQL/PgBouncer) and its
CI/CD pipeline, as deployed by this repository. Out of scope: physical
security of any hosting provider, and threats requiring a compromised
Anthropic/GitHub/cloud-provider supply chain upstream of what this repo
controls.

## Assets
| Asset                          | Why it matters |
|----------------------------------|------------------|
| Customer/business data in Postgres | Confidentiality + integrity are the whole point of running an ERP |
| Filestore attachments            | Same — invoices, contracts, uploaded documents |
| Odoo admin/master password       | Full application-level control if leaked |
| Database credentials             | Direct data access if leaked, bypassing the app entirely |
| TLS private key                  | MITM / impersonation if leaked |
| CI/CD signing identity (cosign, GitHub OIDC) | Ability to publish a "legitimately signed" malicious image if compromised |
| SSH access to hosts              | Full host compromise |
| Backup repository                | An attacker who can write here can plant a "restore" that's actually a backdoor; one who can delete it removes the recovery safety net |

## Trust boundaries
1. **Internet ↔ Nginx** (public network) — the only boundary an anonymous
   attacker can reach directly.
2. **Nginx ↔ Odoo** (private network) — Nginx is trusted to have already
   done TLS termination, rate limiting, and header hardening before traffic
   reaches here.
3. **Odoo ↔ PgBouncer/Postgres** (database network, `internal: true`) —
   Odoo is the only trusted caller; the network itself cannot reach or be
   reached from the Internet.
4. **CI/CD ↔ Registry ↔ Production host** — a separate boundary: GitHub
   Actions' identity (OIDC) is trusted to sign images; the production host
   is trusted to only pull/run signature-verified digests
   (`scripts/security/verify_image.sh`).
5. **Operator ↔ Host (SSH)** — key-only, IP-restricted (UFW +
   `admin_ipv4_cidr`), the boundary for infrastructure-level trust.

## STRIDE analysis

### Spoofing
- *Threat:* Attacker impersonates a legitimate user or the server itself.
- *Mitigations:* TLS 1.2/1.3 + HSTS prevent server impersonation /
  downgrade; Odoo's own auth (with rate-limited `/web/login`) for user
  identity; cosign signature verification prevents a spoofed/tampered image
  from being trusted as "ours."
- *Residual risk:* No MFA is enforced at the Odoo application layer by
  default in this lab (Odoo supports TOTP; enabling and enforcing it for
  admin/accounting roles is a deployment-time decision, tracked as a gap
  below).

### Tampering
- *Threat:* Unauthorized modification of data, config, or the running
  artifact.
- *Mitigations:* least-privilege DB roles limit blast radius of a compromised
  Odoo process; `read_only: true` root filesystems limit what a compromised
  container can persist; cosign signing + verification prevents a tampered
  image from being deployed; Git + branch protection + required review for
  every infra/config change; auditd watches key files
  (`/etc/passwd`, `sshd_config`, `docker/daemon.json`).
- *Residual risk:* an attacker with valid Odoo admin credentials can still
  tamper with application data through legitimate-looking actions — this is
  addressed by Odoo's own audit logging (`mail.tracking.value`) and RBAC, not
  by infrastructure controls; ensure both are actually configured for real
  business data.

### Repudiation
- *Threat:* An actor denies having performed an action.
- *Mitigations:* Nginx access logs with `$request_id` correlated to Odoo
  logs and (where instrumented) traces; auditd for host-level actions; Git
  history for every infra/secrets change (SOPS ciphertext diffs included).
- *Residual risk:* Odoo's own internal audit trail (`mail.thread` message
  log) needs to be enabled per-model for business data if non-repudiation
  of *business actions* (not just infra actions) matters for compliance.

### Information Disclosure
- *Threat:* Unauthorized access to data in transit or at rest.
- *Mitigations:* `database` network has no path to/from the Internet;
  Postgres `pg_hba.conf` rejects everything outside that subnet; TLS
  everywhere in transit; SOPS encryption for secrets at rest; S3 bucket
  encryption (SSE-KMS) + public-access-block for backups;
  `/web/database/manager` blocked at Nginx.
- *Residual risk:* Postgres itself doesn't encrypt data at rest by default
  in this lab (relies on the host's disk encryption, which is
  environment-dependent — see the "Disk encryption" item in
  `docs/COMPLIANCE.md` gaps).

### Denial of Service
- *Threat:* Legitimate users can't reach the service.
- *Mitigations:* Nginx rate limiting (`limit_req_zone`, stricter on
  `/web/login`), `client_max_body_size` cap, resource limits on every
  container (a runaway process can't starve its neighbors), blue/green
  deploys avoid deploy-induced downtime, Alertmanager pages on `OdooDown`/
  `HighHTTP5xxRate` quickly.
- *Residual risk:* no Web Application Firewall or upstream DDoS scrubbing
  (Cloudflare-in-front is a documented, disabled-by-default option in
  `terraform/modules/dns` — `proxied = false` today); a volumetric attack
  beyond what a single host's NIC/rate-limiter can absorb is out of scope
  for a single-VM lab.

### Elevation of Privilege
- *Threat:* An attacker gains more access than intended.
- *Mitigations:* `cap_drop: ALL` + minimal `cap_add` per container;
  `no-new-privileges:true`; non-root container users; least-privilege
  Postgres roles (no superuser for the app); SSH key-only + no root login;
  `sudo` only for the `deploy` user, not password-based.
- *Residual risk:* `cadvisor` runs `privileged: true` (required for
  cgroup/container introspection) — isolated to the compose-managed
  `monitoring` network with no path to `public`/`private`/`database`, but
  it is the single highest-privilege container in the stack and is called
  out explicitly here rather than left as a silent exception.

## Known gaps (tracked, not hidden)
- No MFA enforced at the Odoo application layer by default.
- No WAF / DDoS scrubbing in front of Nginx by default.
- Disk-at-rest encryption depends on the host, not enforced by this repo.
- WAL-replay PITR procedure is documented but not yet drilled as thoroughly
  as the daily-backup restore path (see `disaster-recovery.md`).
- Single-operator incident response — no on-call rotation defined (fine for
  a solo lab; a real gap the moment a second person joins).
