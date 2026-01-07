# State 1: Cloudspace
#
# Creates Rackspace Spot managed Kubernetes cluster and node pool.
# Control plane provisioning takes 50-60 minutes.

# -----------------------------------------------------------------------------
# Cloudspace (Kubernetes Cluster)
# -----------------------------------------------------------------------------
resource "rackspace-spot_cloudspace" "runners" {
  cloudspace_name = var.cluster_name
  region          = var.region
  
  # Wait for the cluster to be ready before considering this resource complete
  wait_until_ready = true
  
  lifecycle {
    # Prevent accidental destruction - this takes 50+ min to recreate
    prevent_destroy = false  # Set to true in production
  }
}

# -----------------------------------------------------------------------------
# Node Pool
# -----------------------------------------------------------------------------
resource "rackspace-spot_spotnodepool" "runners" {
  cloudspace_name = rackspace-spot_cloudspace.runners.cloudspace_name
  server_class    = var.server_class
  
  # Autoscaling configuration
  bid_price        = 0.0  # On-demand pricing (no spot bidding)
  autoscaling      = true
  min_nodes        = var.min_nodes
  max_nodes        = var.max_nodes
  
  # Wait for nodepool to be ready
  wait_until_ready = true
  
  depends_on = [rackspace-spot_cloudspace.runners]
}
