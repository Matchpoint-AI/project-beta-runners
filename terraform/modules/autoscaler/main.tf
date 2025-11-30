################################################################################
# Autoscaler Module - Cloud Run Service for GitHub Webhook Processing
################################################################################
# Receives GitHub workflow_job webhook events and triggers Cloud Run Job
# executions when jobs are queued.
#
# Architecture:
#   GitHub webhook -> Cloud Run Service -> Validates signature -> Executes Job
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/11
################################################################################

#------------------------------------------------------------------------------
# Cloud Run Service - Webhook Receiver
#------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "autoscaler" {
  name     = var.name
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      # Runner job configuration
      env {
        name  = "RUNNER_JOB_NAME"
        value = var.runner_job_name
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "GCP_REGION"
        value = var.region
      }

      env {
        name  = "RUNNER_LABELS"
        value = var.runner_labels
      }

      # Webhook secret from Secret Manager
      env {
        name = "GITHUB_WEBHOOK_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.webhook_secret_id
            version = "latest"
          }
        }
      }

      # GitHub App credentials for polling (from Secret Manager)
      dynamic "env" {
        for_each = var.github_app_id_secret_id != "" ? [1] : []
        content {
          name = "GITHUB_APP_ID"
          value_source {
            secret_key_ref {
              secret  = var.github_app_id_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.github_app_installation_id_secret_id != "" ? [1] : []
        content {
          name = "GITHUB_APP_INSTALLATION_ID"
          value_source {
            secret_key_ref {
              secret  = var.github_app_installation_id_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.github_app_private_key_secret_id != "" ? [1] : []
        content {
          name = "GITHUB_APP_PRIVATE_KEY"
          value_source {
            secret_key_ref {
              secret  = var.github_app_private_key_secret_id
              version = "latest"
            }
          }
        }
      }

      # Polling configuration
      env {
        name  = "GITHUB_ORG"
        value = var.github_org
      }

      env {
        name  = "POLL_ENABLED"
        value = var.poll_enabled ? "true" : "false"
      }

      env {
        name  = "POLL_INTERVAL_SECONDS"
        value = tostring(var.poll_interval_seconds)
      }

      ports {
        container_port = 8080
      }

      # Startup probe
      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 10
      }

      # Liveness probe
      liveness_probe {
        http_get {
          path = "/health"
        }
        timeout_seconds   = 1
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    # Service account
    service_account = var.service_account_email

    # Scaling configuration
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Request timeout
    timeout = "60s"
  }

  # Traffic configuration
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = {
    component  = "github-runner-autoscaler"
    managed-by = "terraform"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to launch_stage as it may be set by GCP
      launch_stage,
    ]
  }
}

#------------------------------------------------------------------------------
# IAM - Allow Unauthenticated Invocations (GitHub Webhooks)
#------------------------------------------------------------------------------
# GitHub webhooks cannot authenticate, so we allow unauthenticated access.
# Security is provided by HMAC signature verification using the webhook secret.
resource "google_cloud_run_v2_service_iam_member" "allow_unauthenticated" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.autoscaler.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
