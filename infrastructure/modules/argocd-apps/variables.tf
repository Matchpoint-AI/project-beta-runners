# ArgoCD Apps Module - Input Variables
#
# Simplified for GitOps pattern - most runner configuration is in argocd/applications/

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
  description = "Authentication token for the cluster"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
variable "github_token" {
  description = "GitHub PAT for runner registration (requires admin:org and manage_runners:org scopes)"
  type        = string
  sensitive   = true
}

variable "repo_url" {
  description = "Git repository URL for ArgoCD to sync from"
  type        = string
  default     = "https://github.com/Matchpoint-AI/project-beta-runners"
}

variable "target_revision" {
  description = "Git branch/tag/commit for ArgoCD to sync"
  type        = string
  default     = "main"
}

# -----------------------------------------------------------------------------
# Namespace Configuration
# -----------------------------------------------------------------------------
variable "arc_namespace" {
  description = "Kubernetes namespace for ARC controller"
  type        = string
  default     = "arc-systems"
}

variable "arc_runners_namespace" {
  description = "Kubernetes namespace for ARC runner pods"
  type        = string
  default     = "arc-runners"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD is installed"
  type        = string
  default     = "argocd"
}

# -----------------------------------------------------------------------------
# GitHub Runner Configuration
# -----------------------------------------------------------------------------
variable "github_secret_name" {
  description = "Name of the Kubernetes secret containing GitHub token"
  type        = string
  default     = "arc-org-github-secret"
}

# -----------------------------------------------------------------------------
# ArgoCD Application Configuration
# -----------------------------------------------------------------------------
variable "bootstrap_app_name" {
  description = "Name of the bootstrap ArgoCD Application"
  type        = string
  default     = "github-runners-bootstrap"
}

variable "argocd_sync_path" {
  description = "Path in the Git repo for ArgoCD to sync applications from"
  type        = string
  default     = "argocd/applications"
}

variable "argocd_auto_prune" {
  description = "Enable automatic pruning of resources"
  type        = bool
  default     = true
}

variable "argocd_self_heal" {
  description = "Enable automatic self-healing of drifted resources"
  type        = bool
  default     = true
}
