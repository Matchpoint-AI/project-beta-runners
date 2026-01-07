#!/bin/bash
#
# Wait for Rackspace Spot cloudspace to be ready using spotctl.
# Provides better visibility than raw curl polling.
#
# Usage:
#   ./spotctl-wait-for-cluster.sh <cloudspace-name> [max-attempts] [sleep-seconds]
#
# Example:
#   ./spotctl-wait-for-cluster.sh mp-runners-v3 240 30
#
# Requires:
#   - spotctl installed and configured
#   - RACKSPACE_SPOT_TOKEN environment variable (or spotctl config)
#

set -euo pipefail

CLOUDSPACE_NAME="${1:?Usage: $0 <cloudspace-name> [max-attempts] [sleep-seconds]}"
MAX_ATTEMPTS="${2:-240}"  # Default: 240 attempts
SLEEP_SECONDS="${3:-30}"   # Default: 30 seconds

echo "Waiting for cloudspace '$CLOUDSPACE_NAME' to be ready..."
echo "  Max attempts: $MAX_ATTEMPTS"
echo "  Sleep interval: ${SLEEP_SECONDS}s"
echo "  Max wait time: $(( MAX_ATTEMPTS * SLEEP_SECONDS / 60 )) minutes"
echo ""

for i in $(seq 1 "$MAX_ATTEMPTS"); do
  # Get cloudspace status via spotctl
  if STATUS_JSON=$(spotctl cloudspaces get "$CLOUDSPACE_NAME" --output json 2>/dev/null); then
    STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "Unknown"')
  else
    STATUS="NotFound"
  fi
  
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$TIMESTAMP] Attempt $i/$MAX_ATTEMPTS: Status = $STATUS"
  
  case "$STATUS" in
    "Ready"|"Running")
      echo ""
      echo "✅ Cloudspace '$CLOUDSPACE_NAME' is ready!"
      
      # Verify kubeconfig is accessible
      if spotctl cloudspaces get-config "$CLOUDSPACE_NAME" --file /dev/null 2>/dev/null; then
        echo "✅ Kubeconfig is accessible"
      else
        echo "⚠️  Kubeconfig not yet accessible, waiting a bit more..."
        sleep 10
      fi
      
      exit 0
      ;;
      
    "Failed"|"Error"|"Deleted")
      echo ""
      echo "❌ Cloudspace '$CLOUDSPACE_NAME' is in '$STATUS' state!"
      echo ""
      echo "Full status:"
      echo "$STATUS_JSON" | jq '.'
      echo ""
      echo "Recovery options:"
      echo "  1. Delete and recreate: spotctl cloudspaces delete --name $CLOUDSPACE_NAME"
      echo "  2. Check Rackspace Spot console for more details"
      exit 1
      ;;
      
    "Provisioning"|"Creating")
      # Still provisioning - continue waiting
      ;;
      
    "NotFound")
      echo "   Cloudspace not found - may not be created yet"
      ;;
      
    *)
      echo "   Unknown status: $STATUS"
      ;;
  esac
  
  sleep "$SLEEP_SECONDS"
done

echo ""
echo "❌ Timed out waiting for cloudspace '$CLOUDSPACE_NAME' after $(( MAX_ATTEMPTS * SLEEP_SECONDS / 60 )) minutes"
echo ""
echo "Last known status:"
spotctl cloudspaces get "$CLOUDSPACE_NAME" --output json 2>/dev/null | jq '.' || echo "Could not fetch status"
echo ""
echo "Recovery options:"
echo "  1. Re-run deployment (cloudspace may still be provisioning)"
echo "  2. Delete stuck cloudspace: spotctl cloudspaces delete --name $CLOUDSPACE_NAME"
echo "  3. Check Rackspace Spot status page"

exit 1
