# Cloudspace Module
#
# Creates a Rackspace Spot managed Kubernetes cluster and node pool.
# Control plane provisioning typically takes 50-60 minutes for new clusters.
#
# ⚠️  WARNING: CLOUDSPACE RECREATION IS EXPENSIVE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Changing `cluster_name` destroys the cloudspace and creates a new one.
# This triggers a 50-60 minute wait for control plane provisioning.
# Only rename the cloudspace if absolutely necessary.
#
# Key behavior:
# - spotctl writes kubeconfig to ~/.kube/<cluster>.yaml (not configurable path)
# - We copy from there to the module directory for terraform to read

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
# Provider Configuration
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
# Primary Cloudspace (Kubernetes Cluster)
# -----------------------------------------------------------------------------
# ⚠️  Changing cloudspace_name triggers FULL RECREATION (50-60 min downtime)

resource "spot_cloudspace" "primary" {
  cloudspace_name  = var.cluster_name
  region           = var.region
  wait_until_ready = false

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [wait_until_ready]
  }
}

# -----------------------------------------------------------------------------
# Secondary Cloudspace (HA Mode Only)
# -----------------------------------------------------------------------------
# Only created when enable_ha=true. Provides redundancy in a different region.

resource "spot_cloudspace" "secondary" {
  count            = var.enable_ha ? 1 : 0
  cloudspace_name  = var.secondary_cluster_name
  region           = var.secondary_region
  wait_until_ready = false

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [wait_until_ready]

    precondition {
      condition     = var.secondary_cluster_name != ""
      error_message = "secondary_cluster_name is required when enable_ha is true."
    }

    precondition {
      condition     = var.secondary_region != ""
      error_message = "secondary_region is required when enable_ha is true."
    }
  }
}

# -----------------------------------------------------------------------------
# Primary Node Pool (REPLACEABLE)
# -----------------------------------------------------------------------------
# Unlike cloudspace, nodepool CAN be destroyed and recreated.
# Rackspace Spot only supports one nodepool per cloudspace, so replacement
# means delete-then-create (not create-before-destroy).
#
# ⚠️  server_class change = nodepool replacement (5-10 min outage)
# ✅  Safe to change in-place: bid_price, min_nodes, max_nodes

resource "spot_spotnodepool" "primary" {
  cloudspace_name = spot_cloudspace.primary.cloudspace_name
  server_class    = var.server_class
  bid_price       = var.bid_price

  autoscaling = {
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
  }

  # No prevent_destroy - nodepool replacement is acceptable (5-10 min)
  # compared to cloudspace recreation (50-60 min)

  depends_on = [spot_cloudspace.primary]
}

# -----------------------------------------------------------------------------
# Secondary Node Pool (HA Mode Only)
# -----------------------------------------------------------------------------
# Mirrors primary node pool configuration for balanced HA operation.

resource "spot_spotnodepool" "secondary" {
  count           = var.enable_ha ? 1 : 0
  cloudspace_name = spot_cloudspace.secondary[0].cloudspace_name
  server_class    = var.secondary_server_class != "" ? var.secondary_server_class : var.server_class
  bid_price       = var.bid_price

  autoscaling = {
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
  }

  depends_on = [spot_cloudspace.secondary]
}

# -----------------------------------------------------------------------------
# spotctl Configuration
# -----------------------------------------------------------------------------
# Sets up ~/.spot_config for CLI authentication.
# Also installs spotctl binary if not present.

resource "terraform_data" "setup_spotctl_config" {
  # triggers_replace forces re-creation (and provisioner re-run) when cloudspace changes
  triggers_replace = [spot_cloudspace.primary.cloudspace_name]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.kube
      printf 'org: "%s"\nrefreshToken: "%s"\nregion: "%s"\n' "${var.rackspace_org}" "$RACKSPACE_SPOT_TOKEN" "${var.region}" > ~/.spot_config
      chmod 600 ~/.spot_config

      if ! command -v spotctl &> /dev/null; then
        curl -sL "https://github.com/rackspace-spot/spotctl/releases/download/${var.spotctl_version}/spotctl-linux-amd64" -o /tmp/spotctl
        chmod +x /tmp/spotctl
      fi
    EOT

    environment = {
      RACKSPACE_SPOT_TOKEN = var.rackspace_spot_token
    }
  }

  depends_on = [spot_spotnodepool.primary]
}

# -----------------------------------------------------------------------------
# Wait for Cluster Ready
# -----------------------------------------------------------------------------
# Polls cloudspace status until Ready, then verifies kubeconfig is available.
# Max wait: 240 attempts * 30s = 2 hours

