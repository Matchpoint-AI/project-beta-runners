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

# Kubeconfig outputs for downstream modules
# Uses dynamically fetched kubeconfig via spotctl (fresh every apply)
output "kubeconfig_raw" {
  description = "Raw kubeconfig YAML (fetched fresh via spotctl)"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = local.kubeconfig["clusters"][0]["cluster"]["server"]
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = local.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"]
  sensitive   = true
}

output "cluster_token" {
  description = "Authentication token for the cluster"
  value       = local.kubeconfig["users"][0]["user"]["token"]
  sensitive   = true
}
