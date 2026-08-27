# Environment files

Each environment reads its configuration from `envs/<environment>.env`, which
is **not** committed (see `.gitignore`). What *is* committed is an
`*.env.example` per environment documenting every variable.

## Local / dev

```bash
cp envs/dev.env.example envs/dev.env
# edit envs/dev.env with your own local values — never real secrets, this is
# purely local and disposable.
```

## Staging / production

Real values never touch the filesystem in clear text. They are:

1. Authored once as `envs/staging.env` / `envs/production.env` on a trusted
   workstation or directly in the target host's memory.
2. Encrypted in place with [SOPS](https://github.com/getsops/sops) + `age`
   (see `secrets/README.md`) and committed as
   `envs/staging.env.enc` / `envs/production.env.enc`.
3. Decrypted just-in-time by CI (`.github/workflows/deploy-staging.yml` /
   `promote-production.yml`) using an `age` private key held only in
   GitHub Actions encrypted secrets, or by `scripts/deploy/deploy.sh` on the
   target host using a key that never leaves that host.

The plaintext `envs/staging.env` / `envs/production.env` files exist only
transiently in CI runner memory / on the target host, never in Git history.
