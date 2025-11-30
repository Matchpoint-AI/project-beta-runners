################################################################################
# APIs Module - Enable Required GCP APIs
################################################################################
# This module enables all Google Cloud APIs required for the GitHub Actions
# runner infrastructure on Cloud Run.
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/2
################################################################################

locals {
  required_apis = [
    "run.googleapis.com",                  # Cloud Run (worker pools and services)
    "cloudbuild.googleapis.com",           # Cloud Build (CI/CD)
    "artifactregistry.googleapis.com",     # Artifact Registry (container images)
    "secretmanager.googleapis.com",        # Secret Manager (GitHub credentials)
    "iam.googleapis.com",                  # IAM (service accounts and roles)
    "cloudresourcemanager.googleapis.com", # Resource Manager (project access)
    "compute.googleapis.com",              # Compute Engine (networking)
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  # Don't disable APIs when destroying - other resources may depend on them
  disable_on_destroy = false

  # Don't disable dependent services - safer for shared projects
  disable_dependent_services = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}
