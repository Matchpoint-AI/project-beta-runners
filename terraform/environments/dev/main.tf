# Development Environment Configuration
# TODO: Implementation tracked in Issue #X

terraform {
  backend "gcs" {
    bucket = "project-beta-terraform-state"
    prefix = "runners/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

# TODO: Instantiate root modules here
