variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "southamerica-east1"
}

variable "zone" {
  description = "GCP zone for VM instance"
  type        = string
  default     = "southamerica-east1-a"
}

variable "domain_name" {
  description = "Base domain name (e.g., smae.e-siri.com)"
  type        = string
}

variable "api_subdomain" {
  description = "API subdomain (e.g., api.smae.e-siri.com)"
  type        = string
  default     = ""
}

variable "metabase_subdomain" {
  description = "Metabase subdomain (e.g., metadb.smae.e-siri.com)"
  type        = string
  default     = ""
}

variable "vm_name" {
  description = "Name of the VM instance"
  type        = string
  default     = "siris"
}

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "siris"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "siris-network"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "siris-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "n2-standard-4"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 100
}

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor WAF protection"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per minute per IP)"
  type        = number
  default     = 100
}

variable "allowed_countries" {
  description = "List of allowed country codes (ISO 3166-1 alpha-2). Empty list allows all countries."
  type        = list(string)
  default     = []
}

variable "enable_logging" {
  description = "Enable Cloud Logging for load balancer and security events"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Path for health check endpoint"
  type        = string
  default     = "/api/ping"
}

variable "enable_iap" {
  description = "Enable Identity-Aware Proxy for SSH access"
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "Additional source IP ranges allowed for SSH (via IAP)"
  type        = list(string)
  default     = []
}

variable "artifact_registry_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "smae"
}

variable "github_repository" {
  description = "GitHub repository in format owner/repo (e.g., ajulabs/smae)"
  type        = string
  default     = "ajulabs/smae"
}

variable "github_org" {
  description = "GitHub organization or user name"
  type        = string
  default     = "ajulabs"
}

variable "secret_prefix" {
  description = "Prefix for Secret Manager secrets"
  type        = string
  default     = "smae"
}
