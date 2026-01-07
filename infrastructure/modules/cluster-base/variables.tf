# Cluster Base Module - Input Variables

variable "cloudspace_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"  # Maps to ArgoCD 2.10.x
}
