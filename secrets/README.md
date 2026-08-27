# Secrets management

**Rule zero:** nothing under this repo's version control is ever a real
secret in clear text — not in `envs/`, not in `terraform/*.tfvars`, not in a
Dockerfile `ARG`, not in a GitHub Actions workflow. Grep for `REPLACE_ME` /
`CHANGE_ME` across the repo before your first real deployment; every match
is a value you must generate and place into the secret manager below, never
into Git.

## Why SOPS + age (and not Vault, here)

The checklist this lab is built from name-checks Vault/Infisical/Doppler as
valid choices. This repo ships **SOPS + age** as the actually-wired-up
implementation because:

- It requires **no running service** — no Vault server to harden, patch,
  unseal, and back up in a solo/small-team lab. One less thing to keep alive.
- Encrypted secrets live *in Git*, next to the code that needs them, and get
  the same review/audit trail as everything else (`git log` on a `.env.enc`
  file **is** your access/change audit log).
- It's exactly what a small team promotes an app with in CI without standing
  up more infrastructure than the app itself.

**When to graduate to Vault/Infisical:** once you have >1 team consuming
secrets, need dynamic/short-lived database credentials, or need a real
audit-log-with-alerting on every secret *read* (not just every change) —
SOPS can't do that, Vault can. `docs/security/secrets-management.md` covers
the migration path.

## One-time setup

```bash
# 1. Generate an age keypair per environment (or one shared ops key — your call)
age-keygen -o secrets/age-staging.key      # NEVER commit this file (see .gitignore)
age-keygen -o secrets/age-production.key

# 2. Copy the "public key: age1..." line printed above into secrets/.sops.yaml

# 3. Store the PRIVATE key in GitHub Actions encrypted secrets, not in the
#    repo and not on a laptop:
gh secret set SOPS_AGE_KEY_STAGING    --repo example-org/odoo-devsecops-lab < secrets/age-staging.key
gh secret set SOPS_AGE_KEY_PRODUCTION --repo example-org/odoo-devsecops-lab < secrets/age-production.key
rm secrets/age-staging.key secrets/age-production.key   # never keep local copies around
```

## Day-to-day usage

```bash
# Author/edit a secret file in your $EDITOR, transparently encrypted on save:
sops envs/staging.env.enc

# Encrypt a plaintext file you already have (then delete the plaintext):
sops -e envs/staging.env > envs/staging.env.enc && shred -u envs/staging.env

# Decrypt just to inspect (never redirect this to a committed path):
sops -d envs/staging.env.enc
```

CI decrypts just-in-time inside `.github/workflows/deploy-staging.yml` /
`promote-production.yml`:

```yaml
- name: Decrypt environment file
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY_STAGING }}
  run: sops -d envs/staging.env.enc > envs/staging.env
```

The decrypted file exists only in the ephemeral runner's filesystem for the
duration of the job and is never uploaded as a build artifact.

## Rotation

Rotate `POSTGRES_SUPERUSER_PASSWORD`, `ODOO_DB_PASSWORD`,
`PGBOUNCER_AUTH_PASSWORD`, `PG_EXPORTER_PASSWORD`, and SMTP credentials every
90 days (or immediately after any suspected exposure). Procedure:

1. Generate the new value, `sops` edit the relevant `envs/<env>.env.enc`.
2. `make deploy ENV=<env>` — blue/green means the new credentials roll out
   with zero downtime (the idle color starts with the new secret, gets
   health-checked, then traffic flips — see `docs/adr/0005`).
3. Revoke the old Postgres role password immediately after the flip
   (`ALTER ROLE ... PASSWORD ...` again, or drop+recreate for the pgbouncer
   auth role) so the old credential can never be reused even if it leaked.

## Access audit

`git log -p -- envs/*.env.enc terraform/environments/*.tfvars.enc` is the
audit trail for "who changed which secret's ciphertext and when" (SOPS
diffs cleanly because it re-encrypts deterministically per key, not per
byte). Branch protection (`docs/security/hardening-checklist.md`) ensures
every such change went through a reviewed Pull Request.
