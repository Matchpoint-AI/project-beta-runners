################################################################################
# Artifact Registry Module - Variables
################################################################################

variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty."
  }
}

variable "region" {
  description = "The GCP region for the Artifact Registry repository"
  type        = string
  default     = "us-central1"
}

variable "runner_service_account_email" {
  description = "Email of the runner service account (needs read access to pull images)"
  type        = string

  validation {
    condition     = can(regex("@.*\\.iam\\.gserviceaccount\\.com$", var.runner_service_account_email))
    error_message = "Must be a valid service account email."
  }
}

variable "deployer_service_account_email" {
  description = "Email of the deployer service account (needs write access to push images)"
  type        = string

  validation {
    condition     = can(regex("@.*\\.iam\\.gserviceaccount\\.com$", var.deployer_service_account_email))
    error_message = "Must be a valid service account email."
  }
}
