################################################################################
# Artifact Registry Module - Container Image Repository
################################################################################
# This module creates an Artifact Registry repository for storing GitHub Actions
# runner container images. Includes cleanup policies for cost optimization.
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/5
################################################################################

#------------------------------------------------------------------------------
# Artifact Registry Repository
#------------------------------------------------------------------------------

resource "google_artifact_registry_repository" "runners" {
  project       = var.project_id
  location      = var.region
  repository_id = "github-runners"
  description   = "Docker images for GitHub Actions self-hosted runners on Cloud Run"
  format        = "DOCKER"

  labels = {
    component   = "github-runner"
    managed-by  = "terraform"
    environment = "shared"
  }

  # Cleanup policy: Keep only recent tagged versions
  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  # Cleanup policy: Delete old untagged images after 7 days
  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s" # 7 days in seconds
    }
  }
}

#------------------------------------------------------------------------------
# IAM: Runner Service Account (Read)
#------------------------------------------------------------------------------

# Runner SA: Pull images
resource "google_artifact_registry_repository_iam_member" "runner_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.runners.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.runner_service_account_email}"
}

#------------------------------------------------------------------------------
# IAM: Deployer Service Account (Write)
#------------------------------------------------------------------------------

# Deployer SA: Push images
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.runners.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.deployer_service_account_email}"
}

#------------------------------------------------------------------------------
# IAM: Cloud Build (Write)
#------------------------------------------------------------------------------

# Get project number for Cloud Build SA reference
data "google_project" "current" {
  project_id = var.project_id
}

# Cloud Build default SA: Push images
resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.runners.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}
