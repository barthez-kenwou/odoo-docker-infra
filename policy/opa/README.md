# Policy-as-Code (OPA / Conftest)

These Rego policies are enforced by `.github/workflows/pr-checks.yml` via
[Conftest](https://www.conftest.dev/) and act as a hard **security gate**:
a violation of a `deny` rule fails the pipeline, per the checklist item
"Security gates bloquant les releases critiques".

Run locally:

```bash
conftest test --policy policy/opa/terraform_plan.rego  terraform/plan.json
conftest test --policy policy/opa/compose.rego         compose/*.yml
conftest test --policy policy/opa/dockerfile.rego       docker/*/Dockerfile
```

| File                  | Checks                                                            |
|-----------------------|--------------------------------------------------------------------|
| `terraform_plan.rego` | The database network must stay `internal = true`; no public S3 ACLs |
| `compose.rego`        | No `:latest` tags; every service drops `ALL` capabilities; resource limits set |
| `dockerfile.rego`     | No `USER root` as the final user; no secrets baked in via `ARG`/`ENV` |
