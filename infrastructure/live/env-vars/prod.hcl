# Production environment configuration
#
# Dual Cloudspace Architecture (Issue #117, #121)
# ===============================================
# Two cloudspaces for high availability and rolling maintenance:
# - Primary: Original cloudspace (keep running during secondary provisioning)
# - Secondary: New cloudspace (provision first, then rebalance primary)
#
# HA Mode (Issue #121):
# - Both cloudspaces must be provisioned and Ready before HA activates
# - Node count balanced using min(primary, secondary) formula
# - Total capacity: 24 max nodes split across both cloudspaces (12 each)

locals {
  # -----------------------------------------------------------------------------
  # High Availability Configuration (Issue #121)
  # -----------------------------------------------------------------------------
  # HA mode requires both cloudspaces to be provisioned and ready.
  # Set to false to disable HA coordination (single cloudspace mode).
  ha_enabled = true

  # -----------------------------------------------------------------------------
  # Primary Cloudspace (existing)
  # -----------------------------------------------------------------------------
  cluster_name = "matchpoint-runners"
  region       = "us-central-dfw-1"
  server_class = "gp.vs1.xlarge-dfw"  # 8 vCPU, 30GB RAM in DFW
  min_nodes    = 2
  max_nodes    = 12
  bid_price    = 0.35

  # -----------------------------------------------------------------------------
  # Secondary Cloudspace (Issue #117)
  # -----------------------------------------------------------------------------
  cluster_name_secondary = "matchpoint-runners-2"
  # Same region, server_class, min_nodes, max_nodes, bid_price as primary
  # This ensures balanced capacity across both cloudspaces

  # -----------------------------------------------------------------------------
  # Runner settings (shared across both cloudspaces)
  # -----------------------------------------------------------------------------
  runner_label = "project-beta-runners"
  min_runners  = 10
  max_runners  = 50

  # -----------------------------------------------------------------------------
  # ArgoCD settings
  # -----------------------------------------------------------------------------
  argocd_chart_version = "5.51.6"  # Maps to ArgoCD 2.10.x

  # -----------------------------------------------------------------------------
  # ARC settings
  # -----------------------------------------------------------------------------
  arc_version = "0.9.3"
  github_org  = "Matchpoint-AI"
}
