# =============================================================================
# Remote state backend.
#
# ACTIVE CONFIGURATION: local backend. This lab ships with a local backend so
# `terraform init` works out of the box with zero external accounts. Local
# state is fine for a single-operator lab; it is NOT fine for a team.
#
# For anything beyond a solo lab, switch to a real remote backend with
# locking — the S3-compatible example below (works against AWS S3 or any
# S3-API object store: MinIO, Backblaze B2, OVH Object Storage, etc.) is the
# one this project is designed around. Terraform >=1.6 supports native S3
# locking via `use_lockfile` (no separate DynamoDB table required).
#
#   terraform {
#     backend "s3" {
#       bucket       = "odoo-lab-tfstate"
#       key          = "odoo-lab/terraform.tfstate"
#       region       = "eu-west-3"
#       encrypt      = true
#       use_lockfile = true   # state locking, no DynamoDB table needed (TF >= 1.6)
#     }
#   }
#
# Migrating: uncomment the block above, comment out the `backend "local"`
# block below, then run `terraform init -migrate-state`.
# =============================================================================
terraform {
  backend "local" {
    path = "terraform.tfstate.d/terraform.tfstate"
  }
}
