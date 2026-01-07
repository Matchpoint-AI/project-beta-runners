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
# Setup spotctl config (sensitive - output suppressed is OK)
# -----------------------------------------------------------------------------
# This resource writes the spotctl config file with the sensitive token.
# Output suppression is expected here since it handles sensitive data.
resource "terraform_data" "setup_spotctl_config" {
  triggers_replace = [spot_cloudspace.this.id]

  provisioner "local-exec" {
    command = <<-EOT
      # Configure spotctl (sensitive operation)
      mkdir -p ~/.spot
      cat > ~/.spot_config << EOF
      org: "${var.rackspace_org}"
      refreshToken: "$RACKSPACE_SPOT_TOKEN"
      region: "${var.region}"
      EOF
      chmod 600 ~/.spot_config
      
      # Install spotctl if not available
      if ! command -v spotctl &> /dev/null; then
        curl -sL "https://github.com/rackspace-spot/spotctl/releases/download/v0.1.1/spotctl-linux-amd64" -o /tmp/spotctl
        chmod +x /tmp/spotctl
      fi
    EOT

    environment = {
      RACKSPACE_SPOT_TOKEN = var.rackspace_spot_token
    }
  }

  depends_on = [spot_spotnodepool.this]
}

# -----------------------------------------------------------------------------
# Wait for Cluster to be Ready (NO sensitive vars - output VISIBLE)
# -----------------------------------------------------------------------------
# This resource polls for cluster status using spotctl.
# Since it doesn't reference sensitive variables, output will be visible in logs.
resource "terraform_data" "wait_for_cluster" {
  triggers_replace = [terraform_data.setup_spotctl_config.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      CLUSTER_NAME="${var.cluster_name}"
      MAX_ATTEMPTS=240
      SLEEP_INTERVAL=30
      
      echo ""
      echo "=============================================="
      echo "  CLOUDSPACE STATUS MONITOR"
      echo "=============================================="
      echo "Cluster: $CLUSTER_NAME"
      echo "Max wait: $((MAX_ATTEMPTS * SLEEP_INTERVAL / 60)) minutes"
      echo "=============================================="
      echo ""
      
      # Use spotctl from PATH or /tmp
      if command -v spotctl &> /dev/null; then
        SPOTCTL="spotctl"
      else
        SPOTCTL="/tmp/spotctl"
      fi
      
      for i in $(seq 1 $MAX_ATTEMPTS); do
        ELAPSED=$((i * SLEEP_INTERVAL / 60))
        
        # Get cloudspace status using spotctl
        if STATUS_JSON=$($SPOTCTL cloudspaces get --name "$CLUSTER_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')
          PHASE=$(echo "$STATUS_JSON" | jq -r '.phase // ""')
          
          # Debug: show raw status on first iteration
          if [ "$i" -eq 1 ]; then
            echo "Raw status from API: $STATUS"
            echo "Raw JSON (truncated):"
            echo "$STATUS_JSON" | jq -c '.' | head -c 500
            echo ""
          fi
          
          case "$STATUS" in
            # Rackspace API returns "Ready" for healthy clusters (UI shows "Healthy")
            "Ready"|"Healthy"|"Running"|"Active")
              echo ""
              echo "=============================================="
              echo "✅ CLOUDSPACE READY!"
              echo "=============================================="
              echo "Cluster: $CLUSTER_NAME"
              echo "Status:  $STATUS"
              echo "Elapsed: $${ELAPSED} minutes"
              echo "=============================================="
              
              # Verify kubeconfig is accessible using spotctl
              echo "Fetching kubeconfig via spotctl..."
              if $SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME" --file /tmp/kubeconfig-test 2>&1; then
                if [ -s /tmp/kubeconfig-test ]; then
                  echo "✅ Kubeconfig retrieved successfully"
                  echo "   Size: $(wc -c < /tmp/kubeconfig-test) bytes"
                  # Verify it's valid YAML with server endpoint
                  if grep -q "server:" /tmp/kubeconfig-test; then
                    echo "✅ Kubeconfig contains server endpoint"
                    rm -f /tmp/kubeconfig-test
                    exit 0
                  else
                    echo "⚠️  Kubeconfig missing server endpoint, waiting..."
                  fi
                else
                  echo "⚠️  Kubeconfig file is empty, waiting..."
                fi
              else
                echo "⚠️  spotctl get-config failed, waiting..."
              fi
              rm -f /tmp/kubeconfig-test 2>/dev/null
              ;;
            "Provisioning"|"Creating"|"Pending")
              printf "\r[%3d/%d] %-15s | Elapsed: %3dm | Phase: %s" "$i" "$MAX_ATTEMPTS" "$STATUS" "$ELAPSED" "$PHASE"
              ;;
            "Failed"|"Error"|"Degraded")
              echo ""
              echo "=============================================="
              echo "❌ CLOUDSPACE FAILED"
              echo "=============================================="
              echo "Cluster: $CLUSTER_NAME"
              echo "Status:  $STATUS"
              echo ""
              echo "Full status:"
              echo "$STATUS_JSON" | jq '.' 2>/dev/null || echo "$STATUS_JSON"
              echo ""
              echo "Recovery: spotctl cloudspaces delete --name $CLUSTER_NAME"
              echo "=============================================="
              exit 1
              ;;
            *)
              # Show unknown status for debugging
              printf "\r[%3d/%d] %-15s | Elapsed: %3dm (unknown status)" "$i" "$MAX_ATTEMPTS" "$STATUS" "$ELAPSED"
              ;;
          esac
        else
          printf "\r[%3d/%d] %-15s | Elapsed: %3dm" "$i" "$MAX_ATTEMPTS" "Initializing..." "$ELAPSED"
        fi
        
        sleep $SLEEP_INTERVAL
      done
      
      echo ""
      echo "=============================================="
      echo "❌ TIMEOUT"
      echo "=============================================="
      echo "Cluster did not become ready in $((MAX_ATTEMPTS * SLEEP_INTERVAL / 60)) minutes"
      echo ""
      echo "Check manually: spotctl cloudspaces get --name $CLUSTER_NAME"
      echo "=============================================="
      exit 1
    EOT
  }

  depends_on = [terraform_data.setup_spotctl_config]
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
