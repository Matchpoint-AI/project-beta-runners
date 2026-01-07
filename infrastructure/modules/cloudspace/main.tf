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
# Spot Provider Configuration
# -----------------------------------------------------------------------------
provider "spot" {
  token = var.rackspace_spot_token
}

variable "rackspace_spot_token" {
  description = "Rackspace Spot API token"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Cloudspace (Kubernetes Cluster)
# -----------------------------------------------------------------------------
resource "spot_cloudspace" "this" {
  cloudspace_name = var.cluster_name
  region          = var.region

  # Note: wait_until_ready = true has a built-in timeout that's too short
  # for the 50-60 minute provisioning time. We use terraform_data.wait_for_cluster
  # below to ensure the cluster is fully ready before reading kubeconfig.
  wait_until_ready = false
}

# -----------------------------------------------------------------------------
# Node Pool
# -----------------------------------------------------------------------------
resource "spot_spotnodepool" "this" {
  cloudspace_name = spot_cloudspace.this.cloudspace_name
  server_class    = var.server_class
  bid_price       = var.bid_price

  # Autoscaling configuration
  autoscaling = {
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
  }

  depends_on = [spot_cloudspace.this]
}

# -----------------------------------------------------------------------------
# Wait for Cluster to be Ready
# -----------------------------------------------------------------------------
# The spot_cloudspace.wait_until_ready may timeout before cluster is fully ready.
# This resource polls the cluster status until it's no longer "Provisioning".
resource "terraform_data" "wait_for_cluster" {
  triggers_replace = [spot_cloudspace.this.id]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for cloudspace ${var.cluster_name} to be ready..."
      for i in $(seq 1 180); do
        # Check if kubeconfig is available (indicates cluster is ready)
        if curl -sf -H "Authorization: Bearer $RACKSPACE_SPOT_TOKEN" \
           "https://spot.rackspace.com/v1/cloudspaces/${var.cluster_name}/kubeconfig" > /dev/null 2>&1; then
          echo "Cloudspace ${var.cluster_name} is ready!"
          exit 0
        fi
        echo "Attempt $i/180: Cluster still provisioning, waiting 30s..."
        sleep 30
      done
      echo "ERROR: Timed out waiting for cloudspace to be ready after 90 minutes"
      exit 1
    EOT

    environment = {
      RACKSPACE_SPOT_TOKEN = var.rackspace_spot_token
    }
  }

  depends_on = [spot_spotnodepool.this]
}

# -----------------------------------------------------------------------------
# Kubeconfig Data Source
# -----------------------------------------------------------------------------
data "spot_kubeconfig" "this" {
  cloudspace_name = spot_cloudspace.this.cloudspace_name

  depends_on = [terraform_data.wait_for_cluster]
}

locals {
  kubeconfig = yamldecode(data.spot_kubeconfig.this.raw)
}
