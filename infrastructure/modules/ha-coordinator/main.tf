# HA Coordinator Module - Main
#
# Coordinates High Availability across dual cloudspaces.
# Implements the HA gate and balanced node distribution logic.
#
# HA Mode Requirements:
# 1. Both cloudspaces must be provisioned and in Ready state
# 2. Node count is balanced using min(primary_nodes, secondary_nodes)
# 3. Status reporting indicates HA readiness state

terraform {
  required_version = ">= 1.0"
}

# -----------------------------------------------------------------------------
# HA Gate Logic
# -----------------------------------------------------------------------------
# HA mode is only active when BOTH cloudspaces are successfully provisioned
# and in a Ready state. This prevents workload distribution to unhealthy
# cloudspaces.

locals {
  # HA Gate: Both cloudspaces must be ready
  ha_gate_passed = var.ha_enabled && var.primary_cloudspace_ready && var.secondary_cloudspace_ready

  # HA Status determination
  ha_status = local.ha_gate_passed ? "ACTIVE" : (
    !var.ha_enabled ? "DISABLED" : (
      !var.primary_cloudspace_ready && !var.secondary_cloudspace_ready ? "BLOCKED_BOTH_UNAVAILABLE" : (
        !var.primary_cloudspace_ready ? "BLOCKED_PRIMARY_UNAVAILABLE" : "BLOCKED_SECONDARY_UNAVAILABLE"
      )
    )
  )

  # Detailed status message for operators
  ha_status_message = local.ha_gate_passed ? (
    "HA is ACTIVE. Both cloudspaces are healthy and accepting workloads."
  ) : (
    !var.ha_enabled ? "HA is DISABLED by configuration." : (
      !var.primary_cloudspace_ready && !var.secondary_cloudspace_ready ? (
        "HA is BLOCKED. Neither cloudspace is ready. Check provisioning status."
      ) : (
        !var.primary_cloudspace_ready ? (
          "HA is BLOCKED. Primary cloudspace (${var.primary_cloudspace_name}) is not ready."
        ) : (
          "HA is BLOCKED. Secondary cloudspace (${var.secondary_cloudspace_name}) is not ready."
        )
      )
    )
  )
}

# -----------------------------------------------------------------------------
# Balanced Node Distribution
# -----------------------------------------------------------------------------
# Both cloudspaces must have the same effective node count for balanced HA.
# Formula: effective_nodes = min(primary_nodes, secondary_nodes)
#
# Example: If primary has 10 nodes and secondary has 8, both operate with 8.

locals {
  # Effective node count per cloudspace (only meaningful when HA is active)
  effective_nodes_per_cloudspace = local.ha_gate_passed ? min(
    var.primary_node_count,
    var.secondary_node_count
  ) : 0

  # Total effective nodes across both cloudspaces
  total_effective_nodes = local.ha_gate_passed ? (
    local.effective_nodes_per_cloudspace * 2
  ) : (
    var.primary_cloudspace_ready ? var.primary_node_count : 0
  )

  # Node balancing details for status reporting
  node_balance_details = local.ha_gate_passed ? {
    primary_actual    = var.primary_node_count
    secondary_actual  = var.secondary_node_count
    effective_each    = local.effective_nodes_per_cloudspace
    total_effective   = local.total_effective_nodes
    nodes_constrained = var.primary_node_count != var.secondary_node_count
    constraining_side = var.primary_node_count < var.secondary_node_count ? "primary" : (
      var.secondary_node_count < var.primary_node_count ? "secondary" : "none"
    )
  } : {
    primary_actual    = var.primary_node_count
    secondary_actual  = var.secondary_node_count
    effective_each    = 0
    total_effective   = local.total_effective_nodes
    nodes_constrained = false
    constraining_side = "n/a"
  }
}

# -----------------------------------------------------------------------------
# Capacity Planning
# -----------------------------------------------------------------------------
# Calculate maximum potential capacity and utilization metrics

locals {
  # Maximum possible nodes (if both cloudspaces at max capacity)
  max_possible_nodes = var.primary_max_nodes + var.secondary_max_nodes

  # Current capacity utilization
  capacity_utilization = local.max_possible_nodes > 0 ? (
    local.total_effective_nodes / local.max_possible_nodes * 100
  ) : 0
}
