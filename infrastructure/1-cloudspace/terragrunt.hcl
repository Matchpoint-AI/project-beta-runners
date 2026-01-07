# State 1: Cloudspace
#
# Creates the Rackspace Spot managed Kubernetes cluster and node pool.
# This is the slowest operation (~50-60 minutes for control plane provisioning).
#
# Dependencies: None (this is the first state)
# Dependents: 2-cluster-base

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment-specific configuration
include "env" {
  path   = "${dirname(find_in_parent_folders())}/_env/prod.hcl"
  expose = true
}

# Module-specific inputs
inputs = {
  cluster_name = include.env.locals.cluster_name
  region       = include.env.locals.region
  server_class = include.env.locals.server_class
  min_nodes    = include.env.locals.min_nodes
  max_nodes    = include.env.locals.max_nodes
}
