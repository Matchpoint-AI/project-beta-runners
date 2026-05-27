variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "zone" {
  description = "GCP zone for the zonal cluster (e.g. us-central1-a)"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the Spot node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB for each node"
  type        = number
  default     = 50
}

variable "min_node_count" {
  description = "Minimum number of nodes in the Spot pool (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "max_node_count" {
  description = "Maximum number of nodes in the Spot pool"
  type        = number
  default     = 25
}

variable "wif_pool_name" {
  description = "Full resource name of the Workload Identity Federation pool"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in org/repo format for WIF binding"
  type        = string
}


variable "wif_pool_id" {
  description = "Short ID of the existing Workload Identity Pool (e.g. github-actions-pool). The project number is looked up via data.google_project."
  type        = string
}
