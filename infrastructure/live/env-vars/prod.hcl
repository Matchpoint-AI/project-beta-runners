# Production environment configuration

locals {
  # Cluster settings
  cluster_name = "matchpoint-runners"
  region       = "us-central-dfw-1"

  # Node pool settings
  # xlarge for better efficiency: 2 runners per node vs 1
  # WARNING: Changing server_class forces nodepool replacement (5-10 min outage)
  server_class = "gp.vs1.xlarge-dfw"  # 8 vCPU, 30GB RAM in DFW
  min_nodes    = 4
  max_nodes    = 25

  # Bidding strategy (Issue #114)
  # Target: 70-75% of on-demand equivalent for reliability
  # xlarge on-demand equivalent: ~$0.48/hr
  # Bid: $0.35/hr = 73% of baseline, ~27% savings
  bid_price    = 0.35

  # Runner settings
  runner_label = "project-beta-runners"
  min_runners  = 10
  max_runners  = 50

  # ArgoCD settings
  argocd_chart_version = "5.51.6"  # Maps to ArgoCD 2.10.x

  # ARC settings
  arc_version = "0.9.3"
  github_org  = "Matchpoint-AI"
}
