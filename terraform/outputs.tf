output "load_balancer_ip" {
  description = "External IP address of the Load Balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "vm_name" {
  description = "Name of the VM instance"
  value       = google_compute_instance.app_vm.name
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM"
  value       = google_compute_instance.app_vm.network_interface[0].network_ip
}

output "vm_zone" {
  description = "Zone where the VM is located"
  value       = google_compute_instance.app_vm.zone
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "ssl_certificate_name" {
  description = "Name of the managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.ssl_cert.name
}

output "ssl_certificate_domains" {
  description = "Domains covered by the SSL certificate"
  value       = google_compute_managed_ssl_certificate.ssl_cert.managed[0].domains
}

output "cloud_armor_policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = var.enable_cloud_armor ? google_compute_security_policy.policy[0].name : "disabled"
}

output "backend_services" {
  description = "Names of the backend services"
  value = {
    frontend = google_compute_backend_service.frontend_backend.name
    api      = google_compute_backend_service.api_backend.name
    metabase = google_compute_backend_service.metabase_backend.name
  }
}

output "ssh_command" {
  description = "Command to SSH into the VM via IAP"
  value       = "gcloud compute ssh ${var.vm_name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "dns_records_needed" {
  description = "DNS A records needed (all point to the same Load Balancer IP)"
  value = {
    frontend = {
      host  = var.domain_name
      type  = "A"
      value = google_compute_global_address.lb_ip.address
    }
    api = {
      host  = var.api_subdomain
      type  = "A"
      value = google_compute_global_address.lb_ip.address
    }
    metabase = {
      host  = var.metabase_subdomain
      type  = "A"
      value = google_compute_global_address.lb_ip.address
    }
  }
}

output "application_urls" {
  description = "URLs to access the application (after DNS and SSL cert are ready)"
  value = {
    frontend = "https://${var.domain_name}"
    api      = "https://${var.api_subdomain}"
    metabase = "https://${var.metabase_subdomain}"
  }
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_name}"
}

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "github_actions_service_account" {
  description = "Service account email for GitHub Actions"
  value       = google_service_account.github_actions.email
}

output "secret_manager_secrets" {
  description = "List of Secret Manager secrets created"
  value       = [for s in google_secret_manager_secret.secrets : s.secret_id]
}
