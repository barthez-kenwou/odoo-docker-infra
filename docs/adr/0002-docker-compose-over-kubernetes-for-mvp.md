# 2. Docker Compose (not Kubernetes) is the primary deployment target

## Status
Accepted

## Context
The obvious "serious DevSecOps" answer is "put it on Kubernetes." But this
lab's actual constraints are: one operator, one (or a couple of) VMs, and a
genuine need to demonstrate depth in security/CI/CD/observability rather than
breadth in cluster operations. Running a real, hardened Kubernetes cluster
(etcd backups, control-plane upgrades, CNI choice, cluster-level RBAC) is its
own multi-week project, largely orthogonal to the DevSecOps practices this
lab is actually meant to prove out.

## Decision
Docker Compose + Terraform (for networks/volumes, and optionally cloud
compute/DNS/storage) is the **primary, fully-implemented** target. A
Kubernetes track exists under `k8s/` as a **documented extension** showing
the same architecture re-expressed with Kubernetes primitives (HPA, PDB,
NetworkPolicy, ExternalSecret, Argo CD) — see `k8s/README.md` — but it is
explicitly a bonus, not the thing this repo depends on to prove its point.

## Consequences
- Every environment (dev/staging/production) runs the *exact same* Compose
  topology (see ADR-0004's "build once" principle and the environment-parity
  goal), just with different resource limits/certs/domains — this is
  achievable and fully tested with Compose in a way a half-finished
  Kubernetes setup would not be.
- Horizontal scaling in the Compose world is vertical (bigger
  `ODOO_WORKERS`/CPU/memory) rather than adding replicas; the Kubernetes
  track is where real horizontal pod autoscaling lives if/when that's needed.
- Blue/green here is implemented by hand (an Nginx upstream file flip) rather
  than a scheduler primitive — see ADR-0005.
- If this project ever needs true multi-node HA, that's the trigger to
  promote `k8s/` from "bonus" to "primary" — not before.
