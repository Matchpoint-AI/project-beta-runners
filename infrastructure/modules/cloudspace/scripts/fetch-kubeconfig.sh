#!/bin/bash
# Fetches kubeconfig via spotctl and outputs as JSON for terraform external data source
# This script runs during both plan and apply phases

set -e

# Read input JSON from stdin
INPUT=$(cat)
CLUSTER_NAME=$(echo "$INPUT" | jq -r '.cluster_name')

# Find spotctl
SPOTCTL=$(command -v spotctl 2>/dev/null || echo "/tmp/spotctl")

# Check if cloudspace is ready
if ! STATUS_JSON=$($SPOTCTL cloudspaces get --name "$CLUSTER_NAME" --output json 2>/dev/null); then
  # Cloudspace doesn't exist yet - return empty kubeconfig
  echo '{"kubeconfig": "", "status": "not_found"}'
  exit 0
fi

STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')

if [[ "$STATUS" != "Ready" && "$STATUS" != "Healthy" && "$STATUS" != "Running" ]]; then
  # Cloudspace exists but not ready
  echo "{\"kubeconfig\": \"\", \"status\": \"$STATUS\"}"
  exit 0
fi

# Cloudspace is ready - fetch kubeconfig
mkdir -p ~/.kube
$SPOTCTL cloudspaces get-config --name "$CLUSTER_NAME" >/dev/null 2>&1

KUBECONFIG_PATH="$HOME/.kube/$CLUSTER_NAME.yaml"

if [ -s "$KUBECONFIG_PATH" ]; then
  # Base64 encode the kubeconfig to safely pass through JSON
  KUBECONFIG_B64=$(base64 -w0 "$KUBECONFIG_PATH")
  echo "{\"kubeconfig\": \"$KUBECONFIG_B64\", \"status\": \"$STATUS\"}"
else
  echo '{"kubeconfig": "", "status": "fetch_failed"}'
fi
