# State 3: ArgoCD Apps
#
# Deploys ARC controller and runner ScaleSet via ArgoCD Applications.
# This is the fastest operation (2-5 minutes).
#
# Dependencies: 2-cluster-base (ArgoCD must be installed)
# Dependents: None (final state)

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment-specific configuration
include "env" {
  path   = "${dirname(find_in_parent_folders())}/_env/prod.hcl"
  expose = true
}

# Dependency on State 2 - ArgoCD must be ready
dependency "cluster_base" {
  config_path = "../2-cluster-base"
  
  # Mock outputs for `terragrunt plan` when State 2 hasn't been applied yet
  mock_outputs = {
    kubeconfig_raw     = "mock"
    cluster_endpoint   = "https://mock-cluster:6443"
    argocd_namespace   = "argocd"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Also need cloudspace info for some configurations
dependency "cloudspace" {
  config_path = "../1-cloudspace"
  
  mock_outputs = {
    cloudspace_name = "mock-cluster"
    region          = "us-central-dfw-1"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Module-specific inputs
inputs = {
  kubeconfig_raw   = dependency.cluster_base.outputs.kubeconfig_raw
  argocd_namespace = dependency.cluster_base.outputs.argocd_namespace
  cloudspace_name  = dependency.cloudspace.outputs.cloudspace_name
  
  # Runner configuration
  runner_label = include.env.locals.runner_label
  min_runners  = include.env.locals.min_runners
  max_runners  = include.env.locals.max_runners
}
