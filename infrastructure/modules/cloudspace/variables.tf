# Cloudspace Module - Input Variables

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "region" {
  description = "Rackspace Spot region"
  type        = string
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

variable "bid_price" {
  description = "Bid price per node per hour in USD (must be > 0 and < 1)"
  type        = number
  default     = 0.28

  validation {
    condition     = var.bid_price > 0 && var.bid_price < 1
    error_message = "Bid price must be between 0 and 1 (exclusive)."
  }
}
