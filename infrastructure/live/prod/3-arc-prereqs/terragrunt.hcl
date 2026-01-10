# Stage 3: ARC Prerequisites
#
# Creates the Kubernetes resources required before ArgoCD can sync ARC applications:
# - arc-systems namespace (for controller)
# - arc-runners namespace (for runner pods)
# - GitHub token secret (for runner registration)
#
# This must run BEFORE 4-argocd-bootstrap, which creates the ArgoCD Application.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load module version configuration
locals {
  source_config = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
}

# Reference the arc-prereqs module from remote repository
terraform {
  source = "${local.source_config.locals.tf_modules_repo}//arc-prereqs?ref=${local.source_config.locals.tf_modules_version}"
}

# Dependency on Stage 1 - need kubeconfig to talk to cluster
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

# Dependency on Stage 2 - ArgoCD must be installed before we create namespaces
dependency "cluster_base" {
  config_path = "../2-cluster-base"

  mock_outputs = {
    argocd_namespace = "argocd"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  # Kubeconfig from cloudspace
  cluster_endpoint       = dependency.cloudspace.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.cloudspace.outputs.cluster_ca_certificate
  cluster_token          = dependency.cloudspace.outputs.cluster_token

  # GitHub PAT for runner registration
  github_token = get_env("INFRA_GH_TOKEN", "")
}
