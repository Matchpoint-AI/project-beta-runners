# Cloudspace Module - Input Variables

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "region" {
  description = "Rackspace Spot region"
  type        = string
}

variable "rackspace_org" {
  description = "Rackspace Spot organization ID for spotctl"
  type        = string
  default     = "matchpoint-ai"
}

variable "server_class" {
  description = "Node pool server class. WARNING: Changing forces nodepool destruction (5-10 min outage)!"
  type        = string
  default     = "gp.vs1.xlarge-dfw" # 8 vCPU, 30GB RAM in DFW
}

variable "min_nodes" {
  description = "Minimum number of nodes in the pool"
  type        = number
  default     = 4
}

variable "max_nodes" {
  description = "Maximum number of nodes in the pool"
  type        = number
  default     = 30
}

variable "bid_price" {
  description = "Bid price per node per hour in USD. Target 70-75% of on-demand equivalent for reliability. Safe to change (no nodepool replacement)."
  type        = number
  default     = 0.35 # ~73% of xlarge on-demand equivalent ($0.48)

  validation {
    condition     = var.bid_price > 0 && var.bid_price < 1
    error_message = "Bid price must be between 0 and 1 (exclusive)."
  }
}

# -----------------------------------------------------------------------------
# spotctl Configuration
# -----------------------------------------------------------------------------
variable "spotctl_version" {
  description = "Version of spotctl CLI to install if not present"
  type        = string
  default     = "v0.1.1"
}

# -----------------------------------------------------------------------------
# Polling Configuration
# -----------------------------------------------------------------------------
variable "cloudspace_poll_max_attempts" {
  description = "Maximum polling attempts for cloudspace to become ready (30s intervals)"
  type        = number
  default     = 240 # 2 hours max
}

variable "cloudspace_poll_interval" {
  description = "Seconds between cloudspace status polling attempts"
  type        = number
  default     = 30
}

variable "nodepool_poll_max_attempts" {
  description = "Maximum polling attempts for nodepool to become ready (30s intervals)"
  type        = number
  default     = 60 # 30 minutes max
}

variable "nodepool_poll_interval" {
  description = "Seconds between nodepool status polling attempts"
  type        = number
  default     = 30
}

