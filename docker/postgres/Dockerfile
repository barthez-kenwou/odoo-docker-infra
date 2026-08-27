# =============================================================================
# PostgreSQL image: pinned upstream + hardened config baked in as defaults.
# The actual config file used at runtime is passed explicitly via
# `-c config_file=...` in compose so it's easy to see what's active.
# =============================================================================
FROM postgres:17.5-alpine3.20

LABEL org.opencontainers.image.title="odoo-devsecops-lab-postgres" \
      org.opencontainers.image.description="Hardened PostgreSQL for the Odoo lab"

COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY pg_hba.conf /etc/postgresql/pg_hba.conf
COPY init/ /docker-entrypoint-initdb.d/

# init scripts must be executable to be picked up by the upstream entrypoint
RUN chmod 0755 /docker-entrypoint-initdb.d/*.sh \
    && chown -R postgres:postgres /etc/postgresql

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=5 \
    CMD pg_isready -U "${POSTGRES_USER:-postgres}" -h 127.0.0.1 || exit 1
