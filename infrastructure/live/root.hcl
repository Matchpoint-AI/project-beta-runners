# Root Terragrunt configuration for project-beta-runners
#
# This file is included by all service-level terragrunt.hcl files
# Following the same pattern as project-beta infrastructure

locals {
  # Parse environment from directory path: .../live/{environment}/{service}/
  parsed_path = regex(".*/live/([^/]+)/.*", get_terragrunt_dir())
  environment = local.parsed_path[0]

  # Load environment-specific variables
  env_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/env-vars/${local.environment}.hcl")

  # Common configuration
  cluster_name = local.env_vars.locals.cluster_name
  region       = local.env_vars.locals.region
}

# Configure remote state backend (GCS)
remote_state {
  backend = "gcs"
  config = {
    bucket   = get_env("GCS_BUCKET")
    project  = get_env("GCP_PROJECT")
    prefix   = "runners/${path_relative_to_include()}"
    location = "us-central1"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "rackspace-spot" {
  token = var.rackspace_spot_token
}

variable "rackspace_spot_token" {
  description = "Rackspace Spot API token"
  type        = string
  sensitive   = true
}
EOF
}

# Common inputs for all modules
inputs = {
  rackspace_spot_token = get_env("RACKSPACE_SPOT_TOKEN")
  cluster_name         = local.cluster_name
  region               = local.region
}
