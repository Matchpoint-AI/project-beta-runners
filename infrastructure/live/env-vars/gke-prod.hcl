# GKE Production environment configuration
#
# Phase 1: GKE Spot cluster running alongside Rackspace.
# The gke-beta-runners label is new; arc-beta-runners stays on Rackspace until Phase 4.

locals {
  # GCP project
  project_id = "project-beta-407300"

  # GKE cluster
  cluster_name = "gke-runners-prod"
  zone         = "us-central1-a"

  # Node pool
  machine_type   = "e2-standard-4"
  disk_size_gb   = 50
  min_node_count = 0
  max_node_count = 25

  # WIF (existing pool in project-beta-407300)
  wif_pool_name = "projects/project-beta-407300/locations/global/workloadIdentityPools/github-actions-pool"
  github_repo   = "Matchpoint-AI/project-beta-runners"

  # ArgoCD
  argocd_chart_version = "5.51.6"
  repo_url             = "https://github.com/Matchpoint-AI/project-beta-runners"

  # ARC
  arc_version     = "0.13.1"
  runner_label    = "gke-beta-runners"
  min_runners     = 0
  max_runners     = 25
  github_config_url = "https://github.com/Matchpoint-AI/matchpoint"
}
