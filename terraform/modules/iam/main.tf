################################################################################
# IAM Module - Service Accounts and Role Bindings
################################################################################
# This module creates service accounts and IAM bindings for the GitHub Actions
# runner infrastructure. Follows principle of least privilege.
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/3
################################################################################

#------------------------------------------------------------------------------
# Service Accounts
#------------------------------------------------------------------------------

# Service Account for the runner worker pool
resource "google_service_account" "runner" {
  project      = var.project_id
  account_id   = "github-runner"
  display_name = "GitHub Actions Runner"
  description  = "Service account for Cloud Run GitHub Actions runner worker pool"
}

# Service Account for the autoscaler function
resource "google_service_account" "autoscaler" {
  project      = var.project_id
  account_id   = "github-runner-autoscaler"
  display_name = "GitHub Runner Autoscaler"
  description  = "Service account for the autoscaler Cloud Run function that scales the worker pool"
}

# Service Account for Cloud Build deployments
resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "github-runner-deployer"
  display_name = "GitHub Runner Deployer"
  description  = "Service account for deploying runner infrastructure via Cloud Build"
}

#------------------------------------------------------------------------------
# Runner Service Account Permissions
#------------------------------------------------------------------------------

# Runner SA: Access secrets (GitHub App credentials)
resource "google_project_iam_member" "runner_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

# Runner SA: Write logs
resource "google_project_iam_member" "runner_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

# Runner SA: Report metrics
resource "google_project_iam_member" "runner_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

#------------------------------------------------------------------------------
# Autoscaler Service Account Permissions
#------------------------------------------------------------------------------

# Autoscaler SA: Manage Cloud Run (to scale worker pool)
resource "google_project_iam_member" "autoscaler_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.autoscaler.email}"
}

# Autoscaler SA: Access secrets (webhook secret, GitHub App credentials)
resource "google_project_iam_member" "autoscaler_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.autoscaler.email}"
}

# Autoscaler SA: Write logs
resource "google_project_iam_member" "autoscaler_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.autoscaler.email}"
}

# Autoscaler SA: Act as runner SA (required to update worker pool)
resource "google_service_account_iam_member" "autoscaler_acts_as_runner" {
  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.autoscaler.email}"
}

#------------------------------------------------------------------------------
# Deployer Service Account Permissions
#------------------------------------------------------------------------------

locals {
  deployer_roles = [
    "roles/run.admin",                       # Deploy Cloud Run services/worker pools
    "roles/artifactregistry.admin",          # Push/manage container images
    "roles/secretmanager.admin",             # Manage secrets
    "roles/iam.serviceAccountAdmin",         # Manage service accounts
    "roles/iam.serviceAccountUser",          # Act as service accounts
    "roles/cloudbuild.builds.editor",        # Manage builds
    "roles/storage.admin",                   # Terraform state bucket
    "roles/resourcemanager.projectIamAdmin", # Manage IAM bindings
  ]
}

resource "google_project_iam_member" "deployer_roles" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

#------------------------------------------------------------------------------
# Cloud Build Integration
#------------------------------------------------------------------------------

# Allow Cloud Build default SA to impersonate deployer SA
resource "google_service_account_iam_member" "cloudbuild_impersonate_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

# Allow Cloud Build default SA to act as deployer SA
resource "google_service_account_iam_member" "cloudbuild_use_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}
