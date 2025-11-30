################################################################################
# Development Environment - GitHub Runners Infrastructure
################################################################################
# This environment deploys all GitHub runner infrastructure for development.
#
# Prerequisites:
# 1. Run scripts/bootstrap-state.sh to create state bucket
# 2. Create GitHub App and store credentials (Issue #13)
#
# Issues: #2, #3, #4, #5, #6, #9
################################################################################

terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "project-beta-runners-tf-state"
    prefix = "env/dev"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

#------------------------------------------------------------------------------
# Providers
#------------------------------------------------------------------------------

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------

data "google_project" "current" {
  project_id = var.project_id
}

#------------------------------------------------------------------------------
# Phase 1: Bootstrap Infrastructure
#------------------------------------------------------------------------------

# Issue #2: Enable required GCP APIs
module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

# Issue #3: IAM - Service Accounts and Role Bindings
module "iam" {
  source         = "../../modules/iam"
  project_id     = var.project_id
  project_number = data.google_project.current.number

  depends_on = [module.apis]
}

# Issue #4: Secret Manager - GitHub App credentials
module "secrets" {
  source                           = "../../modules/secrets"
  project_id                       = var.project_id
  runner_service_account_email     = module.iam.runner_service_account_email
  autoscaler_service_account_email = module.iam.autoscaler_service_account_email

  depends_on = [module.iam]
}

# Issue #5: Artifact Registry - Container image repository
module "artifact_registry" {
  source                         = "../../modules/artifact-registry"
  project_id                     = var.project_id
  region                         = var.region
  runner_service_account_email   = module.iam.runner_service_account_email
  deployer_service_account_email = module.iam.deployer_service_account_email

  depends_on = [module.iam]
}

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID for the development environment"
  type        = string
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
  default     = "us-central1"
}

#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

# Service Account Emails
output "runner_service_account_email" {
  description = "Email of the runner service account"
  value       = module.iam.runner_service_account_email
}

output "autoscaler_service_account_email" {
  description = "Email of the autoscaler service account"
  value       = module.iam.autoscaler_service_account_email
}

output "deployer_service_account_email" {
  description = "Email of the deployer service account"
  value       = module.iam.deployer_service_account_email
}

# Artifact Registry
output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = module.artifact_registry.repository_url
}

output "runner_image_base" {
  description = "Base path for runner container images"
  value       = module.artifact_registry.runner_image_base
}

# Secrets
output "github_app_id_secret" {
  description = "Secret Manager secret ID for GitHub App ID"
  value       = module.secrets.github_app_id_secret_id
}

output "webhook_secret_id" {
  description = "Secret Manager secret ID for webhook secret"
  value       = module.secrets.webhook_secret_id
}
