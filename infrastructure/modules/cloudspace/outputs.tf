# Cloudspace Module - Outputs

# -----------------------------------------------------------------------------
# Primary Cloudspace Outputs
# -----------------------------------------------------------------------------

output "cloudspace_name" {
  description = "Name of the primary Kubernetes cluster"
  value       = spot_cloudspace.primary.cloudspace_name
}

output "region" {
  description = "Region where the primary cluster is deployed"
  value       = spot_cloudspace.primary.region
}

output "nodepool_name" {
  description = "Name of the primary node pool"
  value       = spot_spotnodepool.primary.name
}

output "server_class" {
  description = "Server class of the primary node pool"
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
  description = "Raw kubeconfig YAML for primary cluster (fetched fresh via spotctl)"
  value       = local.kubeconfig_raw
  sensitive   = true
}

output "cloudspace_status" {
  description = "Current primary cloudspace status from spotctl"
  value       = data.external.kubeconfig.result.status
}

output "cluster_endpoint" {
  description = "Primary Kubernetes API server endpoint"
  value       = try(local.kubeconfig["clusters"][0]["cluster"]["server"], "")
}

output "cluster_ca_certificate" {
  description = "Base64-encoded primary cluster CA certificate"
  value       = try(local.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"], "")
  sensitive   = true
}

output "cluster_token" {
  description = "Authentication token for the primary cluster"
  value       = try(local.kubeconfig["users"][0]["user"]["token"], "")
  sensitive   = true
}

# -----------------------------------------------------------------------------
# High Availability Outputs
# -----------------------------------------------------------------------------

output "ha_enabled" {
  description = "Whether HA mode is enabled"
  value       = var.enable_ha
}

output "ha_status" {
  description = "HA status information including both cloudspaces"
  value = var.enable_ha ? {
    enabled = true
    primary = {
      cloudspace_name = spot_cloudspace.primary.cloudspace_name
      region          = spot_cloudspace.primary.region
      nodepool_name   = spot_spotnodepool.primary.name
    }
    secondary = {
      cloudspace_name = spot_cloudspace.secondary[0].cloudspace_name
      region          = spot_cloudspace.secondary[0].region
      nodepool_name   = spot_spotnodepool.secondary[0].name
    }
    gate_passed = terraform_data.ha_gate[0].id != ""
    } : {
    enabled     = false
    primary     = null
    secondary   = null
    gate_passed = false
  }
}

output "secondary_cloudspace_name" {
  description = "Name of the secondary Kubernetes cluster (HA mode only)"
  value       = var.enable_ha ? spot_cloudspace.secondary[0].cloudspace_name : ""
}

output "secondary_region" {
  description = "Region of the secondary cluster (HA mode only)"
  value       = var.enable_ha ? spot_cloudspace.secondary[0].region : ""
}

output "secondary_nodepool_name" {
  description = "Name of the secondary node pool (HA mode only)"
  value       = var.enable_ha ? spot_spotnodepool.secondary[0].name : ""
}

# Secondary kubeconfig (HA mode only)
output "secondary_kubeconfig_raw" {
  description = "Raw kubeconfig YAML for secondary cluster (HA mode only)"
  value       = var.enable_ha ? local.secondary_kubeconfig_raw : ""
  sensitive   = true
}

output "secondary_cluster_endpoint" {
  description = "Secondary Kubernetes API server endpoint (HA mode only)"
  value       = var.enable_ha ? try(local.secondary_kubeconfig["clusters"][0]["cluster"]["server"], "") : ""
}

output "secondary_cluster_ca_certificate" {
  description = "Base64-encoded secondary cluster CA certificate (HA mode only)"
  value       = var.enable_ha ? try(local.secondary_kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"], "") : ""
  sensitive   = true
}

output "secondary_cluster_token" {
  description = "Authentication token for the secondary cluster (HA mode only)"
  value       = var.enable_ha ? try(local.secondary_kubeconfig["users"][0]["user"]["token"], "") : ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Cloudspaces Map (for multi-cluster operations)
# -----------------------------------------------------------------------------

output "cloudspaces" {
  description = "Map of all cloudspaces for multi-cluster operations"
  value = var.enable_ha ? {
    primary = {
      name       = spot_cloudspace.primary.cloudspace_name
      region     = spot_cloudspace.primary.region
      endpoint   = try(local.kubeconfig["clusters"][0]["cluster"]["server"], "")
      kubeconfig = local.kubeconfig_raw
    }
    secondary = {
      name       = spot_cloudspace.secondary[0].cloudspace_name
      region     = spot_cloudspace.secondary[0].region
      endpoint   = try(local.secondary_kubeconfig["clusters"][0]["cluster"]["server"], "")
      kubeconfig = local.secondary_kubeconfig_raw
    }
    } : {
    primary = {
      name       = spot_cloudspace.primary.cloudspace_name
      region     = spot_cloudspace.primary.region
      endpoint   = try(local.kubeconfig["clusters"][0]["cluster"]["server"], "")
      kubeconfig = local.kubeconfig_raw
    }
  }
  sensitive = true
}
