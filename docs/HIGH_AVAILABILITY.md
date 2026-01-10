# High Availability (HA) Cloudspace Architecture

This document describes the dual-cloudspace HA architecture for the Matchpoint runners infrastructure.

## Overview

The HA architecture provides redundancy by running two Rackspace Spot cloudspaces in different regions:

- **Primary**: `matchpoint-runners` in `us-central-dfw-1` (Dallas)
- **Secondary**: `matchpoint-runners-2` in `us-central-ord-1` (Chicago)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     GitHub Actions                                   │
│                         │                                            │
│                         ▼                                            │
│              ┌──────────────────┐                                    │
│              │  Runner Labels   │                                    │
│              │  project-beta-   │                                    │
│              │    runners       │                                    │
│              └────────┬─────────┘                                    │
│                       │                                              │
│           ┌───────────┴───────────┐                                  │
│           ▼                       ▼                                  │
│  ┌─────────────────┐     ┌─────────────────┐                        │
│  │    Primary      │     │   Secondary     │                        │
│  │   Cloudspace    │     │   Cloudspace    │                        │
│  │  (DFW Region)   │     │  (ORD Region)   │                        │
│  │                 │     │                 │                        │
│  │ ┌─────────────┐ │     │ ┌─────────────┐ │                        │
│  │ │  Nodepool   │ │     │ │  Nodepool   │ │                        │
│  │ │  4-25 nodes │ │     │ │  4-25 nodes │ │                        │
│  │ └─────────────┘ │     │ └─────────────┘ │                        │
│  └─────────────────┘     └─────────────────┘                        │
│                                                                      │
│  ◄─────────── HA Gate: Both must be Ready ──────────►              │
└─────────────────────────────────────────────────────────────────────┘
```

## Configuration

### Enabling HA Mode

Edit `infrastructure/live/env-vars/prod.hcl`:

```hcl
locals {
  enable_ha = true  # Enable dual cloudspace HA

  # Primary cloudspace (existing)
  cluster_name = "matchpoint-runners"
  region       = "us-central-dfw-1"

  # Secondary cloudspace
  secondary_cluster_name = "matchpoint-runners-2"
  secondary_region       = "us-central-ord-1"
}
```

### Provisioning Timeline

When enabling HA mode:

1. **Secondary cloudspace creation**: ~50-60 minutes
2. **Secondary nodepool provisioning**: ~5-15 minutes
3. **HA gate verification**: ~1 minute

Total: ~60-75 minutes for full HA activation.

## HA Gate Behavior

The HA provisioning gate ensures:

1. **Primary cloudspace** is Ready/Fulfilled
2. **Primary nodepool** is Ready/Fulfilled
3. **Secondary cloudspace** is Ready/Fulfilled
4. **Secondary nodepool** is Ready/Fulfilled

If any component fails, the HA gate blocks and downstream operations are prevented.

## Node Balancing

When HA is enabled, nodes are balanced across both cloudspaces:

```
effective_nodes_per_cloudspace = min(
    available_nodes(primary_cloudspace),
    available_nodes(secondary_cloudspace)
)
```

Both cloudspaces are configured with the same:
- `min_nodes` and `max_nodes`
- `server_class` (node size)
- `bid_price` (spot pricing)

## Status Outputs

After applying, check HA status:

```bash
terragrunt output -json ha_status
```

Returns:
```json
{
  "enabled": true,
  "primary": {
    "cloudspace_name": "matchpoint-runners",
    "region": "us-central-dfw-1",
    "nodepool_name": "matchpoint-runners-nodepool"
  },
  "secondary": {
    "cloudspace_name": "matchpoint-runners-2",
    "region": "us-central-ord-1",
    "nodepool_name": "matchpoint-runners-2-nodepool"
  },
  "gate_passed": true
}
```

## Failure Scenarios

### Primary Cloudspace Failure

1. Secondary cloudspace continues serving runners
2. GitHub Actions routes to available runners
3. Alert on primary cloudspace degraded status

### Secondary Cloudspace Failure

1. Primary cloudspace continues serving runners
2. HA gate blocks new deployments until secondary recovers
3. Alert on secondary cloudspace degraded status

### Both Cloudspaces Fail

1. No runners available
2. GitHub Actions jobs queue until recovery
3. Critical alert triggered

## Runbook: Enabling HA

### Prerequisites

- [ ] Verify primary cloudspace is healthy
- [ ] Ensure sufficient Rackspace Spot quota for secondary region
- [ ] Allocate ~75 minutes for provisioning

### Steps

1. **Update configuration**:
   ```bash
   # Edit prod.hcl
   enable_ha = true
   ```

2. **Apply changes**:
   ```bash
   cd infrastructure/live/prod/1-cloudspace
   terragrunt apply
   ```

3. **Monitor provisioning**:
   - Watch GitHub Actions workflow for progress
   - Check spotctl for cloudspace status:
     ```bash
     spotctl cloudspaces list
     spotctl nodepools spot list
     ```

4. **Verify HA activation**:
   ```bash
   terragrunt output ha_status
   ```

### Rollback

To disable HA and remove secondary cloudspace:

1. Set `enable_ha = false` in prod.hcl
2. Run `terragrunt apply`
3. Note: Secondary cloudspace has `prevent_destroy = true`
   - Manual deletion via spotctl required:
     ```bash
     spotctl cloudspaces delete --name matchpoint-runners-2
     ```

## Monitoring

### Key Metrics

| Metric | Alert Threshold |
|--------|-----------------|
| Primary cloudspace status | != Ready |
| Secondary cloudspace status | != Ready |
| Primary node count | < min_nodes |
| Secondary node count | < min_nodes |
| HA gate status | Failed |

### Logs

Check Cloud Run logs for provisioning status:
```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=runners-deploy"
```

## Related Issues

- Issue #121: Implement High Availability across dual cloudspaces
- Issue #117: Dual cloudspace architecture planning
