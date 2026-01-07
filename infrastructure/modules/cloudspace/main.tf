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
# IMPORTANT: Uses /tmp/.spot_config (absolute path) to ensure consistency
# across all terraform resources that use spotctl.
resource "terraform_data" "setup_spotctl_config" {
  triggers_replace = [spot_cloudspace.this.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      # Use absolute path to ensure all resources can find it
      CONFIG_PATH="/tmp/.spot_config"
      
      echo "Writing spotctl config to $CONFIG_PATH..."
      cat > "$CONFIG_PATH" << EOF
org: "${var.rackspace_org}"
refreshToken: "$RACKSPACE_SPOT_TOKEN"
region: "${var.region}"
EOF
      chmod 600 "$CONFIG_PATH"
      
      # Also write to ~/.spot_config as backup
      cat > ~/.spot_config << EOF
org: "${var.rackspace_org}"
refreshToken: "$RACKSPACE_SPOT_TOKEN"
region: "${var.region}"
EOF
      chmod 600 ~/.spot_config
      
      # Install spotctl if not available
      if ! command -v spotctl &> /dev/null; then
        echo "Installing spotctl..."
        curl -sL "https://github.com/rackspace-spot/spotctl/releases/download/v0.1.1/spotctl-linux-amd64" -o /tmp/spotctl
        chmod +x /tmp/spotctl
        echo "spotctl installed to /tmp/spotctl"
      fi
      
      # Verify config was written
      if [ -f "$CONFIG_PATH" ]; then
        echo "✅ Config written successfully ($(wc -c < "$CONFIG_PATH") bytes)"
      else
        echo "❌ Failed to write config"
        exit 1
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
# This resource polls for cluster status AND kubeconfig availability.
# It will NOT exit until kubeconfig is successfully retrieved.
resource "terraform_data" "wait_for_cluster" {
  triggers_replace = [terraform_data.setup_spotctl_config.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      CLUSTER_NAME="${var.cluster_name}"
      MAX_ATTEMPTS=240
      SLEEP_INTERVAL=30
      CONFIG_PATH="/tmp/.spot_config"
      
      echo ""
      echo "=============================================="
      echo "  CLOUDSPACE STATUS MONITOR"
      echo "=============================================="
      echo "Cluster: $CLUSTER_NAME"
      echo "Max wait: $((MAX_ATTEMPTS * SLEEP_INTERVAL / 60)) minutes"
      echo "=============================================="
      echo ""
      
      # CRITICAL: Verify config file exists
      echo "Checking spotctl config..."
      if [ ! -f "$CONFIG_PATH" ]; then
        echo "❌ ERROR: spotctl config not found at $CONFIG_PATH"
        echo "   Checking ~/.spot_config..."
        if [ -f ~/.spot_config ]; then
          echo "   Found at ~/.spot_config, copying to $CONFIG_PATH"
          cp ~/.spot_config "$CONFIG_PATH"
        else
          echo "❌ FATAL: No spotctl config found!"
          echo "   Expected: $CONFIG_PATH or ~/.spot_config"
          exit 1
        fi
      fi
      echo "✅ Config found at $CONFIG_PATH"
      
      # Show config (without token) for debugging
      echo "Config contents (token redacted):"
      sed 's/refreshToken:.*/refreshToken: [REDACTED]/' "$CONFIG_PATH"
      echo ""
      
      # Use spotctl from PATH or /tmp
      if command -v spotctl &> /dev/null; then
        SPOTCTL="spotctl"
      else
        SPOTCTL="/tmp/spotctl"
      fi
      
      # Verify spotctl works
      echo "Testing spotctl..."
      if ! $SPOTCTL --version; then
        echo "❌ spotctl not working!"
        exit 1
      fi
      echo ""
      
      for i in $(seq 1 $MAX_ATTEMPTS); do
        ELAPSED=$((i * SLEEP_INTERVAL / 60))
        
        # Get cloudspace status using spotctl
        echo "[Attempt $i/$MAX_ATTEMPTS] Checking status..."
        
        if STATUS_OUTPUT=$($SPOTCTL cloudspaces get --name "$CLUSTER_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_OUTPUT" | jq -r '.status // "Unknown"')
          PHASE=$(echo "$STATUS_OUTPUT" | jq -r '.phase // ""')
          
          echo "  Status: $STATUS"
          
          case "$STATUS" in
            "Ready"|"Healthy"|"Running"|"Active")
              echo ""
              echo "=============================================="
              echo "✅ CLOUDSPACE STATUS: $STATUS"
              echo "=============================================="
              
              # NOW verify kubeconfig is retrievable - DO NOT EXIT until this works
              echo "Fetching kubeconfig..."
              KUBECONFIG_OUTPUT=$($SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME" --file /tmp/kubeconfig-verify 2>&1) || true
              
              if [ -f /tmp/kubeconfig-verify ] && [ -s /tmp/kubeconfig-verify ]; then
                echo "✅ Kubeconfig retrieved ($(wc -c < /tmp/kubeconfig-verify) bytes)"
                
                if grep -q "server:" /tmp/kubeconfig-verify; then
                  SERVER=$(grep "server:" /tmp/kubeconfig-verify | head -1 | awk '{print $2}')
                  echo "✅ Server endpoint: $SERVER"
                  rm -f /tmp/kubeconfig-verify
                  echo ""
                  echo "=============================================="
                  echo "✅ CLUSTER READY - Kubeconfig verified!"
                  echo "=============================================="
                  exit 0
                else
                  echo "⚠️  Kubeconfig missing server endpoint"
                  cat /tmp/kubeconfig-verify | head -20
                fi
              else
                echo "⚠️  Kubeconfig retrieval failed or empty"
                echo "   Output: $KUBECONFIG_OUTPUT"
              fi
              
              rm -f /tmp/kubeconfig-verify 2>/dev/null
              echo "   Waiting for kubeconfig to become available..."
              ;;
              
            "Provisioning"|"Creating"|"Pending")
              echo "  Phase: $PHASE"
              echo "  Elapsed: $${ELAPSED}m"
              ;;
              
            "Failed"|"Error"|"Degraded")
              echo ""
              echo "=============================================="
              echo "❌ CLOUDSPACE FAILED: $STATUS"
              echo "=============================================="
              echo "$STATUS_OUTPUT" | jq '.' 2>/dev/null || echo "$STATUS_OUTPUT"
              echo ""
              echo "Recovery: spotctl cloudspaces delete --name $CLUSTER_NAME"
              exit 1
              ;;
              
            *)
              echo "  Unknown status, continuing..."
              ;;
          esac
        else
          echo "  Could not fetch status: $STATUS_OUTPUT"
        fi
        
        echo "  Sleeping ${SLEEP_INTERVAL}s..."
        echo ""
        sleep $SLEEP_INTERVAL
      done
      
      echo ""
      echo "=============================================="
      echo "❌ TIMEOUT after $((MAX_ATTEMPTS * SLEEP_INTERVAL / 60)) minutes"
      echo "=============================================="
      exit 1
    EOT
  }

  depends_on = [terraform_data.setup_spotctl_config]
}

