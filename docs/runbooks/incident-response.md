# Runbook: Incident Response

## Severity levels
| Level | Definition                                              | Example                                | Response time |
|-------|----------------------------------------------------------|------------------------------------------|-----------------|
| SEV1  | Production down or data at risk                          | Odoo unreachable, Postgres data corruption | Immediate |
| SEV2  | Production degraded, workaround exists                   | High latency, one feature broken          | < 1h |
| SEV3  | Staging issue, or production cosmetic/minor               | Slow report generation                    | Next business day |

## Phases (Detection -> Triage -> Containment -> Eradication -> Recovery -> Post-mortem)

### 1. Detection
Comes from one of: Alertmanager (Slack/email/Telegram), a user report, or the
nightly security re-scan opening a GitHub issue. Whoever notices it first
owns triage until someone else explicitly takes over — say so out loud
(in Slack), don't assume.

### 2. Triage
- Check Grafana ("Odoo Application" + "Infrastructure" dashboards) for what
  changed and when.
- Check `make logs ENV=<env>` / Loki for error spikes correlated with the
  alert's timestamp.
- Assign a severity level (above). SEV1 → page/notify immediately, don't
  wait for a scheduled check-in.

### 3. Containment
Goal: stop the bleeding, not necessarily fix the root cause yet.
- App-level issue → `make rollback ENV=<env>` (see `rollback.md`).
- Under attack (credential stuffing, DDoS-ish pattern) → tighten
  `limit_req_zone` in `docker/nginx/nginx.conf` temporarily, or block the
  source IP range at the UFW level (`ansible/roles/hardening`), or put Nginx
  into maintenance mode (see `troubleshooting.md`).
- Data integrity at risk → stop writes: `docker compose stop odoo-blue
  odoo-green` (keep Postgres up for forensics) before doing anything else.

### 4. Eradication
Remove the actual cause: revert the bad code, patch the vulnerability,
rotate the leaked credential (see `secrets/README.md` rotation procedure),
block the compromised account.

### 5. Recovery
Redeploy the fixed version through the normal pipeline (don't hotfix
production out-of-band unless truly SEV1 and even then, backport the fix
into a proper PR immediately after). Confirm with `smoke_test.sh` and watch
Grafana for at least one full traffic cycle before declaring it resolved.

### 6. Post-mortem
Blameless, written, within 48h for SEV1/SEV2. Minimum contents:
- Timeline (detection time, containment time, resolution time — compare to
  the SLO/error-budget in `docs/SLO_SLA.md`).
- Root cause (the actual technical cause, not "human error").
- What worked (what let us detect/contain it fast).
- Action items with owners — added as tracked issues, not just prose.

## Forensic evidence / retention
- Loki retains 30 days of logs by default (`monitoring/loki/loki-config.yml`
  `retention_period`) — extend before it rotates if the incident needs a
  longer look-back.
- `auditd` rules (`ansible/roles/hardening/tasks/main.yml`) log identity file
  changes, SSH config changes, and all `execve` calls on the host — check
  `/var/log/audit/audit.log` (shipped to Loki as the `auditd` job).
- Never `docker restart`/`rm` a compromised container before capturing
  `docker logs`, `docker inspect`, and (if needed) a filesystem snapshot for
  forensics — restarting destroys the tmpfs/ephemeral evidence.

## Escalation
Solo-operator lab: there's no one to escalate to but future-you and, if this
is a team project, whoever else has access. Document the expectation
explicitly once there's a real team (who's on call, how they're paged) — this
is a known gap for a from-scratch lab and is called out in
`docs/ARCHITECTURE.md`'s limitations section.
