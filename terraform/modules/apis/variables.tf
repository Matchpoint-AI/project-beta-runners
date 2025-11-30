################################################################################
# APIs Module - Variables
################################################################################

variable "project_id" {
  description = "The GCP project ID where APIs will be enabled"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty."
  }
}
