# Stage 3: ArgoCD Apps
#
# Creates the bootstrap ArgoCD Application that manages ARC deployment.
# This follows the "App of Apps" GitOps pattern:
# - Terraform creates namespaces and secrets
# - Terraform applies bootstrap Application CRD
# - ArgoCD syncs and manages ARC controller + runners from repo manifests
#
# This is the fastest operation (1-2 minutes).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load module version configuration
locals {
  source_config = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
}

# Reference the argocd-apps module from remote repository
terraform {
  source = "${local.source_config.locals.tf_modules_repo}//argocd-apps?ref=${local.source_config.locals.tf_modules_version}"
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

# Dependency on Stage 2 - ArgoCD must be installed before we create Applications
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

  # ArgoCD sync configuration
  repo_url        = "https://github.com/Matchpoint-AI/project-beta-runners"
  target_revision = "main"

  # Keep existing ArgoCD Application name for backward compatibility
  # (module default changed to "github-runners-bootstrap" for reusability)
  bootstrap_app_name = "project-beta-runners-bootstrap"
}
