# 3. SOPS + age for secrets management (not Vault/Infisical)

## Status
Accepted

## Context
The original requirements list Vault, Infisical, Doppler, and SOPS as
acceptable secret managers. Vault/Infisical are the "more enterprise" answer,
but they're also a *running service* that itself needs hardening, patching,
unsealing/HA, backup, and monitoring — i.e. exactly the kind of operational
burden this lab is trying to keep proportionate to a solo/small-team
context. SOPS is a CLI tool, not a service: nothing to keep alive.

## Decision
Use SOPS with `age` as the encryption backend for every secret this repo
needs to persist (environment files, sensitive tfvars). See
`secrets/README.md` for the full workflow.

## Consequences
- **Pro:** zero additional infrastructure; secrets get the same review/audit
  trail as code (`git log` on an encrypted file is a real audit log); trivial
  to reason about ("can I decrypt this file" is the entire access model).
- **Con:** no dynamic/short-lived credentials (a Postgres password from SOPS
  is long-lived until manually rotated, unlike Vault's database secrets
  engine which can mint a unique, auto-expiring credential per consumer).
- **Con:** no audit log of secret *reads*, only of ciphertext *changes*.
- **Migration trigger:** the day this needs (a) more than one team consuming
  secrets with different access levels, or (b) dynamic credentials, or (c) a
  read-level audit trail — switch to Vault/Infisical. The `k8s/` track
  already shows the shape of that migration via `ExternalSecret` resources
  pointing at a `ClusterSecretStore`.
