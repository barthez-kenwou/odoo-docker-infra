# =============================================================================
# Custom Odoo image
#
# Design notes (see docs/adr/0002 for the full reasoning):
#   - Base image and Python wheel builder are both version-pinned by digest-
#     friendly tags (never `latest`).
#   - Multi-stage build: a throwaway "wheels" stage compiles any extra Python
#     dependencies required by custom addons, so the final image never carries
#     a C compiler / build toolchain (smaller attack surface, smaller image).
#   - Runs as the non-root `odoo` user (already created by the upstream image).
#   - HEALTHCHECK lets Compose/Kubernetes detect a wedged worker.
#   - No secrets are baked into the image: odoo.conf is a template rendered at
#     container start by entrypoint.sh from environment variables injected by
#     Compose (dev/staging) or External Secrets Operator (Kubernetes bonus).
# =============================================================================

# NOTE ON BUILD CONTEXT: this image is built with the *repository root* as
# context (see compose/docker-compose.base.yml: `context: .., dockerfile:
# docker/odoo/Dockerfile`) so that it can COPY the shared `addons/` tree
# without reaching outside the build context. Keep all COPY paths below
# relative to the repo root.

# ---- Stage 1: build wheels for custom addon Python dependencies ----
FROM python:3.14.6-slim-bookworm AS wheels
WORKDIR /wheels
COPY docker/odoo/requirements.txt .
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential=12.9 libpq-dev=15.* \
    && rm -rf /var/lib/apt/lists/* \
    && pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---- Stage 2: final runtime image ----
# Pin the exact Odoo release. Bump deliberately, never track a moving tag.
FROM odoo:18.0

LABEL org.opencontainers.image.title="odoo-devsecops-lab" \
      org.opencontainers.image.description="Hardened Odoo runtime image for the DevSecOps lab" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/example-org/odoo-devsecops-lab"

USER root

# Only what's strictly needed at runtime (curl for HEALTHCHECK, gettext for
# envsubst used by the entrypoint to render odoo.conf from a template).
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl=7.88.* gettext-base=0.21-* \
    && rm -rf /var/lib/apt/lists/*

# Install any custom-addon Python dependencies from the prebuilt wheels only
# (--no-index): the final image never talks to PyPI, which keeps the build
# reproducible and removes a supply-chain vector.
COPY --from=wheels /wheels /wheels
COPY docker/odoo/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r /tmp/requirements.txt \
    && rm -rf /wheels /tmp/requirements.txt

# Custom addons and the config template. Ownership is set explicitly so the
# non-root `odoo` user (uid 101 upstream) can read everything it needs and
# nothing it doesn't.
COPY --chown=odoo:odoo addons/custom /mnt/extra-addons
COPY --chown=odoo:odoo docker/odoo/odoo.conf.template /etc/odoo/odoo.conf.template
COPY --chown=odoo:odoo docker/odoo/entrypoint.sh /entrypoint.sh
RUN chmod 750 /entrypoint.sh \
    && mkdir -p /var/lib/odoo /var/log/odoo \
    && chown -R odoo:odoo /var/lib/odoo /var/log/odoo /etc/odoo

# Drop privileges for the remainder of the image lifetime.
USER odoo

# Odoo's own longpolling port (8072) is also exposed for websocket/proxy_mode.
EXPOSE 8069 8072

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:8069/web/login -o /dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
