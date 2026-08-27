# =============================================================================
# Root module — wires together the always-on local infrastructure (Docker
# networks + volumes, used by every environment) and the optional cloud
# modules (DNS / object storage / compute), which stay dormant unless their
# `enable_cloud_*` flag is flipped and real provider credentials are supplied.
# =============================================================================

provider "docker" {}

# Configured but unused unless var.enable_cloud_dns = true. Credentials come
# from CLOUDFLARE_API_TOKEN in the environment (injected by CI from the
# secret manager — see docs/security/secrets-management.md), never from a
# committed file.
provider "cloudflare" {}

# Configured but unused unless var.enable_cloud_storage = true. Standard AWS
# credential chain (env vars / shared config / OIDC in CI).
provider "aws" {
  region = "eu-west-3"
}

# Configured but unused unless var.enable_cloud_compute = true. Credentials
# via HCLOUD_TOKEN.
provider "hcloud" {}

module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  environment          = var.environment
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr
  database_subnet_cidr = var.database_subnet_cidr
}

module "volumes" {
  source = "./modules/volumes"

  project_name = var.project_name
  environment  = var.environment
}

# --- Optional: real compute to run the stack on ---
module "compute" {
  source = "./modules/compute"
  count  = var.enable_cloud_compute ? 1 : 0

  project_name     = var.project_name
  environment      = var.environment
  ssh_public_key   = file("~/.ssh/odoo_lab_ops.pub")
  admin_ipv4_cidrs = ["203.0.113.0/24"] # replace with your real admin/VPN CIDR
}

# --- Optional: DNS pointed at that compute (or at a manually-provided IP) ---
module "dns" {
  source = "./modules/dns"
  count  = var.enable_cloud_dns ? 1 : 0

  environment        = var.environment
  domain_root        = var.domain_root
  server_ipv4        = var.enable_cloud_compute ? module.compute[0].server_ipv4 : "203.0.113.10"
  cloudflare_zone_id = "" # populate from a SOPS-decrypted var file, never committed
}

# --- Optional: encrypted, versioned S3 bucket for restic backups ---
module "object_storage" {
  source = "./modules/object_storage"
  count  = var.enable_cloud_storage ? 1 : 0

  project_name = var.project_name
  environment  = var.environment
}
