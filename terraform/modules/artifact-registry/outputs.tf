################################################################################
# Artifact Registry Module - Outputs
################################################################################

output "repository_id" {
  description = "The repository ID"
  value       = google_artifact_registry_repository.runners.repository_id
}

output "repository_name" {
  description = "The full repository name (for IAM references)"
  value       = google_artifact_registry_repository.runners.name
}

output "repository_url" {
  description = "The repository URL for docker push/pull operations"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.runners.repository_id}"
}

output "runner_image_base" {
  description = "Base path for runner images (append :tag for full reference)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.runners.repository_id}/github-runner"
}

output "autoscaler_image_base" {
  description = "Base path for autoscaler images (append :tag for full reference)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.runners.repository_id}/autoscaler"
}
