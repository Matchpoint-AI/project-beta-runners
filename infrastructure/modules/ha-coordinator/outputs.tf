# HA Coordinator Module - Outputs
#
# Provides HA status, node balancing information, and operational metrics.

# -----------------------------------------------------------------------------
# HA Gate Status
# -----------------------------------------------------------------------------

output "ha_active" {
  description = "Whether HA mode is currently active (both cloudspaces ready)"
  value       = local.ha_gate_passed
}

output "ha_status" {
  description = "HA status code: ACTIVE, DISABLED, BLOCKED_PRIMARY_UNAVAILABLE, BLOCKED_SECONDARY_UNAVAILABLE, BLOCKED_BOTH_UNAVAILABLE"
  value       = local.ha_status
}

output "ha_status_message" {
  description = "Human-readable HA status message for operators"
  value       = local.ha_status_message
}

# -----------------------------------------------------------------------------
# Cloudspace Health
# -----------------------------------------------------------------------------

output "primary_ready" {
  description = "Whether the primary cloudspace is ready"
  value       = var.primary_cloudspace_ready
}

output "secondary_ready" {
  description = "Whether the secondary cloudspace is ready"
  value       = var.secondary_cloudspace_ready
}

output "cloudspaces" {
  description = "Cloudspace configuration and health summary"
  value = {
    primary = {
      name  = var.primary_cloudspace_name
      ready = var.primary_cloudspace_ready
      nodes = var.primary_node_count
      max   = var.primary_max_nodes
    }
    secondary = {
      name  = var.secondary_cloudspace_name
      ready = var.secondary_cloudspace_ready
      nodes = var.secondary_node_count
      max   = var.secondary_max_nodes
    }
  }
}

# -----------------------------------------------------------------------------
# Node Balancing
# -----------------------------------------------------------------------------

output "effective_nodes_per_cloudspace" {
  description = "Balanced node count per cloudspace (min of primary and secondary)"
  value       = local.effective_nodes_per_cloudspace
}

output "total_effective_nodes" {
  description = "Total effective nodes across all cloudspaces"
  value       = local.total_effective_nodes
}

output "node_balance_details" {
  description = "Detailed node balancing information including which side is constraining"
  value       = local.node_balance_details
}

# -----------------------------------------------------------------------------
# Capacity Metrics
# -----------------------------------------------------------------------------

output "max_possible_nodes" {
  description = "Maximum possible nodes if both cloudspaces at full capacity"
  value       = local.max_possible_nodes
}

output "capacity_utilization_percent" {
  description = "Current capacity utilization as percentage of max possible"
  value       = local.capacity_utilization
}

# -----------------------------------------------------------------------------
# Summary Report (for CI/CD and monitoring)
# -----------------------------------------------------------------------------

output "ha_summary" {
  description = "Complete HA status summary for monitoring and alerting"
  value = {
    timestamp             = timestamp()
    ha_enabled            = var.ha_enabled
    ha_active             = local.ha_gate_passed
    ha_status             = local.ha_status
    ha_status_message     = local.ha_status_message
    total_effective_nodes = local.total_effective_nodes
    capacity_utilization  = "${format("%.1f", local.capacity_utilization)}%"
    primary_cloudspace    = var.primary_cloudspace_name
    secondary_cloudspace  = var.secondary_cloudspace_name
    node_balance          = local.node_balance_details
  }
}
