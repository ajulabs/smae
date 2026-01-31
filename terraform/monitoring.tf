# Log Sink for Load Balancer logs
resource "google_logging_project_sink" "lb_logs" {
  count = var.enable_logging ? 1 : 0

  name        = "${var.resource_prefix}-lb-logs-sink"
  description = "Log sink for Load Balancer access logs"

  destination = "storage.googleapis.com/projects/_/buckets/${var.resource_prefix}-lb-logs"

  filter = <<-EOT
    resource.type="http_load_balancer"
    resource.labels.backend_service_name="${var.resource_prefix}-backend-service"
  EOT

  unique_writer_identity = true
}

# Log Sink for Cloud Armor security events
resource "google_logging_project_sink" "security_logs" {
  count = var.enable_logging && var.enable_cloud_armor ? 1 : 0

  name        = "${var.resource_prefix}-security-logs-sink"
  description = "Log sink for Cloud Armor security events"

  destination = "storage.googleapis.com/projects/_/buckets/${var.resource_prefix}-security-logs"

  filter = <<-EOT
    resource.type="http_load_balancer"
    jsonPayload.enforcedSecurityPolicy.name="${var.resource_prefix}-security-policy"
  EOT

  unique_writer_identity = true
}

# Log Sink for VM system logs
resource "google_logging_project_sink" "vm_logs" {
  count = var.enable_logging ? 1 : 0

  name        = "${var.resource_prefix}-vm-logs-sink"
  description = "Log sink for VM system logs"

  destination = "storage.googleapis.com/projects/_/buckets/${var.resource_prefix}-vm-logs"

  filter = <<-EOT
    resource.type="gce_instance"
    resource.labels.instance_id="${google_compute_instance.app_vm.instance_id}"
  EOT

  unique_writer_identity = true
}

# Log Sink for firewall logs
resource "google_logging_project_sink" "firewall_logs" {
  count = var.enable_logging ? 1 : 0

  name        = "${var.resource_prefix}-firewall-logs-sink"
  description = "Log sink for VPC firewall logs"

  destination = "storage.googleapis.com/projects/_/buckets/${var.resource_prefix}-firewall-logs"

  filter = <<-EOT
    resource.type="gce_subnetwork"
    logName:"logs/compute.googleapis.com%2Ffirewall"
    resource.labels.subnetwork_name="${var.subnet_name}"
  EOT

  unique_writer_identity = true
}

# Metric for Cloud Armor blocked requests
resource "google_monitoring_alert_policy" "armor_blocks" {
  count = var.enable_logging && var.enable_cloud_armor ? 1 : 0

  display_name = "${var.resource_prefix}-armor-blocks-alert"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Armor blocking high volume of requests"

    condition_threshold {
      filter          = "resource.type=\"http_load_balancer\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND metric.labels.response_code_class=\"400\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 100

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  documentation {
    content   = "Cloud Armor is blocking a high volume of requests. This may indicate an ongoing attack or misconfigured security rules."
    mime_type = "text/markdown"
  }

  notification_channels = []

  alert_strategy {
    auto_close = "1800s"
  }
}

# Metric for VM health check failures
resource "google_monitoring_alert_policy" "health_check_failures" {
  count = var.enable_logging ? 1 : 0

  display_name = "${var.resource_prefix}-health-check-failures-alert"
  combiner     = "OR"

  conditions {
    display_name = "Backend service health check failures"

    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/uptime\" AND resource.labels.instance_id=\"${google_compute_instance.app_vm.instance_id}\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  documentation {
    content   = "The application VM is failing health checks. Check the application logs and VM status."
    mime_type = "text/markdown"
  }

  notification_channels = []

  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard for security monitoring
resource "google_monitoring_dashboard" "security_dashboard" {
  count = var.enable_logging ? 1 : 0

  dashboard_json = jsonencode({
    displayName = "${var.resource_prefix} Security Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Load Balancer Request Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"http_load_balancer\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Cloud Armor Actions"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"http_load_balancer\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND metric.labels.response_code_class=\"400\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Backend Service Latency"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"http_load_balancer\" AND metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "VM CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" AND resource.labels.instance_id=\"${google_compute_instance.app_vm.instance_id}\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}
