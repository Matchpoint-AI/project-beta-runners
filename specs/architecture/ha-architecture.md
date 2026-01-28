# High Availability Architecture

This document describes the High Availability (HA) architecture for the project-beta-runners infrastructure.

## Overview

The HA architecture distributes GitHub Actions runner workloads across two independent Rackspace Spot cloudspaces, providing:

- **Fault Tolerance**: Workloads continue if one cloudspace fails
- **Rolling Maintenance**: Update one cloudspace while the other serves traffic
- **Balanced Capacity**: Equal resource distribution across cloudspaces

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GitHub Cloud                                   │
│                     (Actions workflow dispatch)                             │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  │ runs-on: project-beta-runners
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HA Coordinator (Stage 3)                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  HA Gate Logic                                                       │   │
│  │  ├── primary_ready   = cloudspace_primary.ready                      │   │
│  │  ├── secondary_ready = cloudspace_secondary.ready                    │   │
│  │  └── ha_active       = primary_ready AND secondary_ready             │   │
│  │                                                                       │   │
│  │  Node Balancing                                                       │   │
│  │  └── effective_nodes = min(primary_nodes, secondary_nodes)           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
┌───────────────────────────────┐ ┌───────────────────────────────┐
│   Primary Cloudspace          │ │   Secondary Cloudspace        │
│   (matchpoint-runners)        │ │   (matchpoint-runners-2)      │
│                               │ │                               │
│  ┌─────────────────────────┐  │ │  ┌─────────────────────────┐  │
│  │  Kubernetes Cluster     │  │ │  │  Kubernetes Cluster     │  │
│  │  ├── ArgoCD             │  │ │  │  ├── ArgoCD             │  │
│  │  ├── ARC Controller     │  │ │  │  ├── ARC Controller     │  │
│  │  └── Runner Pods (N)    │  │ │  │  └── Runner Pods (N)    │  │
│  └─────────────────────────┘  │ │  └─────────────────────────┘  │
│                               │ │                               │
│  Region: us-central-dfw-1     │ │  Region: us-central-dfw-1     │
│  Max Nodes: 12                │ │  Max Nodes: 12                │
└───────────────────────────────┘ └───────────────────────────────┘
```

## HA Gate Logic

HA mode is only activated when **both** cloudspaces are successfully provisioned and healthy. This is enforced by the HA Coordinator module.

### Gate Conditions

| Condition | HA Status | Description |
|-----------|-----------|-------------|
| Both Ready | `ACTIVE` | Full HA operation |
| Primary Only | `BLOCKED_SECONDARY_UNAVAILABLE` | Secondary not provisioned |
| Secondary Only | `BLOCKED_PRIMARY_UNAVAILABLE` | Primary not provisioned |
| Neither Ready | `BLOCKED_BOTH_UNAVAILABLE` | Both cloudspaces down |
| HA Disabled | `DISABLED` | Manual override via config |

### State Machine

```
                    ┌─────────────────────┐
                    │     DISABLED        │ ◄── ha_enabled = false
                    └─────────────────────┘
                              │
                              │ ha_enabled = true
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  PROVISIONING                               │
│                                                             │
│  ┌───────────────────┐     ┌───────────────────┐          │
│  │ Primary Provision │     │ Secondary Provision│          │
│  └─────────┬─────────┘     └─────────┬─────────┘          │
│            │                         │                     │
│            ▼                         ▼                     │
│  ┌───────────────────┐     ┌───────────────────┐          │
│  │  Primary Ready    │     │ Secondary Ready   │          │
│  └─────────┬─────────┘     └─────────┬─────────┘          │
│            │                         │                     │
│            └───────────┬─────────────┘                     │
│                        │                                   │
│                        │ BOTH Ready                        │
│                        ▼                                   │
│            ┌───────────────────────┐                       │
│            │       ACTIVE          │                       │
│            │   (HA Operational)    │                       │
│            └───────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

