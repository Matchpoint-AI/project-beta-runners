# Stage 3b: ArgoCD Apps (Secondary) - Issue #117
#
# Creates the bootstrap ArgoCD Application that manages ARC deployment on secondary cluster.
# This follows the "App of Apps" GitOps pattern:
# - Terraform creates namespaces and secrets
# - Terraform applies bootstrap Application CRD
# - ArgoCD syncs and manages ARC controller + runners from repo manifests
#
# SKIP: This module is skipped until the secondary cloudspace is provisioned.
# The kubernetes provider requires a real cluster connection even during plan.
# TODO: Remove this skip block after secondary cloudspace is Ready.
skip = true

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

# Dependency on Stage 1b - need kubeconfig to talk to secondary cluster
dependency "cloudspace" {
  config_path = "../1-cloudspace-secondary"

  mock_outputs = {
    cloudspace_name        = "mock-cluster-secondary"
    region                 = "us-central-dfw-1"
    cluster_endpoint       = "https://mock-endpoint-secondary.example.com"
    cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUREekNDQWZlZ0F3SUJBZ0lVV29jaTFhNGFMSm03elEvd2wyMm1wM3ZJNGZvd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0Z6RVZNQk1HQTFVRUF3d01iVzlqYXkxamJIVnpkR1Z5TUI0WERUSTJNREV3T0RJek5EazFNMW9YRFRJMgpNREV3T1RJek5EazFNMW93RnpFVk1CTUdBMVVFQXd3TWJXOWpheTFqYkhWemRHVnlNSUlCSWpBTkJna3Foa2lHCjl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUFzOHFjcEQ2Nzh3YlFjSlMyT2FJMjFLanZNeW9MZ2tsMmlOYW4Ka1FEWGJ6a2U0U3VKeWZ4V2x3ekNNMmJIQTFmZ2t0c21nMDFWSUxrNXRHMUgvenMwMFBtTWloUFFjdEZESzZWbgprMThQaGhVZ0hKa2JpVW50RithMm0wOGxZN202MlcrY0g3NjdXRVdZWUsyV2EveVRER0N1L0FqOG9qb2FGTlRKCkt1a2hKbUlHcnlsNWJKTml6YzB2SkVJVFl2SUl2cnVpQUpobVdrWDY2NmdUR3Z3T0JvZWZRTUtJRC9zUnRUTXQKWEMwSlpZSkN3WlA0dkFUQkUwaHgvbk1sUVdycFRzY2ZLbWtnUklIN3hRWHM3cnkxU3V2K3c2NHE4NFc2RUN4dQpSSjUzUW1VcjhoRVdSYm9mNHVWby9hUzFmVDlnNlE4MlgxUEg4NHVnSWFVSHBiYVF6UUlEQVFBQm8xTXdVVEFkCkJnTlZIUTRFRmdRVU90OGgreTIwKzNUZ3ZVa09KWE1xRWF1YVJ5NHdId1lEVlIwakJCZ3dGb0FVT3Q4aCt5MjAKKzNUZ3ZVa09KWE1xRWF1YVJ5NHdEd1lEVlIwVEFRSC9CQVV3QXdFQi96QU5CZ2txaGtpRzl3MEJBUXNGQUFPQwpBUUVBaTF5WHpxaU13cUxDZ2dlRnNNYmpQbkl4MG9tcDh4bjg1ZnR2RTdUTDZ2M3lKbzZuamM1bmVibUZYUVhlClZObjhsZlFFWkpVS1NKWUdOTjBzai9Eb1lBaTZoRktvTzVUQW5UUGFJellxbGk2TEUrODlNYjJ2SFZBNFJTMDYKeXZlcW5VUCtzYUlSVUk4b1Bqa3Z4U0cwK0JHT0lYRWR0MXFVai9wKzRhdjB4em9EM2lsZHZhbHJLOFhFQ1liUApnM1RMR0VLQnRyckRONFk3QXNob29TZWd3UDVrR0pCaXZBbHYrdllEbWFwS3hDcmlJRlNTT0VSSXdHQ3NmR2tvCjlmcEZKUVBWNm9iLzA0QTBWelMzWUVlRmxENlAwSnRvb0tlZEIraUNFYmFWR2xUeDlhTkc4czRmbUcrZlphT3oKbUQrWHA5L1JZbllId0VYL1hhRnJIN1hoZ1E9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
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
