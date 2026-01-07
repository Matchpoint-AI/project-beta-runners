# Stage 3: ArgoCD Apps
#
# Deploys ARC controller and runner ScaleSet.
# This is the fastest operation (2-5 minutes).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the argocd-apps module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/argocd-apps"
}

# Dependency on Stage 2 - Cluster must be ready
dependency "cluster_base" {
  config_path = "../2-cluster-base"

  mock_outputs = {
    kubeconfig_raw   = "mock"
    cluster_endpoint = "https://mock:6443"
    argocd_namespace = "argocd"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Load environment-specific variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env-vars/prod.hcl"))
}

inputs = {
  runner_label = local.env_vars.locals.runner_label
  min_runners  = local.env_vars.locals.min_runners
  max_runners  = local.env_vars.locals.max_runners
  arc_version  = local.env_vars.locals.arc_version
  github_org   = local.env_vars.locals.github_org
  github_token = get_env("INFRA_GH_TOKEN", "")
}
