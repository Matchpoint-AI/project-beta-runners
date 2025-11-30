################################################################################
# Secrets Module - Variables
################################################################################

variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty."
  }
}

variable "runner_service_account_email" {
  description = "Email of the runner service account (needs access to GitHub App secrets)"
  type        = string

  validation {
    condition     = can(regex("@.*\\.iam\\.gserviceaccount\\.com$", var.runner_service_account_email))
    error_message = "Must be a valid service account email."
  }
}

variable "autoscaler_service_account_email" {
  description = "Email of the autoscaler service account (needs access to all secrets)"
  type        = string

  validation {
    condition     = can(regex("@.*\\.iam\\.gserviceaccount\\.com$", var.autoscaler_service_account_email))
    error_message = "Must be a valid service account email."
  }
}
