# Production environment configuration
# 
# Included by child modules to get environment-specific values

locals {
  environment = "prod"
  
  # Cluster settings
  cluster_name = "mp-runners-v3"
  region       = "us-central-dfw-1"
  
  # Node pool settings
  server_class = "gp.vs1.large"  # 4 vCPU, 15GB RAM
  min_nodes    = 2
  max_nodes    = 15
  
  # Runner settings
  runner_label  = "project-beta-runners"
  min_runners   = 5
  max_runners   = 25
  
  # ArgoCD settings
  argocd_version = "2.10.x"
}
