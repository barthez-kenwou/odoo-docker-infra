#!/usr/bin/env bash
# =============================================================================
# Configures Odoo's outgoing mail server (ir.mail_server) via XML-RPC from
# SMTP_* variables in envs/<env>.env. Odoo has no config-file option for
# this — it's a database record — so this script is the "infrastructure as
# code" equivalent for that one setting, run once after first deploy and
# again any time SMTP credentials rotate.
# =============================================================================
set -euo pipefail
ENVIRONMENT="${1:?usage: configure_smtp.sh <dev|staging|production>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1090
set -a; source "${REPO_ROOT}/envs/${ENVIRONMENT}.env"; set +a

BASE_URL="${SMTP_CONFIG_ODOO_URL:-https://${SERVER_NAME}}"
[ "$ENVIRONMENT" = "dev" ] && BASE_URL="http://localhost"

python3 - << PYEOF
import xmlrpc.client
import os

url = "${BASE_URL}"
db = "${ODOO_DB_NAME}"
admin_user = "admin"
admin_password = "${ODOO_ADMIN_PASSWD}"

common = xmlrpc.client.ServerProxy(f"{url}/xmlrpc/2/common")
uid = common.authenticate(db, admin_user, admin_password, {})
models = xmlrpc.client.ServerProxy(f"{url}/xmlrpc/2/object")

values = {
    "name": "Lab SMTP relay (${ENVIRONMENT})",
    "smtp_host": "${SMTP_HOST}",
    "smtp_port": int("${SMTP_PORT}"),
    "smtp_user": "${SMTP_USER}",
    "smtp_pass": "${SMTP_PASSWORD}",
    "smtp_encryption": "starttls" if "${SMTP_TLS}" == "True" else "none",
    "sequence": 1,
}

existing = models.execute_kw(db, uid, admin_password, "ir.mail_server", "search", [[["name", "=", values["name"]]]])
if existing:
    models.execute_kw(db, uid, admin_password, "ir.mail_server", "write", [existing, values])
    print(f"[configure_smtp] updated existing ir.mail_server id={existing[0]}")
else:
    new_id = models.execute_kw(db, uid, admin_password, "ir.mail_server", "create", [values])
    print(f"[configure_smtp] created ir.mail_server id={new_id}")
PYEOF

echo "[configure_smtp] done for ${ENVIRONMENT}. Send a test email from Settings > Technical > Outgoing Mail Servers > Test Connection."
