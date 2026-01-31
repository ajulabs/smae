# Firewall rule: Allow health checks from Google Load Balancer
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.resource_prefix}-allow-health-check"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["45000", "45902", "45903"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["allow-health-check"]

  description = "Allow health check traffic from Google Cloud Load Balancer"
}

# Firewall rule: Allow traffic from Load Balancer to VM
resource "google_compute_firewall" "allow_lb_to_vm" {
  name    = "${var.resource_prefix}-allow-lb-to-vm"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["45000", "45902", "45903"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["allow-lb"]

  description = "Allow traffic from Google Cloud Load Balancer to application VM"
}

# Firewall rule: Allow SSH via Identity-Aware Proxy
resource "google_compute_firewall" "allow_iap_ssh" {
  count   = var.enable_iap ? 1 : 0
  name    = "${var.resource_prefix}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = concat(
    ["35.235.240.0/20"],
    var.ssh_source_ranges
  )

  target_tags = ["${var.resource_prefix}-app"]

  description = "Allow SSH access via Identity-Aware Proxy"
}

# Firewall rule: Deny all other inbound traffic (implicit, but explicit for clarity)
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "${var.resource_prefix}-deny-all-ingress"
  network  = google_compute_network.vpc.name
  priority = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  description = "Explicit deny rule for all other inbound traffic"
}
