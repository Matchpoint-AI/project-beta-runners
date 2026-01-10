# Production environment configuration
#
# High Availability Cloudspace Architecture (Issue #121)
# ======================================================
# Two cloudspaces for high availability:
# - Primary: matchpoint-runners in us-central-dfw-1
# - Secondary: matchpoint-runners-2 in us-central-ord-1
#
# HA Mode Behavior:
# - When enable_ha=true, both cloudspaces must be healthy before HA is active
# - Node counts are balanced using min(primary_nodes, secondary_nodes)
# - Both cloudspaces share the same node pool configuration

locals {
  # -----------------------------------------------------------------------------
  # High Availability Configuration
  # -----------------------------------------------------------------------------
  # Set enable_ha=true to enable dual cloudspace HA mode
  # IMPORTANT: This will provision a secondary cloudspace (~50-60 min)
  enable_ha = false  # TODO: Set to true when ready for HA

  # -----------------------------------------------------------------------------
  # Primary Cloudspace
  # -----------------------------------------------------------------------------
  cluster_name = "matchpoint-runners"
  region       = "us-central-dfw-1"
  server_class = "gp.vs1.xlarge-dfw"  # 8 vCPU, 30GB RAM in DFW
  min_nodes    = 4
  max_nodes    = 25
  bid_price    = 0.35

  # -----------------------------------------------------------------------------
  # Secondary Cloudspace (HA Mode Only)
  # -----------------------------------------------------------------------------
  # Geographic redundancy in ORD region
  secondary_cluster_name  = "matchpoint-runners-2"
  secondary_region        = "us-central-ord-1"
  secondary_server_class  = ""  # Empty = same as primary (gp.vs1.xlarge-dfw)

  # -----------------------------------------------------------------------------
  # Runner settings (shared across all cloudspaces)
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
