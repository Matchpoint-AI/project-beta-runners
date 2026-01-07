# Cloudspace Module - Outputs

output "cloudspace_name" {
  description = "Name of the created Kubernetes cluster"
  value       = spot_cloudspace.this.cloudspace_name
}

output "region" {
  description = "Region where the cluster is deployed"
  value       = spot_cloudspace.this.region
}

output "nodepool_id" {
  description = "ID of the node pool"
  value       = spot_spotnodepool.this.id
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
