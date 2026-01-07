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

# Reference the argocd-apps module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/argocd-apps"
}

# Dependency on Stage 2 - ArgoCD must be installed
dependency "cluster_base" {
  config_path = "../2-cluster-base"

  mock_outputs = {
    kubeconfig_raw   = "mock"
    cluster_endpoint = "https://mock:6443"
    argocd_namespace = "argocd"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # GitHub PAT for runner registration
  github_token = get_env("INFRA_GH_TOKEN", "")

  # ArgoCD sync configuration
  repo_url        = "https://github.com/Matchpoint-AI/project-beta-runners"
  target_revision = "main"
}