resource "terraform_data" "wait_for_cluster" {
  # triggers_replace forces re-creation when upstream resource changes
  triggers_replace = [terraform_data.setup_spotctl_config.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CLUSTER_NAME="${var.cluster_name}"
      KUBECONFIG_PATH="$HOME/.kube/$CLUSTER_NAME.yaml"
      MAX_ATTEMPTS=${var.cloudspace_poll_max_attempts}
      SLEEP_INTERVAL=${var.cloudspace_poll_interval}
      SPOTCTL=$(command -v spotctl || echo "/tmp/spotctl")
      
      mkdir -p ~/.kube
      echo "Waiting for cloudspace $CLUSTER_NAME (max 2 hours)..."
      
      for i in $(seq 1 $MAX_ATTEMPTS); do
        if STATUS_JSON=$($SPOTCTL cloudspaces get --name "$CLUSTER_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')
          
          case "$STATUS" in
            "Ready"|"Healthy"|"Running"|"Active"|"fulfilled")
              echo "✅ Cloudspace ready (status: $STATUS). Fetching kubeconfig..."
              $SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME"
              if [ -s "$KUBECONFIG_PATH" ] && grep -q "server:" "$KUBECONFIG_PATH"; then
                echo "✅ Kubeconfig verified at $KUBECONFIG_PATH"
                exit 0
              fi
              echo "⏳ Kubeconfig not available yet, retrying..."
              ;;
            "Provisioning"|"Creating"|"Pending")
              echo "[$i/$MAX_ATTEMPTS] Status: $STATUS"
              ;;
            "Failed"|"Error"|"Degraded")
              echo "❌ Cloudspace failed: $STATUS"
              exit 1
              ;;
          esac
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
# Wait for Nodepool Ready
# -----------------------------------------------------------------------------
# Polls nodepool status until Ready.
# Nodepools provision faster than cloudspaces (~5-15 min vs 50-60 min).
# Max wait: 60 attempts * 30s = 30 minutes

resource "terraform_data" "wait_for_nodepool" {
  # triggers_replace forces re-creation when nodepool changes
  triggers_replace = [spot_spotnodepool.primary.name]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      NODEPOOL_NAME="${spot_spotnodepool.primary.name}"
      MAX_ATTEMPTS=${var.nodepool_poll_max_attempts}
      SLEEP_INTERVAL=${var.nodepool_poll_interval}
      SPOTCTL=$(command -v spotctl || echo "/tmp/spotctl")

      echo "Waiting for nodepool $NODEPOOL_NAME (max 30 minutes)..."

      for i in $(seq 1 $MAX_ATTEMPTS); do
        if STATUS_JSON=$($SPOTCTL nodepools spot get --name "$NODEPOOL_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')

          case "$STATUS" in
            "Ready"|"Healthy"|"Running"|"Active"|"Fulfilled")
              echo "✅ Nodepool ready: $STATUS"
              exit 0
              ;;
            "Provisioning"|"Creating"|"Pending"|"Scaling")
              echo "[$i/$MAX_ATTEMPTS] Status: $STATUS"
              ;;
            "Failed"|"Error"|"Degraded")
              echo "❌ Nodepool failed: $STATUS"
              exit 1
              ;;
            *)
              echo "[$i/$MAX_ATTEMPTS] Status: $STATUS (unknown, continuing...)"
              ;;
          esac
        else
          echo "[$i/$MAX_ATTEMPTS] API call failed, retrying..."
        fi
        sleep $SLEEP_INTERVAL
      done

      echo "❌ Timeout waiting for nodepool"
      exit 1
    EOT
  }

  depends_on = [terraform_data.wait_for_cluster]
}

# -----------------------------------------------------------------------------
# Wait for Secondary Cluster Ready (HA Mode Only)
# -----------------------------------------------------------------------------
# Polls secondary cloudspace status until Ready.

resource "terraform_data" "wait_for_secondary_cluster" {
  count = var.enable_ha ? 1 : 0

  triggers_replace = [terraform_data.setup_spotctl_config.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CLUSTER_NAME="${var.secondary_cluster_name}"
      KUBECONFIG_PATH="$HOME/.kube/$CLUSTER_NAME.yaml"
      MAX_ATTEMPTS=${var.cloudspace_poll_max_attempts}
      SLEEP_INTERVAL=${var.cloudspace_poll_interval}
      SPOTCTL=$(command -v spotctl || echo "/tmp/spotctl")

      mkdir -p ~/.kube
      echo "Waiting for secondary cloudspace $CLUSTER_NAME (max 2 hours)..."

      for i in $(seq 1 $MAX_ATTEMPTS); do
        if STATUS_JSON=$($SPOTCTL cloudspaces get --name "$CLUSTER_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')

          case "$STATUS" in
            "Ready"|"Healthy"|"Running"|"Active"|"fulfilled"|"Fulfilled")
              echo "✅ Secondary cloudspace ready (status: $STATUS). Fetching kubeconfig..."
              $SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME"
              if [ -s "$KUBECONFIG_PATH" ] && grep -q "server:" "$KUBECONFIG_PATH"; then
                echo "✅ Secondary kubeconfig verified at $KUBECONFIG_PATH"
                exit 0
              fi
              echo "⏳ Kubeconfig not available yet, retrying..."
              ;;
            "Provisioning"|"Creating"|"Pending")
              echo "[$i/$MAX_ATTEMPTS] Secondary status: $STATUS"
              ;;
            "Failed"|"Error"|"Degraded")
              echo "❌ Secondary cloudspace failed: $STATUS"
              exit 1
              ;;
          esac
        fi
        sleep $SLEEP_INTERVAL
      done

      echo "❌ Timeout waiting for secondary cloudspace"
      exit 1
    EOT
  }

  depends_on = [terraform_data.setup_spotctl_config]
}

