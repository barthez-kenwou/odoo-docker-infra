# Kubernetes track (bonus / extension)

Everything under `k8s/` is the "what this looks like on Kubernetes instead of
Docker Compose" extension referenced in the original lab spec. It is
**not** required to run the core lab — `compose/` + `terraform/` +
`.github/workflows/` is the fully working, primary deliverable. This
directory demonstrates the same architecture re-expressed with Kubernetes
primitives, for the parts that meaningfully change:

| Concern                     | Compose (primary)                          | Kubernetes (this directory)                     |
|------------------------------|---------------------------------------------|--------------------------------------------------|
| Scaling                     | Fixed `ODOO_WORKERS`, single container      | `HorizontalPodAutoscaler` on CPU/memory            |
| Blue/green                  | `deploy.sh` flips an Nginx upstream file    | `Rollout`-style promotion via Argo CD sync waves / a second Helm release |
| Secrets                     | SOPS-encrypted `.env` files                 | `ExternalSecret` pulling from Vault/Infisical      |
| TLS                         | certbot sidecar + Nginx                     | `cert-manager` + Ingress annotations               |
| Availability                | `restart: unless-stopped`                   | `PodDisruptionBudget` + multi-node scheduling      |
| Network segmentation        | 3 Docker networks (public/private/database) | `NetworkPolicy` default-deny + explicit allow rules |
| GitOps                      | manual `make deploy` / SSH+Compose in CI    | Argo CD watching this repo, auto-sync + self-heal   |

PostgreSQL itself is intentionally **not** reimplemented as a hand-rolled
StatefulSet here — in a real Kubernetes deployment you'd run it via a
maintained operator (e.g. CloudNativePG or Zalando's postgres-operator) or a
managed cloud database, not bespoke YAML. Wire `postgresql.host` in
`values.yaml` to whichever you choose.

> **Validation note:** this chart was authored and reviewed carefully (brace
> balance and `if`/`with`/`end` block matching checked programmatically) but
> was written without a live cluster or the `helm` binary available in the
> authoring environment. Run `helm lint k8s/helm/odoo` and
> `helm template k8s/helm/odoo --debug` before your first real deploy.

## Layout

```
k8s/
├── helm/odoo/          Helm chart for the Odoo Deployment + supporting resources
├── argocd/              Argo CD Application manifests (staging + production)
└── policies/            Cluster-wide Pod Security / NetworkPolicy baselines
```

## Try it (kind/minikube)

```bash
helm install odoo-staging k8s/helm/odoo -f k8s/helm/odoo/values-staging.yaml -n odoo-staging --create-namespace
kubectl apply -f k8s/policies/
```
