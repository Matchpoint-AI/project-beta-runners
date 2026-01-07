# Production environment configuration

locals {
  # Cluster settings
  cluster_name = "mp-runners-v3"
  region       = "us-central-dfw-1"
  
  # Node pool settings
  server_class = "gp.vs1.large"  # 4 vCPU, 15GB RAM
  min_nodes    = 2
  max_nodes    = 15
  
  # Runner settings
  runner_label = "project-beta-runners"
  min_runners  = 5
  max_runners  = 25
  
  # ArgoCD settings
  argocd_chart_version = "5.51.6"  # Maps to ArgoCD 2.10.x
  
  # ARC settings
  arc_version = "0.9.3"
  github_org  = "Matchpoint-AI"
}
