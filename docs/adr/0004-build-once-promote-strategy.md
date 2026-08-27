# 4. Build once, promote the validated artifact

## Status
Accepted

## Context
A tempting shortcut is "just rebuild the image for production with
`ENV=production` flags." That silently reintroduces the exact risk
CI/CD scanning is supposed to eliminate: the image running in production is
no longer bit-for-bit the one that passed Trivy/Grype/DAST in staging.

## Decision
`.github/workflows/build-and-scan.yml` is the **only** workflow that ever
runs `docker build`. It produces one immutable, digest-addressed,
Trivy/Grype-scanned, SBOM-attested, cosign-signed image per component per
commit. `deploy-staging.yml` deploys that exact digest. `promote-production.yml`
re-verifies (never rebuilds) the exact same digest and deploys it to
production. Environment-specific behavior (workers, log level, resource
limits) is expressed entirely through environment variables and Compose
overrides at *runtime*, never through different build-time flags.

## Consequences
- `envs/staging.env` / `envs/production.env` pin `*_IMAGE` to
  `...@sha256:<digest>`, never to a mutable tag — see
  `scripts/deploy/promote_image.sh`.
- A vulnerability found by the nightly re-scan
  (`scheduled-security-scan.yml`) is unambiguous: it affects both staging and
  production identically, because they're running the same bits.
- The trade-off is that a production-only config bug can't be "just add a
  build flag" — it has to be solvable via env vars/Compose overrides. In
  practice this constraint has been a net positive: it forces genuinely
  environment-agnostic images.
