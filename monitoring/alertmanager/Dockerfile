# Thin wrapper around the official Alertmanager image that renders its config
# from a template at container start (Alertmanager has no native env-var
# substitution), so webhook URLs/SMTP creds never need to be baked in or
# committed in clear text.
FROM prom/alertmanager:v0.27.0

USER root
# The upstream image is distroless-ish (no apk/apt); grab a static envsubst
# binary equivalent via busybox's `sh` + a minimal POSIX substitution script
# instead of installing a package (there is no package manager here).
COPY entrypoint.sh /entrypoint.sh
COPY alertmanager.yml.template /etc/alertmanager/alertmanager.yml.template
RUN chmod +x /entrypoint.sh

USER nobody
ENTRYPOINT ["/entrypoint.sh"]
