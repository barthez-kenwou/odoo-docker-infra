# Runbook: Backup & Restore

## Backup schedule (what should be running)
| What          | Script                              | Frequency        | Retention                          |
|---------------|--------------------------------------|-------------------|-------------------------------------|
| Postgres      | `scripts/backup/backup_postgres.sh`  | Daily (cron/timer) | 30 daily / 8 weekly / 12 monthly    |
| Filestore     | `scripts/backup/backup_filestore.sh` | Daily              | 30 daily / 8 weekly / 12 monthly    |
| Restore drill | `scripts/backup/test_restore.sh`     | Weekly             | n/a (non-destructive validation)    |

Install as systemd timers on the host (see `ansible/roles/hardening` for
where to add these, or install directly):

```ini
# /etc/systemd/system/odoo-lab-backup.service
[Service]
Type=oneshot
Environment=ENVIRONMENT=production
WorkingDirectory=/opt/odoo-lab
ExecStart=/opt/odoo-lab/scripts/backup/backup_postgres.sh
ExecStartPost=/opt/odoo-lab/scripts/backup/backup_filestore.sh

# /etc/systemd/system/odoo-lab-backup.timer
[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true
[Install]
WantedBy=timers.target
```

## Manual backup
```bash
make backup ENV=production
make backup-filestore ENV=production
```

## Non-destructive restore verification (do this weekly, not just when scared)
```bash
make test-restore ENV=production
```
This restores the latest snapshot into a throwaway, disposable Postgres
container — completely isolated from the real environment — and runs a
sanity query. A backup you have never test-restored is a backup you don't
actually have.

## Full restore (destructive — real incident)
See `docs/runbooks/disaster-recovery.md` for the complete incident
procedure. The short version:
```bash
make down ENV=production                  # or targeted: stop odoo-blue/green only
ENVIRONMENT=production ./scripts/backup/restore_postgres.sh
ENVIRONMENT=production ./scripts/backup/restore_filestore.sh
make up ENV=production
./scripts/deploy/smoke_test.sh production
```
Both restore scripts require typing the environment name back as
confirmation — there is no `--yes` flag, on purpose.

## Consistency between Postgres and the filestore
Odoo stores file attachments on disk (filestore) but references them by hash
from Postgres. Always restore **both** from snapshots taken in the same
backup run (same date) — mixing a Tuesday DB dump with a Thursday filestore
archive will leave dangling/missing attachment references. `test_restore.sh`
only validates the DB side; if you need to validate cross-consistency,
restore both into a throwaway stack and open the Attachments list in the UI.

## Where backups live
`RESTIC_REPOSITORY` in `envs/<env>.env` points at the S3 bucket provisioned
by `terraform/modules/object_storage` (versioned, encrypted, TLS-only,
public access blocked). For a pure-local lab without cloud credentials,
point it at a local path instead (`RESTIC_REPOSITORY=/mnt/backup-disk/odoo-lab`)
— restic doesn't care.
