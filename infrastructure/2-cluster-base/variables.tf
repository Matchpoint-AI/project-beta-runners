# State 2: Cluster Base - Input Variables

variable "rackspace_spot_token" {
  description = "Rackspace Spot API token"
  type        = string
  sensitive   = true
}

variable "cloudspace_name" {
  description = "Name of the Kubernetes cluster (from State 1)"
  type        = string
}

variable "region" {
  description = "Rackspace Spot region (from State 1)"
  type        = string
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"  # Maps to ArgoCD 2.10.x
}
