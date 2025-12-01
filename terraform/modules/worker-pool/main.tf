################################################################################
# Worker Pool Module - Cloud Run Job for GitHub Actions Runners
################################################################################
# Deploys GitHub Actions runners as Cloud Run Jobs. Each job execution handles
# one workflow job, making them ephemeral and scalable.
#
# The autoscaler service creates job executions when workflow_job.queued events
# are received from GitHub webhooks.
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/8
################################################################################

#------------------------------------------------------------------------------
# Cloud Run Job - GitHub Actions Runner
#------------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "runner" {
  name     = var.name
  location = var.region
  project  = var.project_id

  template {
    parallelism = 1
    task_count  = 1

    template {
      # Use Gen2 execution environment for full syscall support
      # Required for pytest-postgresql to run PostgreSQL binaries
      # See: https://cloud.google.com/run/docs/container-contract
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = var.image

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }

        # Environment variables
        env {
          name  = "GITHUB_ORG"
          value = var.github_org
        }

        env {
          name  = "RUNNER_LABELS"
          value = var.runner_labels
        }

        # Secrets from Secret Manager
        env {
          name = "GITHUB_APP_ID"
          value_source {
            secret_key_ref {
              secret  = var.secrets.app_id
              version = "latest"
            }
          }
        }

        env {
          name = "GITHUB_APP_INSTALLATION_ID"
          value_source {
            secret_key_ref {
              secret  = var.secrets.installation_id
              version = "latest"
            }
          }
        }

        env {
          name = "GITHUB_APP_PRIVATE_KEY"
          value_source {
            secret_key_ref {
              secret  = var.secrets.private_key
              version = "latest"
            }
          }
        }

      }

      # Service account
      service_account = var.service_account_email

      # Job timeout (max time for a single workflow job)
      timeout = "${var.job_timeout_seconds}s"

      # Retry configuration
      max_retries = 0 # Don't retry failed jobs - let GitHub handle re-queuing
    }
  }

  labels = {
    component  = "github-runner"
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
# IAM - Allow Autoscaler to Execute Jobs
#------------------------------------------------------------------------------
resource "google_cloud_run_v2_job_iam_member" "autoscaler_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.runner.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.autoscaler_service_account_email}"
}
