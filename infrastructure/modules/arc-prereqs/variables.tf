# ARC Prerequisites Module - Input Variables

# -----------------------------------------------------------------------------
# Kubeconfig Components (from cloudspace module)
# -----------------------------------------------------------------------------
variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  type        = string
  sensitive   = true
}

variable "cluster_token" {
  description = "Authentication token for the Kubernetes cluster"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# ARC Namespace Configuration
# -----------------------------------------------------------------------------
variable "arc_namespace" {
  description = "Namespace for ARC controller (arc-systems)"
  type        = string
  default     = "arc-systems"
}

variable "arc_runners_namespace" {
  description = "Namespace for runner pods (arc-runners)"
  type        = string
  default     = "arc-runners"
}

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
variable "github_token" {
  description = "GitHub PAT for runner registration. Requires admin:org and manage_runners:org scopes."
  type        = string
  sensitive   = true
}

variable "github_secret_name" {
  description = "Name of the Kubernetes secret for GitHub token"
  type        = string
  default     = "arc-org-github-secret"
}
