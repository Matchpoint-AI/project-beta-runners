# State 2: Cluster Base
#
# Fetches kubeconfig and installs ArgoCD.
# Only runs after State 1 confirms the cluster is ready.
#
# Dependencies: 1-cloudspace
# Dependents: 3-argocd-apps

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment-specific configuration
include "env" {
  path   = "${dirname(find_in_parent_folders())}/_env/prod.hcl"
  expose = true
}

# Dependency on State 1 - cluster must exist before we can get kubeconfig
dependency "cloudspace" {
  config_path = "../1-cloudspace"
  
  # Mock outputs for `terragrunt plan` when State 1 hasn't been applied yet
  mock_outputs = {
    cloudspace_name = "mock-cluster"
    region          = "us-central-dfw-1"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Module-specific inputs
inputs = {
  cloudspace_name = dependency.cloudspace.outputs.cloudspace_name
  region          = dependency.cloudspace.outputs.region
  argocd_version  = include.env.locals.argocd_version
}
