# Runbook: Deployment

## When to use this
Every time code merges to `develop` (auto) or gets promoted to `main`
(manual approval). Also useful as the manual procedure if CI is down and you
need to deploy by hand.

## Preconditions
- The image digests for this deploy passed `build-and-scan.yml` (Trivy,
  Grype, SBOM, cosign signature) — verified automatically by
  `scripts/security/verify_image.sh` as the first step of both
  `deploy-staging.yml` and `promote-production.yml`.
- `envs/<env>.env` is decrypted and present (CI does this via SOPS; see
  `secrets/README.md`).

## Automatic path (normal case)
1. Merge to `develop` → `build-and-scan.yml` builds/scans/signs/pushes →
   dispatches `deploy-staging.yml`.
2. `deploy-staging.yml` runs `scripts/deploy/deploy.sh staging`, then smoke
   tests, then a ZAP DAST baseline scan against the live staging URL.
3. Once staging looks good, a human runs `promote-production.yml` via
   `workflow_dispatch`, pointing at the staging run's ID. This requires
   approval from a reviewer on the `production` GitHub Environment.
4. `promote-production.yml` backs up production first (`make backup`), then
   runs `scripts/deploy/deploy.sh production` with the *same* digests.

## Manual path (CI is down)
```bash
export ENVIRONMENT=staging   # or production
sops -d envs/${ENVIRONMENT}.env.enc > envs/${ENVIRONMENT}.env
./scripts/security/verify_image.sh "$ENVIRONMENT"
./scripts/deploy/deploy.sh "$ENVIRONMENT"
./scripts/deploy/smoke_test.sh "$ENVIRONMENT"
shred -u envs/${ENVIRONMENT}.env
```

## What `deploy.sh` actually does (see script for full detail)
1. Reads which color (`blue`/`green`) is currently active from Nginx.
2. Starts the **idle** color with the new image, waits for its Docker
   healthcheck to report `healthy`.
3. Runs the addon migration (`odoo -u lab_demo_module --stop-after-init`)
   against the idle color.
4. Smoke-tests the idle color directly, container-to-container (bypasses
   Nginx — proves the app itself is fine before touching routing).
5. Rewrites `/etc/nginx/active/active_upstream.conf` inside the Nginx
   container and reloads Nginx (`nginx -s reload` — no dropped connections,
   no restart).
6. Smoke-tests again through the public URL (proves the whole path: TLS,
   headers, rate limiting, routing).
7. Leaves the old color running (not stopped) and records which color it was,
   so `rollback.sh` can flip back instantly. It does not get torn down until
   the *next* deploy overwrites it.

## Handling a breaking database migration
Blue/green assumes the old and new app versions can both run against the
post-migration schema for the duration of the cutover (seconds to low
minutes). For a genuinely breaking change (column removed a query still
needs, etc.), use the expand/contract pattern instead of a single deploy:

1. **Expand**: ship a migration that only *adds* (new column, nullable,
   backfilled) — deploy normally.
2. Deploy the app version that writes to both old and new columns.
3. Backfill, verify.
4. **Contract**: a separate, later deploy removes the old column, once
   nothing reads it anymore.

Never combine "drop a column" and "deploy code that no longer needs it" in
the same blue/green cutover — the brief window where both colors could be
live makes that unsafe.

## Verifying success
- `make ps ENV=<env>` — both colors should show, active one `healthy`.
- Grafana "Odoo Application" dashboard: health probe green, no restart spike.
- `scripts/deploy/smoke_test.sh <env>` exits 0.

## If it fails
Go to `docs/runbooks/rollback.md`.
