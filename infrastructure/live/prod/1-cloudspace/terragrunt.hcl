# State 1: Cloudspace
#
# Creates the Rackspace Spot managed Kubernetes cluster and node pool.
# This is the slowest operation (~50-60 minutes for control plane provisioning).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the cloudspace module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/cloudspace"
}

# Load environment-specific variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env-vars/prod.hcl"))
}

inputs = {
  cluster_name = local.env_vars.locals.cluster_name
  region       = local.env_vars.locals.region
  server_class = local.env_vars.locals.server_class
  min_nodes    = local.env_vars.locals.min_nodes
  max_nodes    = local.env_vars.locals.max_nodes
  bid_price    = local.env_vars.locals.bid_price
}
