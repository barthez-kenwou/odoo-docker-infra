# =============================================================================
# Named Docker volumes for every piece of state that must survive a
# `docker compose down` / container recreation. Kept as a Terraform module
# (rather than letting Compose auto-create anonymous/implicit volumes) so
# they have a stable, predictable lifecycle independent of the app stack —
# `docker compose down` never accidentally deletes them, and `terraform plan`
# clearly shows if a volume would be destroyed.
# =============================================================================

resource "docker_volume" "postgres_data" {
  name = "${var.project_name}-${var.environment}-postgres-data"
  labels {
    label = "environment"
    value = var.environment
  }
}

resource "docker_volume" "postgres_wal_archive" {
  name = "${var.project_name}-${var.environment}-postgres-wal-archive"
  labels {
    label = "environment"
    value = var.environment
  }
}

resource "docker_volume" "odoo_filestore" {
  name = "${var.project_name}-${var.environment}-odoo-filestore"
  labels {
    label = "environment"
    value = var.environment
  }
}

resource "docker_volume" "backups" {
  name = "${var.project_name}-${var.environment}-backups"
  labels {
    label = "environment"
    value = var.environment
  }
}
