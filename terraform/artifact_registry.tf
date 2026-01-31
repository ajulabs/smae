# Artifact Registry Repository
resource "google_artifact_registry_repository" "smae_repo" {
  location      = var.region
  repository_id = "smae"
  description   = "Docker images for SMAE application"
  format        = "DOCKER"

  labels = {
    application = "smae"
    managed_by  = "terraform"
  }
}

resource "google_artifact_registry_repository_iam_member" "vm_reader" {
  location   = google_artifact_registry_repository.smae_repo.location
  repository = google_artifact_registry_repository.smae_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_compute_instance.app_vm.service_account[0].email}"
}

resource "google_artifact_registry_repository_iam_member" "github_writer" {
  location   = google_artifact_registry_repository.smae_repo.location
  repository = google_artifact_registry_repository.smae_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_actions.email}"
}
