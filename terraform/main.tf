# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.resource_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Cloud NAT for outbound internet access
resource "google_compute_router_nat" "nat" {
  name   = "${var.resource_prefix}-nat"
  router = google_compute_router.router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Static IP for Load Balancer
resource "google_compute_global_address" "lb_ip" {
  name = "${var.resource_prefix}-lb-ip"
}

# VM Instance
resource "google_compute_instance" "app_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["${var.resource_prefix}-app", "allow-health-check", "allow-lb"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.boot_disk_size_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    
    # Configure Docker to use Artifact Registry
    gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet
    
    # Install docker-credential-gcr if not present
    if ! command -v docker-credential-gcr &> /dev/null; then
      VERSION=2.1.22
      wget -q https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v$${VERSION}/docker-credential-gcr_linux_amd64-$${VERSION}.tar.gz
      tar -xzf docker-credential-gcr_linux_amd64-$${VERSION}.tar.gz
      sudo mv docker-credential-gcr /usr/local/bin/
      rm docker-credential-gcr_linux_amd64-$${VERSION}.tar.gz
    fi
    
    # Ensure docker-credential-gcr is configured
    docker-credential-gcr configure-docker --registries=${var.region}-docker.pkg.dev
    
    echo "Startup script completed" | systemd-cat -t startup-script
  EOF

  allow_stopping_for_update = true

  labels = {
    environment = "production"
    application = "smae"
    managed_by  = "terraform"
  }
}

# Instance Group (required for Load Balancer backend)
resource "google_compute_instance_group" "app_group" {
  name = "${var.resource_prefix}-instance-group"
  zone = var.zone

  instances = [
    google_compute_instance.app_vm.self_link
  ]

  named_port {
    name = "frontend"
    port = 45902
  }

  named_port {
    name = "api"
    port = 45000
  }

  named_port {
    name = "metabase"
    port = 45903
  }
}

# Health Check - Frontend
resource "google_compute_health_check" "frontend_health_check" {
  name                = "${var.resource_prefix}-frontend-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 45902
    request_path = "/"
  }

  log_config {
    enable = var.enable_logging
  }
}

# Health Check - API
resource "google_compute_health_check" "api_health_check" {
  name                = "${var.resource_prefix}-api-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 45000
    request_path = var.health_check_path
  }

  log_config {
    enable = var.enable_logging
  }
}

# Health Check - Metabase
resource "google_compute_health_check" "metabase_health_check" {
  name                = "${var.resource_prefix}-metabase-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 45903
    request_path = "/api/health"
  }

  log_config {
    enable = var.enable_logging
  }
}

# Backend Service - Frontend
resource "google_compute_backend_service" "frontend_backend" {
  name                  = "${var.resource_prefix}-frontend-backend"
  protocol              = "HTTP"
  port_name             = "frontend"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group.app_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.frontend_health_check.id]

  security_policy = var.enable_cloud_armor ? google_compute_security_policy.policy[0].id : null

  log_config {
    enable      = var.enable_logging
    sample_rate = 1.0
  }

  connection_draining_timeout_sec = 300
}

# Backend Service - API
resource "google_compute_backend_service" "api_backend" {
  name                  = "${var.resource_prefix}-api-backend"
  protocol              = "HTTP"
  port_name             = "api"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group.app_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.api_health_check.id]

  security_policy = var.enable_cloud_armor ? google_compute_security_policy.policy[0].id : null

  log_config {
    enable      = var.enable_logging
    sample_rate = 1.0
  }

  connection_draining_timeout_sec = 300
}

# Backend Service - Metabase
resource "google_compute_backend_service" "metabase_backend" {
  name                  = "${var.resource_prefix}-metabase-backend"
  protocol              = "HTTP"
  port_name             = "metabase"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group.app_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.metabase_health_check.id]

  security_policy = var.enable_cloud_armor ? google_compute_security_policy.policy[0].id : null

  log_config {
    enable      = var.enable_logging
    sample_rate = 1.0
  }

  connection_draining_timeout_sec = 300
}

# URL Map with Host Rules
resource "google_compute_url_map" "url_map" {
  name            = "${var.resource_prefix}-url-map"
  default_service = google_compute_backend_service.frontend_backend.id

  host_rule {
    hosts        = [var.domain_name]
    path_matcher = "frontend"
  }

  host_rule {
    hosts        = [var.api_subdomain]
    path_matcher = "api"
  }

  host_rule {
    hosts        = [var.metabase_subdomain]
    path_matcher = "metabase"
  }

  path_matcher {
    name            = "frontend"
    default_service = google_compute_backend_service.frontend_backend.id
  }

  path_matcher {
    name            = "api"
    default_service = google_compute_backend_service.api_backend.id
  }

  path_matcher {
    name            = "metabase"
    default_service = google_compute_backend_service.metabase_backend.id
  }
}

# Managed SSL Certificate (covers all subdomains)
resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  name = "${var.resource_prefix}-ssl-cert-v2"

  managed {
    domains = [
      var.domain_name,
      var.api_subdomain,
      var.metabase_subdomain
    ]
  }
}

# HTTPS Proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "${var.resource_prefix}-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}

# Global Forwarding Rule (HTTPS)
resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name                  = "${var.resource_prefix}-https-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}

# HTTP to HTTPS Redirect (optional but recommended)
resource "google_compute_url_map" "http_redirect" {
  name = "${var.resource_prefix}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "${var.resource_prefix}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name                  = "${var.resource_prefix}-http-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}
