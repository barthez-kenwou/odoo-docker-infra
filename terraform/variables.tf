variable "project_name" {
  description = "Short project slug, used as a prefix for every resource name."
  type        = string
  default     = "odoo-lab"
}

variable "environment" {
  description = "Deployment environment. Drives naming, isolation, and which optional cloud modules make sense to enable."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

# --- Fixed subnets (kept in sync with docker/postgres/pg_hba.conf and the
# nginx stub_status allow-list — see docs/security/hardening-checklist.md) ---
variable "public_subnet_cidr" {
  type    = string
  default = "172.28.0.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "172.28.1.0/24"
}

variable "database_subnet_cidr" {
  type    = string
  default = "172.28.2.0/24"
}

# --- Optional cloud modules (disabled by default: this lab is fully
# runnable on a single Docker host with zero cloud accounts). Flip these on
# and supply the corresponding provider credentials to provision the real
# infrastructure described in modules/{dns,object_storage,compute}. ---
variable "enable_cloud_dns" {
  description = "Provision DNS records (Cloudflare) for this environment's subdomain."
  type        = bool
  default     = false
}

variable "enable_cloud_storage" {
  description = "Provision an S3 bucket (AWS) as the encrypted, versioned, immutable backup destination for restic."
  type        = bool
  default     = false
}

variable "enable_cloud_compute" {
  description = "Provision a VPS (Hetzner Cloud) to actually run this stack outside of localhost."
  type        = bool
  default     = false
}

variable "domain_root" {
  description = "Root domain used to build environment subdomains (e.g. odoo.example.com / staging-odoo.example.com)."
  type        = string
  default     = "example.com"
}
