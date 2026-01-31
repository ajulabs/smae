# Secret Manager Secrets
# All secrets use "smae-" prefix for easy identification

locals {
  secrets = toset([
    "smae-postgres-password",
    "smae-mb-db-pass",
    "smae-minio-root-user",
    "smae-minio-root-password",
    "smae-s3-access-key",
    "smae-s3-secret-key",
    "smae-session-jwt-secret",
    "smae-prisma-encryption-key",
    "smae-sof-api-token",
    "smae-sei-api-token",
    "smae-azure-key"
  ])
}

resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets

  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    application = "smae"
    managed_by  = "terraform"
  }
}

resource "google_secret_manager_secret_iam_member" "vm_access" {
  for_each = google_secret_manager_secret.secrets

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_compute_instance.app_vm.service_account[0].email}"
}
