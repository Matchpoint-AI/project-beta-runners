# Stage 1b: Secondary Cloudspace (Issue #117)
#
# Creates a second Rackspace Spot managed Kubernetes cluster for HA.
# This is a purely ADDITIVE change - does not affect the primary cloudspace.
#
# Provisioning takes ~50-60 minutes for control plane + nodepool.
# After this is Ready, we can safely reduce primary cloudspace resources.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load module version configuration
locals {
  versions = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
  env_vars      = read_terragrunt_config(find_in_parent_folders("env-vars/prod.hcl"))
}

# Reference the cloudspace module from remote repository
terraform {
  source = "${local.versions.locals.remote_modules}//cloudspace?ref=${local.versions.locals.modules_version}"
}

# Use secondary cloudspace configuration
inputs = {
  cluster_name = local.env_vars.locals.cluster_name_secondary
  region       = local.env_vars.locals.region
  server_class = local.env_vars.locals.server_class
  min_nodes    = local.env_vars.locals.min_nodes
  max_nodes    = local.env_vars.locals.max_nodes_secondary
  bid_price    = local.env_vars.locals.bid_price
}
