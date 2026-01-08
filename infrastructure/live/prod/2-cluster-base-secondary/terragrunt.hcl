# Stage 2b: Cluster Base (Secondary) - Issue #117
#
# Installs ArgoCD on the secondary cloudspace using kubeconfig from Stage 1b.
# Only runs after secondary cloudspace confirms it's ready.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the same cluster-base module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/cluster-base"
}

# Dependency on Stage 1b - secondary cloudspace must exist and provide kubeconfig
dependency "cloudspace" {
  config_path = "../1-cloudspace-secondary"

  mock_outputs = {
    cloudspace_name        = "mock-cluster-secondary"
    region                 = "us-central-dfw-1"
    cluster_endpoint       = "https://mock-endpoint-secondary.example.com"
    cluster_ca_certificate = "bW9jay1jYS1jZXJ0"
    cluster_token          = "mock-token"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Load environment-specific variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env-vars/prod.hcl"))
}

inputs = {
  cluster_endpoint       = dependency.cloudspace.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.cloudspace.outputs.cluster_ca_certificate
  cluster_token          = dependency.cloudspace.outputs.cluster_token
  argocd_chart_version   = local.env_vars.locals.argocd_chart_version
}
