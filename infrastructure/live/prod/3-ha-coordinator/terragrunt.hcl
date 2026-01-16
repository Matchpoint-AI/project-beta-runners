# Stage 3: HA Coordinator
#
# Coordinates High Availability across dual cloudspaces.
# This module acts as the HA "gate" - workloads should only be distributed
# when both cloudspaces are healthy and ready.
#
# Key responsibilities:
# 1. HA Gate: Verify both cloudspaces are provisioned and ready
# 2. Node Balancing: Calculate min(primary_nodes, secondary_nodes)
# 3. Status Reporting: Provide clear HA readiness state
#
# Issue #121: High Availability across dual cloudspaces

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load configuration
locals {
  versions = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
  env_vars = read_terragrunt_config(find_in_parent_folders("env-vars/prod.hcl"))

  # Local module path for ha-coordinator
  local_modules = "${get_parent_terragrunt_dir()}/../modules"
}

# Use local ha-coordinator module
terraform {
  source = "${local.local_modules}//ha-coordinator"
}

# Dependencies on both cloudspaces
dependency "cloudspace_primary" {
  config_path = "../1-cloudspace"

  mock_outputs = {
    cloudspace_name   = "mock-primary"
    cloudspace_ready  = false
    current_nodes     = 0
    region            = "us-central-dfw-1"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "cloudspace_secondary" {
  config_path = "../1-cloudspace-secondary"

  mock_outputs = {
    cloudspace_name   = "mock-secondary"
    cloudspace_ready  = false
    current_nodes     = 0
    region            = "us-central-dfw-1"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  # Primary cloudspace
  primary_cloudspace_name  = dependency.cloudspace_primary.outputs.cloudspace_name
  primary_cloudspace_ready = try(dependency.cloudspace_primary.outputs.cloudspace_ready, false)
  primary_node_count       = try(dependency.cloudspace_primary.outputs.current_nodes, 0)
  primary_max_nodes        = local.env_vars.locals.max_nodes

  # Secondary cloudspace
  secondary_cloudspace_name  = dependency.cloudspace_secondary.outputs.cloudspace_name
  secondary_cloudspace_ready = try(dependency.cloudspace_secondary.outputs.cloudspace_ready, false)
  secondary_node_count       = try(dependency.cloudspace_secondary.outputs.current_nodes, 0)
  secondary_max_nodes        = local.env_vars.locals.max_nodes

  # HA configuration
  ha_enabled = local.env_vars.locals.ha_enabled
}
