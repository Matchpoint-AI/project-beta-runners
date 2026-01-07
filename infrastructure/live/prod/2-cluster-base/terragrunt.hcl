# State 2: Cluster Base
#
# Fetches kubeconfig and installs ArgoCD.
# Only runs after State 1 confirms the cluster is ready.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the cluster-base module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/cluster-base"
}

# Dependency on State 1 - cluster must exist before we can get kubeconfig
dependency "cloudspace" {
  config_path = "../1-cloudspace"
  
  mock_outputs = {
    cloudspace_name = "mock-cluster"
    region          = "us-central-dfw-1"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Load environment-specific variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env-vars/prod.hcl"))
}

inputs = {
  cloudspace_name      = dependency.cloudspace.outputs.cloudspace_name
  argocd_chart_version = local.env_vars.locals.argocd_chart_version
}