# -----------------------------------------------------------------------------
# Wait for Secondary Nodepool Ready (HA Mode Only)
# -----------------------------------------------------------------------------

resource "terraform_data" "wait_for_secondary_nodepool" {
  count = var.enable_ha ? 1 : 0

  triggers_replace = [spot_spotnodepool.secondary[0].name]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      NODEPOOL_NAME="${spot_spotnodepool.secondary[0].name}"
      MAX_ATTEMPTS=${var.nodepool_poll_max_attempts}
      SLEEP_INTERVAL=${var.nodepool_poll_interval}
      SPOTCTL=$(command -v spotctl || echo "/tmp/spotctl")

      echo "Waiting for secondary nodepool $NODEPOOL_NAME (max 30 minutes)..."

      for i in $(seq 1 $MAX_ATTEMPTS); do
        if STATUS_JSON=$($SPOTCTL nodepools spot get --name "$NODEPOOL_NAME" --output json 2>&1); then
          STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')

          case "$STATUS" in
            "Ready"|"Healthy"|"Running"|"Active"|"Fulfilled")
              echo "✅ Secondary nodepool ready: $STATUS"
              exit 0
              ;;
            "Provisioning"|"Creating"|"Pending"|"Scaling")
              echo "[$i/$MAX_ATTEMPTS] Secondary status: $STATUS"
              ;;
            "Failed"|"Error"|"Degraded")
              echo "❌ Secondary nodepool failed: $STATUS"
              exit 1
              ;;
            *)
              echo "[$i/$MAX_ATTEMPTS] Secondary status: $STATUS (unknown, continuing...)"
              ;;
          esac
        else
          echo "[$i/$MAX_ATTEMPTS] API call failed, retrying..."
        fi
        sleep $SLEEP_INTERVAL
      done

      echo "❌ Timeout waiting for secondary nodepool"
      exit 1
    EOT
  }

  depends_on = [terraform_data.wait_for_secondary_cluster]
}

# -----------------------------------------------------------------------------
# HA Provisioning Gate
# -----------------------------------------------------------------------------
# Blocks downstream operations until BOTH cloudspaces are ready.
# This is the synchronization point that ensures HA is fully active.

resource "terraform_data" "ha_gate" {
  count = var.enable_ha ? 1 : 0

  triggers_replace = [
    terraform_data.wait_for_nodepool.id,
    terraform_data.wait_for_secondary_nodepool[0].id
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "============================================"
      echo "  HA PROVISIONING GATE - VERIFICATION"
      echo "============================================"
      echo ""
      echo "Primary cloudspace:   ${var.cluster_name}"
      echo "Secondary cloudspace: ${var.secondary_cluster_name}"
      echo ""
      echo "✅ Both cloudspaces are ready!"
      echo "✅ Both nodepools are ready!"
      echo "✅ HA mode is now ACTIVE"
      echo ""
      echo "============================================"
    EOT
  }

  depends_on = [
    terraform_data.wait_for_nodepool,
    terraform_data.wait_for_secondary_nodepool
  ]
}

# -----------------------------------------------------------------------------
# Kubeconfig Fetch (External Data Source)
# -----------------------------------------------------------------------------
# Uses external data source to fetch kubeconfig via spotctl.
# This runs during both plan and apply phases, solving the chicken-and-egg
# problem where data.local_file would fail during plan.

data "external" "kubeconfig" {
  program = ["bash", "${path.module}/scripts/fetch-kubeconfig.sh"]

  query = {
    cluster_name = var.cluster_name
  }

  depends_on = [terraform_data.wait_for_nodepool]
}

# Secondary kubeconfig (HA mode only)
data "external" "secondary_kubeconfig" {
  count   = var.enable_ha ? 1 : 0
  program = ["bash", "${path.module}/scripts/fetch-kubeconfig.sh"]

  query = {
    cluster_name = var.secondary_cluster_name
  }

  depends_on = [terraform_data.wait_for_secondary_nodepool]
}

locals {
  # Decode the base64-encoded kubeconfig from the external data source
  # Use null as fallback since yamldecode returns a complex object that must match
  kubeconfig_raw = data.external.kubeconfig.result.kubeconfig != "" ? base64decode(data.external.kubeconfig.result.kubeconfig) : ""
  kubeconfig     = local.kubeconfig_raw != "" ? yamldecode(local.kubeconfig_raw) : null

  # Secondary kubeconfig (HA mode only)
  secondary_kubeconfig_raw = var.enable_ha && length(data.external.secondary_kubeconfig) > 0 ? (
    data.external.secondary_kubeconfig[0].result.kubeconfig != "" ? base64decode(data.external.secondary_kubeconfig[0].result.kubeconfig) : ""
  ) : ""
  secondary_kubeconfig = local.secondary_kubeconfig_raw != "" ? yamldecode(local.secondary_kubeconfig_raw) : null
}
