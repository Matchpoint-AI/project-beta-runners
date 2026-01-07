# Root Terragrunt configuration for project-beta-runners
# 
# This configuration:
# - Uses GCS backend for state storage (credentials via WIF in CI)
# - Passes common variables to all child modules
# - Uses get_env() for environment-variable-based configuration

# Generate backend configuration for all child modules
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

# Generate provider configuration for all child modules
generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    rackspace-spot = {
      source  = "rackerlabs/rackspace-spot"
      version = ">= 0.1.0"
    }
  }
}

provider "rackspace-spot" {
  token = var.rackspace_spot_token
}
EOF
}

# Common inputs for all child modules
inputs = {
  rackspace_spot_token = get_env("RACKSPACE_SPOT_TOKEN")
  
  # Cluster configuration
  cluster_name   = "mp-runners-v3"
  region         = "us-central-dfw-1"
  
  # Node pool configuration  
  min_nodes = 2
  max_nodes = 15
  
  # Runner configuration
  runner_label = "project-beta-runners"
}
