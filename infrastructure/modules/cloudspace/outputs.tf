# Cloudspace Module - Outputs

output "cloudspace_name" {
  description = "Name of the created Kubernetes cluster"
  value       = spot_cloudspace.this.cloudspace_name
}

output "region" {
  description = "Region where the cluster is deployed"
  value       = spot_cloudspace.this.region
}

output "nodepool_name" {
  description = "Name of the node pool"
  value       = spot_spotnodepool.this.name
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
# Uses dynamically fetched kubeconfig via spotctl external data source
output "kubeconfig_raw" {
  description = "Raw kubeconfig YAML (fetched fresh via spotctl)"
  value       = local.kubeconfig_raw
  sensitive   = true
}

output "cloudspace_status" {
  description = "Current cloudspace status from spotctl"
  value       = data.external.kubeconfig.result.status
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = try(local.kubeconfig["clusters"][0]["cluster"]["server"], "")
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = try(local.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"], "")
  sensitive   = true
}

output "cluster_token" {
  description = "Authentication token for the cluster"
  value       = try(local.kubeconfig["users"][0]["user"]["token"], "")
  sensitive   = true
}
