# ArgoCD Apps Module - Input Variables

variable "runner_label" {
  description = "GitHub Actions runner label"
  type        = string
  default     = "project-beta-runners"
}

variable "min_runners" {
  description = "Minimum number of warm runners"
  type        = number
  default     = 5
}

variable "max_runners" {
  description = "Maximum number of runners under load"
  type        = number
  default     = 25
}

variable "arc_version" {
  description = "ARC Helm chart version"
  type        = string
  default     = "0.9.3"
}

variable "github_org" {
  description = "GitHub organization for runner registration"
  type        = string
  default     = "Matchpoint-AI"
}

variable "github_app_id" {
  description = "GitHub App ID for runner registration"
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App private key (base64 encoded)"
  type        = string
  sensitive   = true
}
