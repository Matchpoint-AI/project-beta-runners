# ArgoCD Installation + Bootstrap
#
# Stage 2 of GKE migration. Installs ArgoCD and creates the bootstrap Application
# that syncs argocd/applications-gke/ from this repo.
# Depends on the GKE cluster existing (Stage 1).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  gke_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/env-vars/gke-prod.hcl")
}

dependency "gke_cluster" {
  config_path = "../gke-cluster"

  mock_outputs = {
    cluster_endpoint       = "https://10.0.0.1"
    cluster_ca_certificate = "LS0tLS1CRUdJTi..."
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../modules//argocd"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "helm" {
      kubernetes {
        host                   = "${dependency.gke_cluster.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.gke_cluster.outputs.cluster_ca_certificate}")
        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "gke-gcloud-auth-plugin"
        }
      }
    }

    provider "kubectl" {
      host                   = "${dependency.gke_cluster.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.gke_cluster.outputs.cluster_ca_certificate}")
      load_config_file       = false
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "gke-gcloud-auth-plugin"
      }
    }
  EOF
}

inputs = {
  argocd_chart_version   = local.gke_vars.locals.argocd_chart_version
  repo_url               = local.gke_vars.locals.repo_url
  cluster_endpoint       = dependency.gke_cluster.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.gke_cluster.outputs.cluster_ca_certificate
}
