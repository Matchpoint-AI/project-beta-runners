# State 1-v2: Second Cloudspace (matchpoint-github-actions-runners)
#
# Second Rackspace Spot managed Kubernetes cluster for testing/redundancy.
# This cloudspace was created manually and imported into terraform state.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the cloudspace module
terraform {
  source = "${get_parent_terragrunt_dir()}/../modules/cloudspace"
}

# Override cluster name for this cloudspace
inputs = {
  cluster_name = "matchpoint-github-actions-runners"
  region       = "us-central-dfw-1"
  server_class = "gp.vs1.large-dfw"
  min_nodes    = 2
  max_nodes    = 15
}

# Temporary import blocks - remove after first successful apply
generate "imports" {
  path      = "imports.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# Import the manually-created cloudspace
# These blocks will import existing resources into terraform state
# Remove this file after successful import

import {
  to = spot_cloudspace.this
  id = "matchpoint-github-actions-runners"
}

import {
  to = spot_spotnodepool.this
  id = "e1db3e70-466a-44be-aa7b-00daaae14259"
}
EOF
}
