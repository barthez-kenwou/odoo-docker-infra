# FinOps notes

This lab runs on a single Docker host (or localhost) by default, so "cost"
is mostly hypothetical until `enable_cloud_compute`/`enable_cloud_dns`/
`enable_cloud_storage` are switched on in `terraform/environments/*.tfvars`.
This document is the placeholder for that moment, not a live cost dashboard.

## Cost centers once cloud modules are enabled
| Resource                                   | Where provisioned                    | Rough cost driver |
|-----------------------------------------------|------------------------------------------|----------------------|
| VPS (staging + production)                  | `terraform/modules/compute` (Hetzner)     | Fixed monthly per instance size |
| S3 backup bucket                            | `terraform/modules/object_storage` (AWS)  | Storage volume + Glacier transitions + requests |
| DNS                                         | `terraform/modules/dns` (Cloudflare)      | Free tier covers this lab's needs |
| Container registry                          | GHCR (free for public, metered for private) or self-hosted Harbor (VM cost only) | Storage + egress |

## Right-sizing
- Compose resource `limits`/`reservations` in
  `docker-compose.{staging,production}.yml` are the enforcement point —
  don't size the underlying VM bigger than the sum of what's actually
  reserved plus headroom; re-tune based on real
  `tests/load/k6_load_test.js` results (see
  `docs/runbooks/troubleshooting.md#workerresource-sizing`).
- restic's deduplication means incremental backup storage growth is much
  smaller than "daily full dump size × retention count" — monitor actual
  bucket growth after the first month rather than estimating from
  first-principles.

## Storage lifecycle
`terraform/modules/object_storage`'s lifecycle rule already transitions
noncurrent backup versions to Glacier after 30 days and expires them after
365 — the single biggest lever for backup cost control in this repo.

## Cost forecasting (manual, for now)
No automated cost dashboard is wired up (would typically be a Grafana panel
backed by the Infracost or cloud provider's billing API/Cost Explorer export
— a reasonable next addition once real cloud spend exists to track). Until
then: check the cloud provider's billing console monthly and compare against
the previous month, flagging anything that grew faster than user/data
growth would explain.

## Per-environment cost awareness
Because dev/staging/production are structurally identical (ADR-0002), the
main cost lever *between* environments is instance size and whether staging
even needs to run 24/7 — consider a scheduled stop/start for staging outside
business hours if cost ever matters more than always-on staging
availability (a Compose-based stack makes "stop the whole staging VM
overnight" trivial and safe, unlike a shared Kubernetes cluster).
