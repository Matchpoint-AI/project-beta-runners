# State 3: ArgoCD Apps - Input Variables

variable "rackspace_spot_token" {
  description = "Rackspace Spot API token"
  type        = string
  sensitive   = true
}

variable "kubeconfig_raw" {
  description = "Raw kubeconfig YAML (from State 2)"
  type        = string
  sensitive   = true
}

variable "argocd_namespace" {
  description = "Namespace where ArgoCD is installed (from State 2)"
  type        = string
  default     = "argocd"
}

variable "cloudspace_name" {
  description = "Name of the Kubernetes cluster (from State 1)"
  type        = string
}

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

variable "github_app_id" {
  description = "GitHub App ID for runner registration"
  type        = string
  sensitive   = true
  default     = ""  # Passed via environment
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  sensitive   = true
  default     = ""  # Passed via environment
}

variable "github_app_private_key" {
  description = "GitHub App private key (base64 encoded)"
  type        = string
  sensitive   = true
  default     = ""  # Passed via environment
}

variable "github_org" {
  description = "GitHub organization for runner registration"
  type        = string
  default     = "Matchpoint-AI"
}
