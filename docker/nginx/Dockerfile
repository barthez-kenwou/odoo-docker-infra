# =============================================================================
# Hardened reverse-proxy image (Nginx in front of Odoo).
# Pinned version, non-root (nginx:*-alpine already drops to the `nginx` user
# via master process privilege separation; we additionally run the container
# itself with a non-root UID at the Compose level — see docker-compose.base.yml).
# =============================================================================
FROM nginx:1.27.3-alpine3.20

LABEL org.opencontainers.image.title="odoo-devsecops-lab-nginx" \
      org.opencontainers.image.description="Hardened Nginx reverse proxy for the Odoo lab"

# curl for HEALTHCHECK only; nothing else added to keep the image minimal.
RUN apk add --no-cache curl=8.9.* \
    # Remove the default welcome page / default server block to avoid any
    # accidental information disclosure if a request slips through without
    # a matching Host header (default_server explicitly points at conf.d/00-catchall.conf).
    && rm -f /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY snippets/ssl-params.conf /etc/nginx/snippets/ssl-params.conf
# Templated at container start by the official nginx entrypoint
# (20-envsubst-on-templates.sh), which substitutes only the variables listed
# in NGINX_ENVSUBST_FILTER and writes the result to /etc/nginx/conf.d/.
COPY conf.d/odoo.conf.template /etc/nginx/templates/odoo.conf.template
COPY conf.d/00-catchall.conf.template /etc/nginx/templates/00-catchall.conf.template

# Directory for the blue/green "which upstream is active" file. This is
# intentionally OUTSIDE the templated conf.d flow: it is bind-mounted at
# runtime (see compose/docker-compose.base.yml) and rewritten in place by
# scripts/deploy/deploy.sh, then hot-reloaded with `nginx -s reload` — no
# image rebuild needed to flip blue<->green.
RUN mkdir -p /etc/nginx/active \
    && printf 'upstream odoo_active {\n    server odoo-blue:8069;\n}\n' > /etc/nginx/active/active_upstream.conf \
    && chown -R nginx:nginx /etc/nginx/active /var/cache/nginx

EXPOSE 80 443

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -fsS http://localhost/healthz -o /dev/null || exit 1
