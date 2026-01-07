# Stage 2: Cluster Base
#
# Installs ArgoCD using kubeconfig from Stage 1.
# Only runs after Stage 1 confirms the cluster is ready.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the cluster-base module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/cluster-base"
}

# Dependency on Stage 1 - cluster must exist and provide kubeconfig
dependency "cloudspace" {
  config_path = "../1-cloudspace"

  mock_outputs = {
    cloudspace_name        = "mock-cluster"
    region                 = "us-central-dfw-1"
    cluster_endpoint       = "https://mock-endpoint.example.com"
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
