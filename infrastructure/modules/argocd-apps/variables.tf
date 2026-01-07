# ArgoCD Apps Module - Input Variables
#
# Simplified for GitOps pattern - most runner configuration is in argocd/applications/

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
