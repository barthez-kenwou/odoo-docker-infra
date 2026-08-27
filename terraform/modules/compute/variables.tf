variable "project_name"  { type = string }
variable "environment"   { type = string }
variable "server_type"   {
  type    = string
  default = "cx32" # 4 vCPU / 8GB — comfortable for staging; bump for production
}
variable "location" {
  type    = string
  default = "nbg1"
}
variable "ssh_public_key" {
  type        = string
  description = "Public key installed for the ops user; the matching private key never touches this repo (see docs/security/secrets-management.md)."
}
variable "admin_ipv4_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach SSH (22) — your office/VPN/Tailscale range, never 0.0.0.0/0."
}
