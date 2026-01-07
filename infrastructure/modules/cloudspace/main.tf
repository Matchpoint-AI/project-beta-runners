# Cloudspace Module
#
# Creates Rackspace Spot managed Kubernetes cluster and node pool.
# Control plane provisioning typically takes 50-60 minutes, but can take up to 120 minutes.

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

  # Rackspace Spot only allows updating Webhook and KubernetesVersion fields.
  # Ignore changes to other fields to prevent update errors.
  lifecycle {
    ignore_changes = [wait_until_ready]
  }
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
# Wait for Cluster to be Ready (using spotctl for status visibility)
# -----------------------------------------------------------------------------
# The spot_cloudspace.wait_until_ready may timeout before cluster is fully ready.
# This resource uses spotctl to poll with actual status visibility.
resource "terraform_data" "wait_for_cluster" {
  triggers_replace = [spot_cloudspace.this.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      CLUSTER_NAME="${var.cluster_name}"
      ORG="${var.rackspace_org}"
      MAX_ATTEMPTS=240
      SLEEP_INTERVAL=30
      
      echo "=============================================="
      echo "Waiting for cloudspace $CLUSTER_NAME to be ready"
      echo "Organization: $ORG"
      echo "Max wait time: $((MAX_ATTEMPTS * SLEEP_INTERVAL / 60)) minutes"
      echo "=============================================="
      
      # Configure spotctl
      cat > ~/.spot_config << EOF
      org: "$ORG"
      refreshToken: "$RACKSPACE_SPOT_TOKEN"
      region: "${var.region}"
      EOF
      chmod 600 ~/.spot_config
      
      # Check if spotctl is available, fall back to curl if not
      if ! command -v spotctl &> /dev/null; then
        echo "spotctl not found, installing..."
        curl -sL "https://github.com/rackspace-spot/spotctl/releases/download/v0.1.1/spotctl-linux-amd64" -o /tmp/spotctl
        chmod +x /tmp/spotctl
        SPOTCTL="/tmp/spotctl"
      else
        SPOTCTL="spotctl"
      fi
      
      for i in $(seq 1 $MAX_ATTEMPTS); do
        # Get cloudspace status using spotctl (--name flag required)
        if STATUS_JSON=$($SPOTCTL cloudspaces get --name "$CLUSTER_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')
          
          case "$STATUS" in
            "Ready"|"Running"|"Active")
              echo ""
              echo "=============================================="
              echo "✅ Cloudspace $CLUSTER_NAME is READY!"
              echo "Status: $STATUS"
              echo "=============================================="
              
              # Verify kubeconfig is accessible
              if $SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME" --file /tmp/kubeconfig-test 2>/dev/null; then
                echo "✅ Kubeconfig verified accessible"
                rm -f /tmp/kubeconfig-test
                exit 0
              else
                echo "⚠️  Status is Ready but kubeconfig not yet accessible, continuing to wait..."
              fi
              ;;
            "Provisioning"|"Creating"|"Pending")
              ELAPSED=$((i * SLEEP_INTERVAL / 60))
              echo "[$i/$MAX_ATTEMPTS] Status: $STATUS (elapsed: ${ELAPSED}m)"
              ;;
            "Failed"|"Error"|"Degraded")
              echo ""
              echo "=============================================="
              echo "❌ Cloudspace $CLUSTER_NAME is in $STATUS state!"
              echo "Full status:"
              echo "$STATUS_JSON" | jq '.'
              echo ""
              echo "To recover, delete and recreate:"
              echo "  spotctl cloudspaces delete --name $CLUSTER_NAME"
              echo "=============================================="
              exit 1
              ;;
            *)
              echo "[$i/$MAX_ATTEMPTS] Unknown status: $STATUS"
              ;;
          esac
        else
          echo "[$i/$MAX_ATTEMPTS] Could not fetch status (cluster may still be initializing)"
        fi
        
        sleep $SLEEP_INTERVAL
      done
      
      echo ""
      echo "=============================================="
      echo "❌ TIMEOUT: Cloudspace did not become ready in $((MAX_ATTEMPTS * SLEEP_INTERVAL / 60)) minutes"
      echo "Last known status: $STATUS"
      echo ""
      echo "Check status manually:"
      echo "  spotctl cloudspaces get --name $CLUSTER_NAME --output json"
      echo "=============================================="
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
