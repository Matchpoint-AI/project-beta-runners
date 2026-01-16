# HA Coordinator Module - Variables
#
# Input variables for coordinating High Availability across dual cloudspaces.

variable "primary_cloudspace_name" {
  description = "Name of the primary cloudspace"
  type        = string
}

variable "secondary_cloudspace_name" {
  description = "Name of the secondary cloudspace"
  type        = string
}

variable "primary_cloudspace_ready" {
  description = "Whether the primary cloudspace is in Ready state"
  type        = bool
}

variable "secondary_cloudspace_ready" {
  description = "Whether the secondary cloudspace is in Ready state"
  type        = bool
}

variable "primary_node_count" {
  description = "Current node count in primary cloudspace"
  type        = number
}

variable "secondary_node_count" {
  description = "Current node count in secondary cloudspace"
  type        = number
}

variable "primary_max_nodes" {
  description = "Maximum nodes configured for primary cloudspace"
  type        = number
}

variable "secondary_max_nodes" {
  description = "Maximum nodes configured for secondary cloudspace"
  type        = number
}

variable "ha_enabled" {
  description = "Whether HA mode should be enabled (requires both cloudspaces)"
  type        = bool
  default     = true
}
