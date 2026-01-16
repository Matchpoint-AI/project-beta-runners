# HA Coordinator Module

Coordinates High Availability across dual cloudspaces for the project-beta-runners infrastructure.

## Overview

This module implements:

- **HA Gate Logic**: Determines when HA mode can be safely activated
- **Balanced Node Distribution**: Ensures equal resource distribution across cloudspaces
- **Status Reporting**: Provides detailed status information for operators and monitoring

## HA Gate

HA mode is only active when BOTH cloudspaces are:
1. Provisioned
2. In Ready state

This prevents workload distribution to unhealthy cloudspaces.

### HA Status Codes

| Status | Description |
|--------|-------------|
| `ACTIVE` | Both cloudspaces healthy, HA operating normally |
| `DISABLED` | HA mode disabled by configuration |
| `BLOCKED_PRIMARY_UNAVAILABLE` | Primary cloudspace not ready |
| `BLOCKED_SECONDARY_UNAVAILABLE` | Secondary cloudspace not ready |
| `BLOCKED_BOTH_UNAVAILABLE` | Neither cloudspace ready |

## Node Balancing

Both cloudspaces must have the same effective node count for balanced HA:

```
effective_nodes = min(primary_nodes, secondary_nodes)
```

**Example**: If primary has 10 nodes and secondary has 8, both operate with 8 effective nodes.

## Usage

```hcl
module "ha_coordinator" {
  source = "../../modules/ha-coordinator"

  primary_cloudspace_name   = "matchpoint-runners-primary"
  secondary_cloudspace_name = "matchpoint-runners-secondary"

  primary_cloudspace_ready   = true
  secondary_cloudspace_ready = true

  primary_node_count   = 10
  secondary_node_count = 8

  primary_max_nodes   = 20
  secondary_max_nodes = 20

  ha_enabled = true
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ha_enabled"></a> [ha\_enabled](#input\_ha\_enabled) | Whether HA mode should be enabled (requires both cloudspaces) | `bool` | `true` | no |
| <a name="input_primary_cloudspace_name"></a> [primary\_cloudspace\_name](#input\_primary\_cloudspace\_name) | Name of the primary cloudspace | `string` | n/a | yes |
| <a name="input_primary_cloudspace_ready"></a> [primary\_cloudspace\_ready](#input\_primary\_cloudspace\_ready) | Whether the primary cloudspace is in Ready state | `bool` | n/a | yes |
| <a name="input_primary_max_nodes"></a> [primary\_max\_nodes](#input\_primary\_max\_nodes) | Maximum nodes configured for primary cloudspace | `number` | n/a | yes |
| <a name="input_primary_node_count"></a> [primary\_node\_count](#input\_primary\_node\_count) | Current node count in primary cloudspace | `number` | n/a | yes |
| <a name="input_secondary_cloudspace_name"></a> [secondary\_cloudspace\_name](#input\_secondary\_cloudspace\_name) | Name of the secondary cloudspace | `string` | n/a | yes |
| <a name="input_secondary_cloudspace_ready"></a> [secondary\_cloudspace\_ready](#input\_secondary\_cloudspace\_ready) | Whether the secondary cloudspace is in Ready state | `bool` | n/a | yes |
| <a name="input_secondary_max_nodes"></a> [secondary\_max\_nodes](#input\_secondary\_max\_nodes) | Maximum nodes configured for secondary cloudspace | `number` | n/a | yes |
| <a name="input_secondary_node_count"></a> [secondary\_node\_count](#input\_secondary\_node\_count) | Current node count in secondary cloudspace | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_capacity_utilization_percent"></a> [capacity\_utilization\_percent](#output\_capacity\_utilization\_percent) | Current capacity utilization as percentage of max possible |
| <a name="output_cloudspaces"></a> [cloudspaces](#output\_cloudspaces) | Cloudspace configuration and health summary |
| <a name="output_effective_nodes_per_cloudspace"></a> [effective\_nodes\_per\_cloudspace](#output\_effective\_nodes\_per\_cloudspace) | Balanced node count per cloudspace (min of primary and secondary) |
| <a name="output_ha_active"></a> [ha\_active](#output\_ha\_active) | Whether HA mode is currently active (both cloudspaces ready) |
| <a name="output_ha_status"></a> [ha\_status](#output\_ha\_status) | HA status code: ACTIVE, DISABLED, BLOCKED\_PRIMARY\_UNAVAILABLE, BLOCKED\_SECONDARY\_UNAVAILABLE, BLOCKED\_BOTH\_UNAVAILABLE |
| <a name="output_ha_status_message"></a> [ha\_status\_message](#output\_ha\_status\_message) | Human-readable HA status message for operators |
| <a name="output_ha_summary"></a> [ha\_summary](#output\_ha\_summary) | Complete HA status summary for monitoring and alerting |
| <a name="output_max_possible_nodes"></a> [max\_possible\_nodes](#output\_max\_possible\_nodes) | Maximum possible nodes if both cloudspaces at full capacity |
| <a name="output_node_balance_details"></a> [node\_balance\_details](#output\_node\_balance\_details) | Detailed node balancing information including which side is constraining |
| <a name="output_primary_ready"></a> [primary\_ready](#output\_primary\_ready) | Whether the primary cloudspace is ready |
| <a name="output_secondary_ready"></a> [secondary\_ready](#output\_secondary\_ready) | Whether the secondary cloudspace is ready |
| <a name="output_total_effective_nodes"></a> [total\_effective\_nodes](#output\_total\_effective\_nodes) | Total effective nodes across all cloudspaces |
<!-- END_TF_DOCS -->
