# Variables for worker-pool module
# TODO: Implementation tracked in Issue #X

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "worker_pool_name" {
  description = "Name of the worker pool"
  type        = string
  default     = "github-runners"
}

variable "image" {
  description = "Container image for the runner"
  type        = string
}

variable "min_instances" {
  description = "Minimum instances (set to 0 for scale-to-zero)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instances"
  type        = number
  default     = 10
}

variable "cpu" {
  description = "CPU allocation"
  type        = string
  default     = "2"
}

variable "memory" {
  description = "Memory allocation"
  type        = string
  default     = "4Gi"
}

variable "service_account_email" {
  description = "Service account for the worker pool"
  type        = string
}

variable "github_token_secret_id" {
  description = "Secret Manager secret ID for GitHub token"
  type        = string
}
