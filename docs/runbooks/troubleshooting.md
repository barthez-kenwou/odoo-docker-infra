# Runbook: Troubleshooting

## Odoo won't start / crash-looping
1. `make logs ENV=<env>` — look for a Python traceback right after "Starting
   Odoo" — usually a bad `odoo.conf` value or a broken custom addon.
2. Confirm PgBouncer is healthy first: `make ps ENV=<env>` — Odoo depends on
   it (`depends_on: condition: service_healthy`), so if PgBouncer never goes
   healthy, Odoo never even starts.
3. Check `OdooContainerRestartLoop` in Grafana/Alertmanager for the exact
   restart count/timing.

## Nginx returns 502
Almost always means the active Odoo color isn't answering. Check:
```bash
docker compose exec nginx cat /etc/nginx/active/active_upstream.conf   # which color is "active"?
make ps ENV=<env>                                                       # is that color healthy?
```
If the active color died mid-request, either wait for its healthcheck to
recover it, or `make rollback ENV=<env>` to flip to the other color.

## Slow requests / high latency
1. Grafana "PostgreSQL" dashboard → check active connections and exclusive
   locks first (a stuck migration or a long-running report query is the
   usual cause).
2. `docker compose exec postgres psql -U postgres -d odoo -c "SELECT pid, now() - query_start AS duration, query FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC LIMIT 10;"`
3. `log_min_duration_statement = 500` (see `docker/postgres/postgresql.conf`)
   means anything over 500ms is already in the logs/Loki — search there for
   the exact slow query text.
4. If it's genuinely load (not a bad query), that's what
   `tests/load/k6_load_test.js` is for: re-run it to reproduce, then look at
   `ODOO_WORKERS` sizing (see the sizing note below) before assuming you need
   bigger hardware.

## Worker/resource sizing
Rule of thumb (Odoo's own sizing guidance): `workers ≈ (CPU cores × 2) + 1`,
with enough RAM for `workers × limit_memory_hard` plus headroom for the OS
and Postgres. The values baked into
`compose/docker-compose.{staging,production}.yml` are conservative starting
points — re-tune based on real `tests/load/k6_load_test.js` results, not
guesswork, and record the new numbers with a comment explaining why.

## Disk full
1. `DiskAlmostFull` alert fires (< 10% free — see
   `monitoring/prometheus/alerts/node.rules.yml`).
2. Usual suspects, in order of likelihood: Postgres WAL archive
   (`postgres_wal_archive` volume) growing unbounded because
   `backup_postgres.sh`'s cron stopped running, Docker's own log files (should
   be capped by `ansible/roles/hardening`'s `daemon.json` — verify
   `max-size`/`max-file` are actually applied), or genuinely just needing more
   disk.
3. `docker system df` to see where space is going. `docker system prune` is
   a *last* resort — understand what's filling it before deleting things.

## Email deliverability
1. Confirm SPF/DKIM/DMARC are actually published:
   ```bash
   dig TXT staging-odoo.example.com | grep spf
   dig TXT default._domainkey.staging-odoo.example.com
   dig TXT _dmarc.staging-odoo.example.com
   ```
   (managed by `terraform/modules/dns` if `enable_cloud_dns = true`).
2. Check the DMARC aggregate reports sent to the `rua=` address — that's
   where you learn if legitimate mail is failing alignment before you
   tighten `p=none` to `p=quarantine`/`p=reject`.
3. In dev, everything goes to MailHog (`http://localhost:8025`) — nothing
   ever reaches a real inbox, by design.

## TLS certificate problems
- `TLSCertificateExpiringSoon` firing → check `docker compose logs certbot`;
  the renewal timer runs every 12h inside the `certbot` service
  (`profiles: ["tls"]`).
- Local dev self-signed cert warnings in the browser are expected — that's
  what "self-signed" means; see `scripts/tls/issue_cert.sh`.

## "I need to put the site into maintenance mode"
Temporarily point Nginx's default location at a static maintenance page
instead of `odoo_active`:
```bash
docker compose exec nginx sh -c 'echo "location / { return 503; }" > /etc/nginx/conf.d/99-maintenance.conf'
docker compose exec nginx nginx -s reload
# ... do the maintenance work ...
docker compose exec nginx rm /etc/nginx/conf.d/99-maintenance.conf
docker compose exec nginx nginx -s reload
```
