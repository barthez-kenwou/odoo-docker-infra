# =============================================================================
# PgBouncer connection pooler, built from Alpine directly (no third-party
# Docker Hub image) so the full supply chain is auditable from this Dockerfile.
# =============================================================================
FROM alpine:3.24.1

LABEL org.opencontainers.image.title="odoo-devsecops-lab-pgbouncer" \
      org.opencontainers.image.description="Connection pooler between Odoo and PostgreSQL"

RUN apk add --no-cache pgbouncer=1.22.* postgresql16-client=16.* gettext=0.22.* bash=5.2.*

COPY pgbouncer.ini.template /etc/pgbouncer/pgbouncer.ini.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && mkdir -p /pgbouncer-userlist \
    && addgroup -S pgbouncer 2>/dev/null || true \
    && adduser -S -D -H -G pgbouncer pgbouncer 2>/dev/null || true \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer /pgbouncer-userlist

USER pgbouncer
EXPOSE 6432

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=5 \
    CMD pg_isready -h 127.0.0.1 -p 6432 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
