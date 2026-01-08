# Production environment configuration
#
# Dual Cloudspace Architecture (Issue #117)
# =========================================
# Two cloudspaces for high availability and rolling maintenance:
# - Primary: Original cloudspace (keep running during secondary provisioning)
# - Secondary: New cloudspace (provision first, then rebalance primary)
#
# Total capacity unchanged: 25 max nodes split across both cloudspaces

locals {
  # -----------------------------------------------------------------------------
  # Primary Cloudspace (existing)
  # -----------------------------------------------------------------------------
  # WARNING: Do not modify until secondary is fully provisioned!
  # After secondary is Ready, reduce to: min_nodes=2, max_nodes=13
  cluster_name = "matchpoint-runners"
  region       = "us-central-dfw-1"
  server_class = "gp.vs1.xlarge-dfw"  # 8 vCPU, 30GB RAM in DFW
  min_nodes    = 4   # TODO: Reduce to 2 after secondary is Ready
  max_nodes    = 25  # TODO: Reduce to 13 after secondary is Ready
  bid_price    = 0.35

  # -----------------------------------------------------------------------------
  # Secondary Cloudspace (new - Issue #117)
  # -----------------------------------------------------------------------------
  # Phase 2: Create with half resources (purely additive, safe to deploy)
  cluster_name_secondary = "matchpoint-runners-2"
  min_nodes_secondary    = 2
  max_nodes_secondary    = 12
  # Same region, server_class, bid_price as primary

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
