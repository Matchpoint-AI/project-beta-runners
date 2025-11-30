################################################################################
# Docker Host Module - Variables
################################################################################

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "name" {
  description = "Name of the Docker host VM"
  type        = string
  default     = "docker-host"
}

variable "zone" {
  description = "GCP Zone for the VM"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Machine type for the Docker host"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 100
}

variable "network" {
  description = "VPC network name or self_link"
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Subnetwork name or self_link (optional)"
  type        = string
  default     = null
}

variable "service_account_email" {
  description = "Service account email for the VM"
  type        = string
}

variable "preemptible" {
  description = "Use preemptible VM for cost savings (less stable)"
  type        = bool
  default     = false
}

variable "allowed_source_ranges" {
  description = "CIDR ranges allowed to access Docker daemon"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_health_check" {
  description = "Enable GCP health check for monitoring"
  type        = bool
  default     = false
}
