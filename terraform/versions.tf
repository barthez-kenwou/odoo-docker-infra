# =============================================================================
# Provider version pinning. Every provider is pinned with a `~>` (allow patch
# releases only) rather than left unbounded, per the "no latest, ever" rule
# that also applies to container images.
# =============================================================================
terraform {
  required_version = ">= 1.8.0, < 2.0.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
    # Only initialized when var.enable_cloud_dns = true (see modules/dns).
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.23.0"
    }
    # Only initialized when var.enable_cloud_storage = true (see modules/object_storage).
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60.0"
    }
    # Only initialized when var.enable_cloud_compute = true (see modules/compute).
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.47.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.2"
    }
  }
}
