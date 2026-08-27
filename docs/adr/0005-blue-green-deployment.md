# 5. Blue/green deployment over rolling or canary

## Status
Accepted

## Context
Three real options for zero-downtime deploys in a Compose-based, single-host
topology:

- **Rolling** — not really meaningful with a single container per color in
  Compose; would require running N replicas behind a load balancer, adding
  complexity without much benefit at this scale.
- **Canary** — needs traffic-splitting infrastructure (weighted upstreams,
  a service mesh, or a smarter proxy config) to send e.g. 5% of traffic to
  the new version; valuable at higher traffic/team scale, overkill here.
- **Blue/green** — two full copies of the app tier, an atomic switch of which
  one receives traffic. Simple to reason about, simple to roll back
  (flip back), and cheap to implement with a single Nginx upstream file.

## Decision
Implement blue/green at the Nginx layer: `odoo-blue` and `odoo-green`
services both exist in `compose/docker-compose.base.yml`; only one is
"active" at a time per `/etc/nginx/active/active_upstream.conf`.
`scripts/deploy/deploy.sh` starts the idle color, health-checks it,
smoke-tests it directly (bypassing Nginx), flips the upstream file, reloads
Nginx (`nginx -s reload`, zero dropped connections), then smoke-tests again
through the public URL. The old color is kept running (not torn down)
specifically so `scripts/deploy/rollback.sh` can flip back in seconds with no
image pull and no migration.

## Consequences
- Every deploy briefly runs 2x the Odoo container resources (both colors
  live simultaneously during the cutover window) — sized for in
  `docker-compose.staging.yml` / `.production.yml`.
- Database migrations run once, against the shared Postgres, before the
  traffic flip — this means migrations must be backward-compatible with the
  *old* color for the duration of the cutover window (the old color is still
  potentially serving traffic while the migration runs). See
  `docs/runbooks/deployment.md` for the concrete sequencing and how to handle
  a genuinely breaking migration.
- Rollback is fast (seconds) as long as the old color's schema is still
  compatible; a rollback *after* a breaking migration requires the DB restore
  procedure in `docs/runbooks/disaster-recovery.md` instead.