## Node Balancing Algorithm

To ensure consistent workload distribution, both cloudspaces operate with an equal number of effective nodes.

### Formula

```
effective_nodes_per_cloudspace = min(
    available_nodes(primary_cloudspace),
    available_nodes(secondary_cloudspace)
)

primary.active_nodes = effective_nodes_per_cloudspace
secondary.active_nodes = effective_nodes_per_cloudspace
total_effective = effective_nodes_per_cloudspace * 2
```

### Examples

| Scenario | Primary Nodes | Secondary Nodes | Effective Each | Total |
|----------|---------------|-----------------|----------------|-------|
| Balanced | 10 | 10 | 10 | 20 |
| Primary Constrained | 8 | 12 | 8 | 16 |
| Secondary Constrained | 12 | 6 | 6 | 12 |
| One Down | 10 | 0 | 0 | 0 (HA blocked) |

### Rationale

- **Predictability**: Equal capacity simplifies workload distribution
- **Fairness**: Neither cloudspace is overloaded
- **Resilience**: If one fails, capacity loss is exactly 50%

## Terragrunt Stage Order

```
Stage 1a: 1-cloudspace           → Primary K8s cluster
Stage 1b: 1-cloudspace-secondary → Secondary K8s cluster (parallel)
Stage 2a: 2-cluster-base         → Primary ArgoCD + bootstrap
Stage 2b: 2-cluster-base-secondary → Secondary ArgoCD + bootstrap
Stage 3:  3-ha-coordinator       → HA gate + node balancing
```

## Configuration

HA is configured in `infrastructure/live/env-vars/prod.hcl`:

```hcl
locals {
  # Enable/disable HA coordination
  ha_enabled = true

  # Primary cloudspace
  cluster_name = "matchpoint-runners"
  max_nodes    = 12

  # Secondary cloudspace
  cluster_name_secondary = "matchpoint-runners-2"
  # Same max_nodes as primary for balanced capacity
}
```

## Monitoring

### Key Metrics

| Metric | Source | Alert Threshold |
|--------|--------|-----------------|
| `ha_status` | HA Coordinator output | != "ACTIVE" |
| `effective_nodes_per_cloudspace` | HA Coordinator output | < min_nodes |
| `capacity_utilization_percent` | HA Coordinator output | > 80% |

### Status Commands

```bash
# Check HA status via Terragrunt
cd infrastructure/live/prod/3-ha-coordinator
terragrunt output ha_summary

# Expected output when HA is active:
{
  "ha_active": true,
  "ha_status": "ACTIVE",
  "ha_status_message": "HA is ACTIVE. Both cloudspaces are healthy and accepting workloads.",
  "total_effective_nodes": 20,
  "capacity_utilization": "83.3%",
  ...
}
```

## Failure Scenarios

### Scenario 1: Secondary Cloudspace Fails

1. HA Coordinator detects `secondary_ready = false`
2. `ha_status` transitions to `BLOCKED_SECONDARY_UNAVAILABLE`
3. Workloads continue on primary (degraded mode)
4. Alert triggered for operator intervention

### Scenario 2: Primary Cloudspace Fails

1. HA Coordinator detects `primary_ready = false`
2. `ha_status` transitions to `BLOCKED_PRIMARY_UNAVAILABLE`
3. Secondary continues serving workloads (if ARC configured)
4. Alert triggered for operator intervention

### Scenario 3: Both Cloudspaces Fail

1. HA Coordinator detects both `*_ready = false`
2. `ha_status` = `BLOCKED_BOTH_UNAVAILABLE`
3. No runners available (workflow jobs queued)
4. Critical alert triggered

## Recovery Procedures

See [HA_RUNBOOK.md](./HA_RUNBOOK.md) for detailed recovery procedures.

## Related Issues

- Issue #117: Add secondary cloudspace for HA
- Issue #121: Implement HA gate and node balancing (this feature)
