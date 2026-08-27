# Runbook: Disaster Recovery

## RPO / RTO (see docs/SLO_SLA.md for the full definitions)
| Scenario                          | RPO (max data loss) | RTO (max time to recover) |
|-------------------------------------|----------------------|------------------------------|
| Postgres container crash            | 0 (auto-restart)      | < 2 min                       |
| Postgres data corruption            | ~24h (last daily backup) or minutes with WAL/PITR | < 1h |
| Full server loss                    | ~24h (last off-box backup) | < 4h (re-provision + restore) |
| Accidental data deletion (app-level)| Depends on detection time | < 1h once detected |

## Scenario: Postgres container down
1. Docker's `restart: unless-stopped` should already be bringing it back.
   Confirm: `make ps ENV=<env>`.
2. If it's crash-looping, check `make logs ENV=<env>` for the postgres
   service — most likely disk full (see `troubleshooting.md#disk-full`) or a
   corrupted WAL segment.
3. If truly corrupted: stop the app tier, restore from the latest backup
   (see below), accept the RPO gap, document it in the post-mortem.

## Scenario: full server loss
1. Provision a replacement host:
   - Cloud: `make apply ENV=<env>` (with `enable_cloud_compute = true` and
     credentials configured) recreates the VM via
     `terraform/modules/compute`.
   - Bare metal/manual: provision Ubuntu 24.04 LTS by hand.
2. `ansible-playbook -i ansible/inventory/<env>.ini ansible/playbooks/docker-install.yml`
3. `ansible-playbook -i ansible/inventory/<env>.ini ansible/playbooks/harden.yml`
4. `git clone` this repo onto the new host, decrypt `envs/<env>.env` via SOPS.
5. `make plan ENV=<env> && make apply ENV=<env>` — recreates networks/volumes
   (empty at this point).
6. `make up ENV=<env>` — brings up Postgres/PgBouncer/Nginx/Odoo against
   **empty** volumes.
7. Restore from backups (this is the actual recovery step):
   ```bash
   ENVIRONMENT=<env> ./scripts/backup/restore_postgres.sh
   ENVIRONMENT=<env> ./scripts/backup/restore_filestore.sh
   ```
8. Point DNS at the new host's IP (`terraform/modules/dns`, or manually).
9. Re-issue TLS certificates: `./scripts/tls/issue_cert.sh <env>`.
10. `./scripts/deploy/smoke_test.sh <env>`.
11. Post-mortem: actual RTO achieved vs. target, what slowed it down.

## Scenario: data corruption / accidental deletion caught late
Point-in-time recovery via archived WAL (see `docker/postgres/postgresql.conf`
`archive_command`) lets you restore to just-before-the-bad-event instead of
just-to-last-daily-backup:

1. Identify the approximate timestamp just before the bad event (check Loki
   logs / Odoo's own chatter/audit trail for the offending action).
2. Restore the most recent daily base backup that predates that timestamp
   (`restore_postgres.sh`, but stop before starting Odoo).
3. Replay WAL segments from `postgres_wal_archive` up to (but not including)
   the target timestamp using `recovery_target_time` in a `recovery.signal`
   — this is a manual, careful procedure; practice it on a throwaway
   environment (`test-restore` gives you the muscle memory for the dump-restore
   half; the WAL-replay half needs its own drill — track this as a known gap,
   see `docs/ARCHITECTURE.md` limitations).
4. Validate before pointing the app at it.

## Disaster recovery drills (do these, don't just document them)
```bash
make chaos-db ENV=staging        # kill postgres, watch alerting + auto-recovery
make chaos-odoo ENV=staging      # kill the active color, watch failover
make chaos-disk ENV=staging      # simulate near-full disk, watch DiskAlmostFull alert
make test-restore ENV=staging    # weekly, non-destructive
```
Run the full "full server loss" drill at least quarterly, in staging, timed
end to end. If actual RTO exceeds the target above, that's the signal to
invest in faster provisioning (pre-baked AMI/image, more automation) rather
than a signal to just widen the RTO target.
