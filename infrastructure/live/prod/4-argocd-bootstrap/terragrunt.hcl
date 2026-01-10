# Stage 4: ArgoCD Bootstrap
#
# Creates the bootstrap ArgoCD Application that syncs from this repository.
# ArgoCD will then manage:
# - arc-controller (ARC controller Helm chart)
# - arc-runners (ARC runner scale set Helm chart)
#
# This depends on 3-arc-prereqs which creates the required namespaces and secrets.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load module version configuration
locals {
  source_config = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
}

# Reference the argocd-bootstrap module from remote repository
terraform {
  source = "${local.source_config.locals.tf_modules_repo}//argocd-bootstrap?ref=${local.source_config.locals.tf_modules_version}"
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

# Dependency on Stage 3 - namespaces and secrets must exist before ArgoCD Application
dependency "arc_prereqs" {
  config_path = "../3-arc-prereqs"

  mock_outputs = {
    arc_namespace           = "arc-systems"
    runner_namespace        = "arc-runners"
    github_secret_name      = "arc-org-github-secret"
    github_secret_namespace = "arc-runners"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  # Kubeconfig from cloudspace
  cluster_endpoint       = dependency.cloudspace.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.cloudspace.outputs.cluster_ca_certificate
  cluster_token          = dependency.cloudspace.outputs.cluster_token

  # ArgoCD Application configuration
  application_name = "project-beta-runners-bootstrap"
  repo_url         = "https://github.com/Matchpoint-AI/project-beta-runners"
  target_revision  = "main"
  sync_path        = "argocd/applications"
}