# -----------------------------------------------------------------------------
# Dynamic Kubeconfig Fetch (fresh every apply via spotctl)
# -----------------------------------------------------------------------------
resource "terraform_data" "fetch_kubeconfig" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CLUSTER_NAME="${var.cluster_name}"
      KUBECONFIG_PATH="${path.module}/kubeconfig.yaml"
      CONFIG_PATH="/tmp/.spot_config"
      
      # Verify config exists
      if [ ! -f "$CONFIG_PATH" ] && [ ! -f ~/.spot_config ]; then
        echo "❌ No spotctl config found!"
        exit 1
      fi
      
      # Use spotctl from PATH or /tmp
      if command -v spotctl &> /dev/null; then
        SPOTCTL="spotctl"
      else
        SPOTCTL="/tmp/spotctl"
      fi
      
      echo "Fetching kubeconfig for $CLUSTER_NAME..."
      $SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME" --file "$KUBECONFIG_PATH"
      
      if [ -s "$KUBECONFIG_PATH" ]; then
        echo "✅ Kubeconfig saved to $KUBECONFIG_PATH ($(wc -c < "$KUBECONFIG_PATH") bytes)"
      else
        echo "❌ Failed to fetch kubeconfig"
        exit 1
      fi
    EOT
  }

  depends_on = [terraform_data.wait_for_cluster]
}

# Read the dynamically fetched kubeconfig
data "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig.yaml"
  
  depends_on = [terraform_data.fetch_kubeconfig]
}

locals {
  kubeconfig = yamldecode(data.local_file.kubeconfig.content)
}
