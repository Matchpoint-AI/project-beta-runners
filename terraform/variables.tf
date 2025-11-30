variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "Matchpoint-AI"
}

variable "github_repositories" {
  description = "List of GitHub repositories to serve"
  type        = list(string)
  default = [
    "project-beta",
    "project-beta-api",
    "project-beta-frontend"
  ]
}

variable "runner_labels" {
  description = "Labels to apply to the runners"
  type        = list(string)
  default     = ["self-hosted", "cloud-run", "linux", "x64"]
}

variable "min_instances" {
  description = "Minimum number of runner instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of runner instances"
  type        = number
  default     = 10
}

variable "machine_cpu" {
  description = "CPU allocation for each runner (e.g., '2' for 2 vCPUs)"
  type        = string
  default     = "2"
}

variable "machine_memory" {
  description = "Memory allocation for each runner (e.g., '4Gi')"
  type        = string
  default     = "4Gi"
}
