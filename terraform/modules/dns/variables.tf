variable "environment"  { type = string }
variable "domain_root"  { type = string }
variable "server_ipv4"  {
  type        = string
  description = "Public IPv4 of the host serving this environment (module.compute output, or supplied manually)."
}
variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for domain_root. Read from a SOPS-decrypted tfvars file in CI, never committed."
  default     = ""
}
