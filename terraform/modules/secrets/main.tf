################################################################################
# Secrets Module - Secret Manager Configuration
################################################################################
# This module creates Secret Manager secrets for GitHub App credentials and
# webhook verification. Secrets are created as shells - actual values must be
# added manually after GitHub App creation (except webhook secret which is
# auto-generated).
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/4
################################################################################

#------------------------------------------------------------------------------
# GitHub App Secrets
#------------------------------------------------------------------------------

# GitHub App ID - numeric identifier for the App
resource "google_secret_manager_secret" "github_app_id" {
  project   = var.project_id
  secret_id = "github-app-id"

  labels = {
    component = "github-runner"
    type      = "credential"
  }

  replication {
    auto {}
  }
}

# GitHub App Installation ID - numeric identifier for the org installation
resource "google_secret_manager_secret" "github_app_installation_id" {
  project   = var.project_id
  secret_id = "github-app-installation-id"

  labels = {
    component = "github-runner"
    type      = "credential"
  }

  replication {
    auto {}
  }
}

# GitHub App Private Key - PEM-encoded RSA private key
resource "google_secret_manager_secret" "github_app_private_key" {
  project   = var.project_id
  secret_id = "github-app-private-key"

  labels = {
    component = "github-runner"
    type      = "credential"
    sensitive = "true"
  }

  replication {
    auto {}
  }
}

#------------------------------------------------------------------------------
# Webhook Secret
#------------------------------------------------------------------------------

# Webhook secret for verifying GitHub webhook signatures
resource "google_secret_manager_secret" "webhook_secret" {
  project   = var.project_id
  secret_id = "github-webhook-secret"

  labels = {
    component = "github-runner"
    type      = "credential"
  }

  replication {
    auto {}
  }
}

# Generate a random webhook secret value
resource "random_password" "webhook_secret" {
  length  = 32
  special = false
}

# Store the generated webhook secret
resource "google_secret_manager_secret_version" "webhook_secret" {
  secret      = google_secret_manager_secret.webhook_secret.id
  secret_data = random_password.webhook_secret.result
}

#------------------------------------------------------------------------------
# IAM: Runner Service Account Access
#------------------------------------------------------------------------------

# Runner SA: Access App ID
resource "google_secret_manager_secret_iam_member" "runner_app_id" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_app_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runner_service_account_email}"
}

# Runner SA: Access Installation ID
resource "google_secret_manager_secret_iam_member" "runner_installation_id" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_app_installation_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runner_service_account_email}"
}

# Runner SA: Access Private Key
resource "google_secret_manager_secret_iam_member" "runner_private_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_app_private_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runner_service_account_email}"
}

#------------------------------------------------------------------------------
# IAM: Autoscaler Service Account Access
#------------------------------------------------------------------------------

# Autoscaler SA: Access App ID (for generating runner tokens)
resource "google_secret_manager_secret_iam_member" "autoscaler_app_id" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_app_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.autoscaler_service_account_email}"
}

# Autoscaler SA: Access Installation ID
resource "google_secret_manager_secret_iam_member" "autoscaler_installation_id" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_app_installation_id.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.autoscaler_service_account_email}"
}

# Autoscaler SA: Access Private Key
resource "google_secret_manager_secret_iam_member" "autoscaler_private_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_app_private_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.autoscaler_service_account_email}"
}

# Autoscaler SA: Access Webhook Secret (for signature verification)
resource "google_secret_manager_secret_iam_member" "autoscaler_webhook" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.webhook_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.autoscaler_service_account_email}"
}
