# Cluster Base Module - Input Variables

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

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6" # Maps to ArgoCD 2.10.x
}

# -----------------------------------------------------------------------------
# ArgoCD Helm Configuration
# -----------------------------------------------------------------------------
variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_helm_timeout" {
  description = "Timeout in seconds for ArgoCD Helm installation"
  type        = number
  default     = 600 # 10 minutes
}

variable "argocd_service_type" {
  description = "ArgoCD server service type"
  type        = string
  default     = "ClusterIP"
}

variable "argocd_dex_enabled" {
  description = "Enable Dex for ArgoCD SSO"
  type        = bool
  default     = false
}

variable "argocd_repo_server_replicas" {
  description = "Number of ArgoCD repo server replicas"
  type        = number
  default     = 1
}
