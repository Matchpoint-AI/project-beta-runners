# Stage 2: Cluster Base
#
# Installs ArgoCD and creates bootstrap Application.
# ArgoCD then manages everything else from Git manifests.
#
# After this stage, ArgoCD syncs from argocd/ directory:
# - argocd/prereqs/      → Namespaces, ExternalSecrets
# - argocd/applications/ → ARC controller, runners

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load module version configuration
locals {
  versions = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
  env_vars = read_terragrunt_config(find_in_parent_folders("env-vars/prod.hcl"))
}

# Reference the cluster-base module from remote repository
terraform {
  source = "${local.versions.locals.remote_modules}//cluster-base?ref=${local.versions.locals.modules_version}"
}

# State migration: kubernetes_manifest -> kubectl_manifest
# The module now uses kubectl_manifest instead of kubernetes_manifest.
# Remove the old resource from state and let kubectl_manifest adopt the existing Application.
generate "migration" {
  path      = "migration.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    # Remove old kubernetes_manifest from state (resource changed to kubectl_manifest)
    removed {
      from = kubernetes_manifest.bootstrap_application
      lifecycle {
        destroy = false
      }
    }
  EOF
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

inputs = {
  # Cluster connection from cloudspace dependency
  cluster_endpoint       = dependency.cloudspace.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.cloudspace.outputs.cluster_ca_certificate
  cluster_token          = dependency.cloudspace.outputs.cluster_token

  argocd_chart_version = local.env_vars.locals.argocd_chart_version

  # Bootstrap Application - ArgoCD syncs from this repo
  bootstrap_enabled         = true
  bootstrap_app_name        = "project-beta-runners-bootstrap"
  bootstrap_repo_url        = "https://github.com/Matchpoint-AI/project-beta-runners"
  bootstrap_sync_path       = "argocd/applications"
  bootstrap_target_revision = "main"
}
