# =============================================================================
# A single VPS to actually run this stack outside of localhost. Disabled by
# default (root variable `enable_cloud_compute`). Hetzner Cloud is used here
# as a concrete, inexpensive example provider — swap for AWS/OVH/DO by
# reimplementing this one module; nothing else in the repo depends on it.
#
# Ansible (../../ansible) takes over from here for OS-level hardening once
# the box exists; this module only provisions the VM and its firewall.
# =============================================================================

resource "hcloud_firewall" "app" {
  name = "${var.project_name}-${var.environment}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.admin_ipv4_cidrs
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  # Everything else — including Postgres 5432, PgBouncer 6432, Prometheus
  # 9090, Grafana 3000 — is deliberately absent: those are reached only over
  # the Docker-internal networks or through an SSH tunnel / WireGuard, never
  # from the public Internet. See docs/runbooks/troubleshooting.md.
}

resource "hcloud_ssh_key" "ops" {
  name       = "${var.project_name}-${var.environment}-ops"
  public_key = var.ssh_public_key
}

resource "hcloud_server" "app" {
  name        = "${var.project_name}-${var.environment}"
  server_type = var.server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.ops.id]
  firewall_ids = [hcloud_firewall.app.id]

  labels = {
    environment = var.environment
    project     = var.project_name
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
