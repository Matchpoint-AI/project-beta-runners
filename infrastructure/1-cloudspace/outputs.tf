# State 1: Cloudspace - Outputs
#
# These outputs are consumed by State 2 (cluster-base) via dependency blocks.

output "cloudspace_name" {
  description = "Name of the created Kubernetes cluster"
  value       = rackspace-spot_cloudspace.runners.cloudspace_name
}

output "region" {
  description = "Region where the cluster is deployed"
  value       = rackspace-spot_cloudspace.runners.region
}

output "nodepool_name" {
  description = "Name of the node pool"
  value       = rackspace-spot_spotnodepool.runners.id
}

output "server_class" {
  description = "Server class of the node pool"
  value       = var.server_class
}

output "node_scaling" {
  description = "Node pool scaling configuration"
  value = {
    min = var.min_nodes
    max = var.max_nodes
  }
}
