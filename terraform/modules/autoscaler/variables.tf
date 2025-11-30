################################################################################
# Autoscaler Module - Variables
################################################################################

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Name of the Cloud Run Service"
  type        = string
  default     = "github-runner-autoscaler"
}

variable "image" {
  description = "Container image URL for the autoscaler (from Artifact Registry)"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for the autoscaler"
  type        = string
}

variable "cpu" {
  description = "CPU allocation"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation"
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum number of instances (0 for scale to zero)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "runner_job_name" {
  description = "Name of the Cloud Run Job to execute for runners"
  type        = string
}

variable "runner_labels" {
  description = "Comma-separated labels that this autoscaler manages"
  type        = string
  default     = "self-hosted,cloud-run"
}

variable "webhook_secret_id" {
  description = "Secret Manager secret ID for webhook validation"
  type        = string
}

#------------------------------------------------------------------------------
# GitHub App Credentials (for Polling)
#------------------------------------------------------------------------------

variable "github_app_id_secret_id" {
  description = "Secret Manager secret ID for GitHub App ID"
  type        = string
  default     = ""
}

variable "github_app_installation_id_secret_id" {
  description = "Secret Manager secret ID for GitHub App Installation ID"
  type        = string
  default     = ""
}

variable "github_app_private_key_secret_id" {
  description = "Secret Manager secret ID for GitHub App Private Key"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization to poll for queued jobs"
  type        = string
  default     = "Matchpoint-AI"
}

#------------------------------------------------------------------------------
# Polling Configuration
#------------------------------------------------------------------------------

variable "poll_enabled" {
  description = "Enable background polling for stuck jobs"
  type        = bool
  default     = true
}

variable "poll_interval_seconds" {
  description = "Interval between poll cycles in seconds (Issue #33)"
  type        = number
  default     = 5
}
