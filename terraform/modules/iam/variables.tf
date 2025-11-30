################################################################################
# IAM Module - Variables
################################################################################

variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty."
  }
}

variable "project_number" {
  description = "The GCP project number (required for Cloud Build SA reference)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.project_number))
    error_message = "Project number must be a numeric string."
  }
}
