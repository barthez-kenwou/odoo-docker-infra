#!/bin/sh
# =============================================================================
# POSIX-shell env-var substitution (no `envsubst` binary available on the
# distroless-style upstream Alertmanager image) followed by exec'ing the
# real Alertmanager binary as PID 1.
# =============================================================================
set -eu

TEMPLATE=/etc/alertmanager/alertmanager.yml.template
RENDERED=/tmp/alertmanager.yml

render() {
  # Whitelisted variables only — mirrors the pattern used by
  # docker/odoo/entrypoint.sh, just implemented without envsubst.
  awk '
    { line = $0
      for (i = 1; i <= n; i++) {
        gsub(vars[i], values[i], line)
      }
      print line
    }
  ' \
    -v n=9 \
    -v "vars[1]=\\$\\{SLACK_WEBHOOK_URL\\}" -v "values[1]=${SLACK_WEBHOOK_URL:-}" \
    -v "vars[2]=\\$\\{ALERT_EMAIL_TO\\}" -v "values[2]=${ALERT_EMAIL_TO:-}" \
    -v "vars[3]=\\$\\{ALERT_EMAIL_FROM\\}" -v "values[3]=${ALERT_EMAIL_FROM:-}" \
    -v "vars[4]=\\$\\{SMTP_HOST\\}" -v "values[4]=${SMTP_HOST:-}" \
    -v "vars[5]=\\$\\{SMTP_PORT\\}" -v "values[5]=${SMTP_PORT:-}" \
    -v "vars[6]=\\$\\{SMTP_USER\\}" -v "values[6]=${SMTP_USER:-}" \
    -v "vars[7]=\\$\\{SMTP_PASSWORD\\}" -v "values[7]=${SMTP_PASSWORD:-}" \
    -v "vars[8]=\\$\\{TELEGRAM_BOT_TOKEN\\}" -v "values[8]=${TELEGRAM_BOT_TOKEN:-}" \
    -v "vars[9]=\\$\\{TELEGRAM_CHAT_ID\\}" -v "values[9]=${TELEGRAM_CHAT_ID:-0}" \
    "$TEMPLATE" > "$RENDERED"
}

render
exec /bin/alertmanager --config.file="$RENDERED" --storage.path=/alertmanager "$@"
