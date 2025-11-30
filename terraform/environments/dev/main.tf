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
# Docker Host VM (for testcontainers support)
#------------------------------------------------------------------------------

# Issue #31: Docker-in-Docker support for Cloud Run runners
# Cloud Run cannot run privileged containers, so we use a remote Docker daemon
module "docker_host" {
  source     = "../../modules/docker-host"
  project_id = var.project_id

  name         = "github-runner-docker-host"
  zone         = "${var.region}-a"
  machine_type = var.docker_host_machine_type

  # Use runner service account for the Docker host
  service_account_email = module.iam.runner_service_account_email

  # Allow access from Cloud Run's VPC connector range
  allowed_source_ranges = ["10.0.0.0/8"]

  # Cost optimization for dev (can be disabled for prod)
  preemptible = var.docker_host_preemptible

  depends_on = [module.iam]
}

#------------------------------------------------------------------------------
# Phase 2: Worker Pool (Cloud Run Job for Runners)
#------------------------------------------------------------------------------

# Issue #8: Worker Pool - Cloud Run Job for GitHub Actions runners
module "worker_pool" {
  source     = "../../modules/worker-pool"
  project_id = var.project_id
  region     = var.region

  name  = var.runner_job_name
  image = var.runner_image

  # Service accounts
  service_account_email            = module.iam.runner_service_account_email
  autoscaler_service_account_email = module.iam.autoscaler_service_account_email

  # Runner configuration
  github_org    = var.github_org
  runner_labels = var.runner_labels

  # Resource allocation
  cpu    = var.runner_cpu
  memory = var.runner_memory

  # Secrets
  secrets = {
    app_id          = module.secrets.github_app_id_secret_id
    installation_id = module.secrets.github_app_installation_id_secret_id
    private_key     = module.secrets.github_app_private_key_secret_id
  }

  # Docker host for testcontainers (Issue #31)
  docker_host_url = module.docker_host.docker_host_url

  depends_on = [module.secrets, module.artifact_registry, module.docker_host]
}

#------------------------------------------------------------------------------
# Phase 3: Autoscaler (Cloud Run Service for Webhooks)
#------------------------------------------------------------------------------

# Issue #11: Autoscaler - Cloud Run Service for webhook processing
# Issue #25: Added polling fallback for stuck jobs
module "autoscaler" {
  source     = "../../modules/autoscaler"
  project_id = var.project_id
  region     = var.region

  name  = var.autoscaler_name
  image = var.autoscaler_image

  # Service account
  service_account_email = module.iam.autoscaler_service_account_email

  # Runner job to execute
  runner_job_name = module.worker_pool.job_name
  runner_labels   = var.runner_labels

  # Webhook secret
  webhook_secret_id = module.secrets.webhook_secret_id

  # GitHub App credentials for polling (Issue #25)
  github_app_id_secret_id              = module.secrets.github_app_id_secret_id
  github_app_installation_id_secret_id = module.secrets.github_app_installation_id_secret_id
  github_app_private_key_secret_id     = module.secrets.github_app_private_key_secret_id
  github_org                           = var.github_org

  # Polling configuration
  poll_enabled          = var.poll_enabled
  poll_interval_seconds = var.poll_interval_seconds

  depends_on = [module.worker_pool]
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

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "Matchpoint-AI"
}

#------------------------------------------------------------------------------
# Worker Pool Variables
#------------------------------------------------------------------------------

variable "runner_job_name" {
  description = "Name of the Cloud Run Job for runners"
  type        = string
  default     = "github-runner"
}

variable "runner_image" {
  description = "Container image URL for the runner"
  type        = string
}

variable "runner_labels" {
  description = "Comma-separated labels for the runners"
  type        = string
  default     = "self-hosted,cloud-run,linux,x64"
}

variable "runner_cpu" {
  description = "CPU allocation per runner"
  type        = string
  default     = "2"
}

variable "runner_memory" {
  description = "Memory allocation per runner"
  type        = string
  default     = "4Gi"
}

#------------------------------------------------------------------------------
# Autoscaler Variables
#------------------------------------------------------------------------------

variable "autoscaler_name" {
  description = "Name of the Cloud Run Service for autoscaler"
  type        = string
  default     = "github-runner-autoscaler"
}

variable "autoscaler_image" {
  description = "Container image URL for the autoscaler"
  type        = string
}

#------------------------------------------------------------------------------
# Polling Configuration (Issue #25)
#------------------------------------------------------------------------------

variable "poll_enabled" {
  description = "Enable background polling for stuck jobs"
  type        = bool
  default     = true
}

variable "poll_interval_seconds" {
  description = "Interval between poll cycles in seconds"
  type        = number
  default     = 30
}

#------------------------------------------------------------------------------
# Docker Host Variables (Issue #31)
#------------------------------------------------------------------------------

variable "docker_host_machine_type" {
  description = "Machine type for the Docker host VM"
  type        = string
  default     = "e2-standard-4"
}

variable "docker_host_preemptible" {
  description = "Use preemptible VM for Docker host (cost savings, less stable)"
  type        = bool
  default     = true
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

#------------------------------------------------------------------------------
# Phase 2: Worker Pool Outputs
#------------------------------------------------------------------------------

output "runner_job_name" {
  description = "Name of the Cloud Run Job for runners"
  value       = module.worker_pool.job_name
}

output "runner_job_uri" {
  description = "URI of the Cloud Run Job"
  value       = module.worker_pool.job_uri
}

#------------------------------------------------------------------------------
# Phase 3: Autoscaler Outputs
#------------------------------------------------------------------------------

output "autoscaler_service_uri" {
  description = "URI of the autoscaler Cloud Run Service"
  value       = module.autoscaler.service_uri
}

output "webhook_url" {
  description = "URL to configure in GitHub organization webhook settings"
  value       = module.autoscaler.webhook_url
}

#------------------------------------------------------------------------------
# Docker Host Outputs (Issue #31)
#------------------------------------------------------------------------------

output "docker_host_url" {
  description = "DOCKER_HOST URL for runners to connect to remote Docker daemon"
  value       = module.docker_host.docker_host_url
}

output "docker_host_internal_ip" {
  description = "Internal IP of the Docker host VM"
  value       = module.docker_host.internal_ip
}

output "docker_host_instance_name" {
  description = "Name of the Docker host VM instance"
  value       = module.docker_host.instance_name
}
