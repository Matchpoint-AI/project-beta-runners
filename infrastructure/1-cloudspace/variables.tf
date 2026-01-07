# State 1: Cloudspace - Input Variables

variable "rackspace_spot_token" {
  description = "Rackspace Spot API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "mp-runners-v3"
}

variable "region" {
  description = "Rackspace Spot region"
  type        = string
  default     = "us-central-dfw-1"
}

variable "server_class" {
  description = "Node pool server class (e.g., gp.vs1.large = 4 vCPU, 15GB RAM)"
  type        = string
  default     = "gp.vs1.large"
}

variable "min_nodes" {
  description = "Minimum number of nodes in the pool"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of nodes in the pool"
  type        = number
  default     = 15
}
