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
  wait_until_ready = false

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

  autoscaling = {
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
  }

  depends_on = [spot_cloudspace.this]
}

# -----------------------------------------------------------------------------
# Setup spotctl config
# -----------------------------------------------------------------------------
resource "terraform_data" "setup_spotctl_config" {
  triggers_replace = [spot_cloudspace.this.id]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.spot
      printf 'org: "%s"\nrefreshToken: "%s"\nregion: "%s"\n' "${var.rackspace_org}" "$RACKSPACE_SPOT_TOKEN" "${var.region}" > ~/.spot_config
      chmod 600 ~/.spot_config
      
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
# Wait for Cluster to be Ready
# -----------------------------------------------------------------------------
resource "terraform_data" "wait_for_cluster" {
  triggers_replace = [terraform_data.setup_spotctl_config.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CLUSTER_NAME="${var.cluster_name}"
      MAX_ATTEMPTS=240
      SLEEP_INTERVAL=30
      
      echo "Waiting for cloudspace $CLUSTER_NAME (max $((MAX_ATTEMPTS * SLEEP_INTERVAL / 60)) min)..."
      
      SPOTCTL=$(command -v spotctl || echo "/tmp/spotctl")
      
      for i in $(seq 1 $MAX_ATTEMPTS); do
        ELAPSED=$((i * SLEEP_INTERVAL / 60))
        
        if STATUS_JSON=$($SPOTCTL cloudspaces get --name "$CLUSTER_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')
          
          case "$STATUS" in
            "Ready"|"Healthy"|"Running"|"Active")
              echo "✅ Cloudspace ready! Verifying kubeconfig..."
              if $SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME" --file /tmp/kubeconfig-test 2>&1; then
                if [ -s /tmp/kubeconfig-test ] && grep -q "server:" /tmp/kubeconfig-test; then
                  echo "✅ Kubeconfig verified"
                  rm -f /tmp/kubeconfig-test
                  exit 0
                fi
              fi
              echo "⚠️ Kubeconfig not ready yet..."
              ;;
            "Provisioning"|"Creating"|"Pending")
              printf "\r[%3d/%d] %s | %dm elapsed" "$i" "$MAX_ATTEMPTS" "$STATUS" "$ELAPSED"
              ;;
            "Failed"|"Error"|"Degraded")
              echo "❌ Cloudspace failed: $STATUS"
              exit 1
              ;;
          esac
        else
          printf "\r[%3d/%d] Initializing... | %dm elapsed" "$i" "$MAX_ATTEMPTS" "$ELAPSED"
        fi
        
        sleep $SLEEP_INTERVAL
      done
      
      echo "❌ Timeout waiting for cloudspace"
      exit 1
    EOT
  }

  depends_on = [terraform_data.setup_spotctl_config]
}

# -----------------------------------------------------------------------------
# Dynamic Kubeconfig Fetch
# -----------------------------------------------------------------------------
resource "terraform_data" "fetch_kubeconfig" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CLUSTER_NAME="${var.cluster_name}"
      KUBECONFIG_PATH="${path.module}/kubeconfig.yaml"
      SPOTCTL=$(command -v spotctl || echo "/tmp/spotctl")
      
      echo "Fetching kubeconfig for $CLUSTER_NAME..."
      $SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME" --file "$KUBECONFIG_PATH"
      
      if [ -s "$KUBECONFIG_PATH" ]; then
        echo "✅ Kubeconfig saved ($(wc -c < "$KUBECONFIG_PATH") bytes)"
      else
        echo "❌ Failed to fetch kubeconfig"
        exit 1
      fi
    EOT
  }

  depends_on = [terraform_data.wait_for_cluster]
}

data "local_file" "kubeconfig" {
  filename   = "${path.module}/kubeconfig.yaml"
  depends_on = [terraform_data.fetch_kubeconfig]
}

locals {
  kubeconfig = yamldecode(data.local_file.kubeconfig.content)
}
