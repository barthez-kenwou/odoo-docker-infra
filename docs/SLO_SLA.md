# SLIs, SLOs, SLA, and Error Budget

## Golden signals monitored (RED + USE)
- **RED** (per-request, Odoo/Nginx): Rate, Errors, Duration — Nginx access
  logs + `blackbox-exporter` probes.
- **USE** (per-resource, hosts/containers): Utilization, Saturation, Errors —
  node-exporter + cAdvisor.

## Service Level Indicators (SLI)
| SLI                         | Measurement                                                       |
|------------------------------|----------------------------------------------------------------------|
| Availability                | `probe_success{job="blackbox-http"}` (health endpoint, 15s interval)  |
| Latency                     | `probe_duration_seconds` (p95) for the health/login probe             |
| Error rate                  | Nginx 5xx rate via `nginx_http_requests_total{status=~"5.."}`         |
| Backup success rate         | `backup_postgres.sh` / `backup_filestore.sh` exit code, tracked via cron/systemd job status |

## Service Level Objectives (SLO) — internal target, not a customer contract
| SLI          | Target                          | Window   |
|---------------|-----------------------------------|-----------|
| Availability | 99.5% (≈ 3h39m downtime/month)    | Rolling 30d |
| p95 latency  | < 1.5s on `/web/login`             | Rolling 7d |
| Error rate   | < 1% of requests return 5xx        | Rolling 7d |
| Backup success | 100% (a failed backup is always investigated same-day) | Daily |

These are the thresholds actually encoded in
`monitoring/prometheus/alerts/*.yml` and `tests/load/k6_load_test.js`
(`http_req_duration: p(95)<1500`, `http_req_failed: rate<0.01`) — the SLO
here and the alert/threshold in code should never drift apart; if you change
one, change the other.

## Error budget
99.5% availability over 30 days = **~3h 39m** of allowed downtime.
Budget policy:
- **< 50% of budget consumed:** ship normally.
- **50-100% consumed:** slow down — require an extra review on
  infra-touching PRs, prioritize the top open reliability issue over new
  features.
- **Budget exhausted:** freeze non-critical deploys until the post-mortem
  action items from the incident(s) that burned the budget are done.

## Service Level Agreement (SLA)
This lab has no external customers, so there is no *contractual* SLA. If
this were productionized for real customers, the SLA (the number you'd
actually put in a contract, with penalties) should be set *looser* than the
SLO above — e.g. SLO 99.5% internally, SLA 99.0% externally — so you have
margin to miss the internal target occasionally without breaching a
contract. Never set SLA == SLO.

## RPO / RTO
See `docs/runbooks/disaster-recovery.md` for the full table; summary:
- **RPO:** ~24h for the standard daily-backup path; minutes achievable via
  WAL-based PITR (implemented, drill maturity noted as a gap in
  `docs/THREAT_MODEL.md`).
- **RTO:** < 4h for a full server loss (provision + restore), < 1h for a
  DB-only restore onto already-running infrastructure.
