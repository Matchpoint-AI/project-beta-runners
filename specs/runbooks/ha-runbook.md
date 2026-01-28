# High Availability Operations Runbook

This runbook provides step-by-step procedures for operating and troubleshooting the HA runner infrastructure.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Checking HA Status](#checking-ha-status)
3. [Failure Recovery](#failure-recovery)
4. [Scaling Operations](#scaling-operations)
5. [Maintenance Procedures](#maintenance-procedures)
6. [Troubleshooting](#troubleshooting)

---

## Daily Operations

### Morning Health Check

```bash
# 1. Check HA status
cd infrastructure/live/prod/3-ha-coordinator
terragrunt output ha_summary

# 2. Verify both cloudspaces are healthy
terragrunt output cloudspaces

# 3. Check node counts are balanced
terragrunt output node_balance_details
```

**Expected healthy output:**
```json
{
  "ha_active": true,
  "ha_status": "ACTIVE",
  "total_effective_nodes": 20
}
```

### Monitoring Dashboard Checks

1. Verify `ha_status == "ACTIVE"` in monitoring
2. Check capacity utilization < 80%
3. Verify runner pods are running in both cloudspaces

---

## Checking HA Status

### Quick Status Check

```bash
cd infrastructure/live/prod/3-ha-coordinator
terragrunt output ha_status
```

### Detailed Status Check

```bash
# Full HA summary with all metrics
terragrunt output -json ha_summary | jq .

# Check individual cloudspace health
terragrunt output -json cloudspaces | jq .
```

### Status Codes Reference

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| `ACTIVE` | Both cloudspaces healthy | None |
| `BLOCKED_PRIMARY_UNAVAILABLE` | Primary cloudspace down | See Recovery |
| `BLOCKED_SECONDARY_UNAVAILABLE` | Secondary cloudspace down | See Recovery |
| `BLOCKED_BOTH_UNAVAILABLE` | Both cloudspaces down | CRITICAL - See Recovery |
| `DISABLED` | HA manually disabled | Check configuration |

---

## Failure Recovery

### Scenario: Secondary Cloudspace Down

**Symptoms:**
- `ha_status = "BLOCKED_SECONDARY_UNAVAILABLE"`
- Workflows running slower (reduced capacity)

**Recovery Steps:**

1. **Assess the situation:**
   ```bash
   cd infrastructure/live/prod/1-cloudspace-secondary
   terragrunt output cloudspace_ready
   terragrunt output cloudspace_status
   ```

2. **Check Rackspace Spot console:**
   - Log into Rackspace Spot portal
   - Check cloudspace status and error messages
   - Review node pool health

3. **If cloudspace is degraded, attempt refresh:**
   ```bash
   terragrunt apply -refresh-only
   ```

4. **If cloudspace is destroyed, re-provision:**
   ```bash
   terragrunt apply
   # Note: This takes 50-60 minutes
   ```

5. **Verify recovery:**
   ```bash
   cd ../3-ha-coordinator
   terragrunt output ha_status
   # Should return "ACTIVE"
   ```

### Scenario: Primary Cloudspace Down

**Symptoms:**
- `ha_status = "BLOCKED_PRIMARY_UNAVAILABLE"`
- May have complete outage if secondary not fully configured

**Recovery Steps:**

1. **CRITICAL: Check if secondary can serve workloads:**
   ```bash
   kubectl --context=matchpoint-runners-2 get pods -n arc-runners
   ```

2. **Follow same steps as secondary recovery** (above)

3. **If both cloudspaces affected, escalate immediately**

### Scenario: Both Cloudspaces Down

**CRITICAL INCIDENT**

1. **Declare incident** - This is a P0
2. **Notify stakeholders** - All CI/CD is blocked
3. **Check Rackspace Spot status page** for outages
4. **Attempt parallel recovery:**
   ```bash
   # Terminal 1
   cd infrastructure/live/prod/1-cloudspace
   terragrunt apply

   # Terminal 2
   cd infrastructure/live/prod/1-cloudspace-secondary
   terragrunt apply
   ```
5. **If Rackspace Spot is down**, wait for their resolution
6. **Post-incident review** required

---

## Scaling Operations

### Scale Up Nodes

To increase capacity in both cloudspaces:

1. **Edit node configuration:**
   ```bash
   vim infrastructure/live/env-vars/prod.hcl
   # Increase max_nodes value (e.g., 12 → 16)
   ```

2. **Apply to both cloudspaces:**
   ```bash
   cd infrastructure/live/prod
   terragrunt run-all apply --terragrunt-include-dir 1-cloudspace --terragrunt-include-dir 1-cloudspace-secondary
   ```

3. **Verify balanced scaling:**
   ```bash
   cd 3-ha-coordinator
   terragrunt output node_balance_details
   ```

### Scale Down Nodes

**CAUTION:** Scaling down may terminate active jobs.

1. **Check current workload:**
   ```bash
   kubectl get pods -n arc-runners --all-contexts
   ```

2. **Scale during low-activity window**

3. **Reduce max_nodes in prod.hcl**

4. **Apply changes**

---

## Maintenance Procedures

### Rolling Maintenance (Zero Downtime)

To update one cloudspace while the other serves traffic:

1. **Verify HA is active:**
   ```bash
   cd infrastructure/live/prod/3-ha-coordinator
   terragrunt output ha_active
   # Must be true
   ```

2. **Cordon primary cloudspace:**
   ```bash
   # Mark primary as unschedulable (runners will finish current jobs)
   kubectl --context=matchpoint-runners cordon --all
   ```

3. **Wait for jobs to drain:**
   ```bash
   # Watch until no jobs running on primary
   kubectl --context=matchpoint-runners get pods -n arc-runners -w
   ```

4. **Perform maintenance on primary:**
   ```bash
   cd infrastructure/live/prod/1-cloudspace
   terragrunt apply
   # Wait for completion
   ```

5. **Uncordon primary:**
   ```bash
   kubectl --context=matchpoint-runners uncordon --all
   ```

6. **Verify primary healthy:**
   ```bash
   cd ../3-ha-coordinator
   terragrunt output cloudspaces | jq .primary
   ```

7. **Repeat for secondary** (steps 2-6 with secondary context)

### Emergency Maintenance

If urgent maintenance is needed without zero-downtime:

1. **Notify users** of expected outage window
2. **Apply changes directly** without draining
3. **Monitor recovery**

---

## Troubleshooting

### Problem: Node Count Imbalanced

**Symptom:** `node_balance_details.nodes_constrained = true`

**Cause:** One cloudspace has fewer nodes than the other.

**Resolution:**
1. Check which side is constraining:
   ```bash
   terragrunt output node_balance_details | jq .constraining_side
   ```
2. Investigate why that cloudspace has fewer nodes:
   - Spot instance availability?
   - Provisioning failure?
   - Manual scaling?
3. Address root cause or adjust configuration

### Problem: HA Stuck in BLOCKED State

**Symptom:** HA status not transitioning to ACTIVE

**Diagnosis:**
```bash
# Check cloudspace outputs directly
cd infrastructure/live/prod/1-cloudspace
terragrunt output cloudspace_ready

cd ../1-cloudspace-secondary
terragrunt output cloudspace_ready
```

**Common Causes:**
- Cloudspace provisioning still in progress (wait 50-60 min)
- Rackspace Spot API issues
- Terraform state drift

**Resolution:**
```bash
# Refresh state
terragrunt apply -refresh-only

# If state is corrupted, import resources
terragrunt import ...
```

### Problem: Capacity Utilization Too High

**Symptom:** `capacity_utilization > 90%`

**Impact:** Jobs may queue during peak times

**Resolution:**
1. Scale up max_nodes in prod.hcl
2. Consider adding a third cloudspace for additional capacity
3. Review workflow efficiency (are jobs taking too long?)

---

## Contact and Escalation

| Severity | Response Time | Contact |
|----------|---------------|---------|
| P0 (Both cloudspaces down) | Immediate | On-call + management |
| P1 (One cloudspace down) | 30 minutes | On-call |
| P2 (Degraded performance) | 4 hours | Platform team |

---

## Appendix: Useful Commands

```bash
# HA Status
terragrunt output ha_summary

# Cloudspace health
terragrunt output cloudspaces

# Node balancing details
terragrunt output node_balance_details

# Check runner pods (both contexts)
kubectl get pods -n arc-runners --context=matchpoint-runners
kubectl get pods -n arc-runners --context=matchpoint-runners-2

# Check ArgoCD applications
kubectl get applications -n argocd --context=matchpoint-runners
kubectl get applications -n argocd --context=matchpoint-runners-2

# Refresh terraform state
terragrunt apply -refresh-only

# Force re-apply (use with caution)
terragrunt apply -replace=<resource>
```
