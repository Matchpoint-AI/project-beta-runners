################################################################################
# Worker Pool Module - Variables
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
  description = "Name of the Cloud Run Job"
  type        = string
  default     = "github-runner"
}

variable "image" {
  description = "Container image URL for the runner (from Artifact Registry)"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for the runner job"
  type        = string
}

variable "autoscaler_service_account_email" {
  description = "Service account email for the autoscaler (needs invoker role)"
  type        = string
}

variable "cpu" {
  description = "CPU allocation per runner instance"
  type        = string
  default     = "2"
}

variable "memory" {
  description = "Memory allocation per runner instance"
  type        = string
  default     = "4Gi"
}

variable "job_timeout_seconds" {
  description = "Maximum time for a single workflow job (in seconds)"
  type        = number
  default     = 3600 # 1 hour
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "Matchpoint-AI"
}

variable "runner_labels" {
  description = "Comma-separated labels for the runner"
  type        = string
  default     = "self-hosted,cloud-run,linux,x64"
}

variable "secrets" {
  description = "Secret Manager secret IDs for GitHub App credentials"
  type = object({
    app_id          = string
    installation_id = string
    private_key     = string
  })
}

#------------------------------------------------------------------------------
# Docker Host Configuration (for testcontainers support)
#------------------------------------------------------------------------------

variable "docker_host_url" {
  description = "URL for remote Docker daemon (e.g., tcp://10.0.0.5:2375). Required for testcontainers since Cloud Run cannot run privileged containers."
  type        = string
  default     = ""
}
