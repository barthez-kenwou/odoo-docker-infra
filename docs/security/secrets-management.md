# Secrets management — policy overview

The operational how-to (day-to-day SOPS commands, CI wiring, rotation
procedure) lives in `secrets/README.md` next to the actual config. This page
covers the policy decisions behind it.

## What counts as a secret
Any of: database passwords, the Odoo admin/master password, SMTP
credentials, Slack/Telegram webhook URLs and bot tokens, TLS private keys,
cloud provider API tokens (Cloudflare/AWS/Hetzner), SSH private keys, cosign
private keys (if using key-based signing locally instead of keyless/OIDC),
and the `age` private keys used to decrypt everything else.

## Where each category lives
| Secret category         | At rest                                   | In use (runtime)                     |
|---------------------------|----------------------------------------------|------------------------------------------|
| App/DB credentials        | `envs/<env>.env.enc` (SOPS)                    | Container env vars, injected at deploy   |
| TLS private keys          | Never in Git — cert volume, or CI secret for the `age` key that decrypts them if pre-provisioned | `nginx_certs` Docker volume |
| CI-to-infra credentials   | GitHub Actions encrypted secrets              | Injected as workflow env vars, scoped per job |
| SSH keys (host access)    | Never in Git; private key on the operator's machine / CI secret, public key via `terraform/modules/compute` | `~/.ssh/authorized_keys` on the target host |
| Kubernetes (bonus track)  | External secret store (Vault/Infisical) via `ExternalSecret` | Mounted as a Kubernetes `Secret` |

## Decision: see ADR-0003
Why SOPS+age instead of Vault/Infisical is documented in
`docs/adr/0003-sops-age-for-secrets-management.md`, including the explicit
trigger for when to migrate.

## Non-negotiables (see also the CI gate that enforces the first one)
1. Nothing decrypted is ever committed, logged, or uploaded as a CI
   artifact. Every workflow that decrypts a secret also cleans it up in an
   `if: always()` step.
2. No secret is ever passed as a Dockerfile `ARG`/`ENV` baked into an image
   layer — everything is injected at container **runtime** (Compose
   `environment:` from the decrypted `.env`, or Kubernetes `Secret`).
3. A secret compromised (or even suspected compromised) gets rotated, not
   just "monitored" — see the rotation procedure in `secrets/README.md`.
