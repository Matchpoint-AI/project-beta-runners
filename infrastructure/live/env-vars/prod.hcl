# Production environment configuration

locals {
  # Cluster settings
  cluster_name = "matchpoint-runners"
  region       = "us-central-dfw-1"
  
  # Node pool settings
  # Upgraded to xlarge for better efficiency: 2 runners per node vs 1
  server_class = "gp.vs1.xlarge-dfw"  # 8 vCPU, 30GB RAM in DFW
  min_nodes    = 4
  max_nodes    = 25
  
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
