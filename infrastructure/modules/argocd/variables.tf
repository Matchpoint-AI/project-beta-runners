variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "bootstrap_app_name" {
  description = "Name of the bootstrap ArgoCD Application"
  type        = string
  default     = "gke-runners-bootstrap"
}

variable "repo_url" {
  description = "Git repository URL for the bootstrap Application source"
  type        = string
}

variable "target_revision" {
  description = "Git branch/tag/commit for the bootstrap Application"
  type        = string
  default     = "main"
}

variable "applications_path" {
  description = "Path in the repo to the ArgoCD applications directory"
  type        = string
  default     = "argocd/applications-gke"
}

variable "cluster_endpoint" {
  description = "GKE cluster endpoint (used for Kubernetes provider config)"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster"
  type        = string
  sensitive   = true
}
