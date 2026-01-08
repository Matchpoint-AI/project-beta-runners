# Stage 3b: ArgoCD Apps (Secondary) - Issue #117
#
# Creates the bootstrap ArgoCD Application that manages ARC deployment on secondary cluster.
# This follows the "App of Apps" GitOps pattern:
# - Terraform creates namespaces and secrets
# - Terraform applies bootstrap Application CRD
# - ArgoCD syncs and manages ARC controller + runners from repo manifests

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the same argocd-apps module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/argocd-apps"
}

# Dependency on Stage 1b - need kubeconfig to talk to secondary cluster
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

# Dependency on Stage 2b - ArgoCD must be installed before we create Applications
dependency "cluster_base" {
  config_path = "../2-cluster-base-secondary"

  mock_outputs = {
    argocd_namespace = "argocd"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  # Kubeconfig from secondary cloudspace
  cluster_endpoint       = dependency.cloudspace.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.cloudspace.outputs.cluster_ca_certificate
  cluster_token          = dependency.cloudspace.outputs.cluster_token

  # GitHub PAT for runner registration
  github_token = get_env("INFRA_GH_TOKEN", "")

  # ArgoCD sync configuration
  repo_url        = "https://github.com/Matchpoint-AI/project-beta-runners"
  target_revision = "main"
}
