# Cloudspace Module
#
# Creates Rackspace Spot managed Kubernetes cluster and node pool.
# Control plane provisioning takes 50-60 minutes.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = ">= 0.1.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Cloudspace (Kubernetes Cluster)
# -----------------------------------------------------------------------------
resource "spot_cloudspace" "this" {
  cloudspace_name = var.cluster_name
  region          = var.region

  # Wait for the cluster to be ready before considering this resource complete
  wait_until_ready = true
}

# -----------------------------------------------------------------------------
# Node Pool
# -----------------------------------------------------------------------------
resource "spot_spotnodepool" "this" {
  cloudspace_name = spot_cloudspace.this.cloudspace_name
  server_class    = var.server_class

  # Autoscaling configuration
  bid_price   = 0.0 # On-demand pricing (no spot bidding)
  autoscaling = true
  min_nodes   = var.min_nodes
  max_nodes   = var.max_nodes

  # Wait for nodepool to be ready
  wait_until_ready = true

  depends_on = [spot_cloudspace.this]
}
