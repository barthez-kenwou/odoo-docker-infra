# Runbook: Rollback

## When to use this
A deploy's post-flip smoke test failed, or something looks wrong within the
first few minutes/hours after a deploy and you want to get back to the
last-known-good state fast, before investigating root cause.

## Fast path (schema-compatible rollback)
If the failing deploy did **not** run a breaking (contract-phase) migration:

```bash
make rollback ENV=staging      # or production
```

This runs `scripts/deploy/rollback.sh`, which:
1. Reads which color was active *before* the failed deploy (recorded by
   `deploy.sh` in `/tmp/odoo-lab-<env>-previous-color`).
2. Starts that color if it isn't still running.
3. Flips Nginx's active upstream back to it and reloads.

This is seconds, not minutes — no image pull, no migration re-run.

## If the fast path doesn't apply (post-migration rollback)
If the failing deploy included a schema change the old color's code can't
tolerate, flipping Nginx back isn't enough — you need to restore the
database to its pre-migration state too:

1. Flip Nginx back to the old color first (stops the bleeding — old code,
   even against a half-migrated schema, is usually less broken than new code
   against a schema it doesn't expect. Judgment call; if genuinely unsafe,
   put Nginx into maintenance mode instead — see `troubleshooting.md`).
2. Follow `docs/runbooks/disaster-recovery.md` to restore Postgres from the
   `make backup` snapshot taken automatically before the deploy
   (`promote-production.yml`'s "Pre-deployment backup" step).
3. Once the DB is back to pre-migration state, confirm the old color is
   healthy against it, then investigate the migration bug before trying
   again.

## Automatic rollback in CI
Both `deploy-staging.yml` and `promote-production.yml` run
`scripts/deploy/rollback.sh` automatically in an `if: failure()` step, so a
smoke-test failure during the pipeline itself is already rolled back by the
time you see the red X on GitHub. This manual procedure is for anything
noticed *after* the pipeline reported green.

## Post-rollback checklist
- [ ] Confirm `smoke_test.sh` passes against the rolled-back color.
- [ ] Check Grafana for the incident window — capture graphs for the
      post-mortem (see `incident-response.md`).
- [ ] File an issue with the root cause once known; don't just retry the
      same deploy blind.
