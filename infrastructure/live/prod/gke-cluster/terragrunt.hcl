# GKE Cluster + Spot Node Pool
#
# Stage 1 of GKE migration. Creates the cluster, node pool, deployer SA, and WIF binding.
# Operator applies manually after PR lands.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  gke_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/env-vars/gke-prod.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../modules//gke-cluster"
}

inputs = {
  project_id     = local.gke_vars.locals.project_id
  cluster_name   = local.gke_vars.locals.cluster_name
  zone           = local.gke_vars.locals.zone
  machine_type   = local.gke_vars.locals.machine_type
  disk_size_gb   = local.gke_vars.locals.disk_size_gb
  min_node_count = local.gke_vars.locals.min_node_count
  max_node_count = local.gke_vars.locals.max_node_count
  wif_pool_name  = local.gke_vars.locals.wif_pool_name
  github_repo    = local.gke_vars.locals.github_repo
}
