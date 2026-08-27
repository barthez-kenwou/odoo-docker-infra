# =============================================================================
# Three Docker networks implementing the mandated public/private/database
# tier segmentation. Fixed subnets so that firewall/pg_hba/nginx allow-lists
# elsewhere in the repo can reference stable CIDRs instead of "whatever
# Docker picked this time".
# =============================================================================

resource "docker_network" "public" {
  name   = "${var.project_name}-${var.environment}-public"
  driver = "bridge"

  ipam_config {
    subnet = var.public_subnet_cidr
  }

  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "tier"
    value = "public"
  }
}

resource "docker_network" "private" {
  name   = "${var.project_name}-${var.environment}-private"
  driver = "bridge"

  ipam_config {
    subnet = var.private_subnet_cidr
  }

  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "tier"
    value = "private"
  }
}

resource "docker_network" "database" {
  name     = "${var.project_name}-${var.environment}-database"
  driver   = "bridge"
  internal = true # no default route to the outside world — enforces
                   # "no internal service is ever directly exposed to / can
                   # reach the Internet" at the network layer, not just via
                   # the absence of published ports.

  ipam_config {
    subnet = var.database_subnet_cidr
  }

  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "tier"
    value = "database"
  }
}
