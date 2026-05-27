#!/usr/bin/env bash
# Bootstrap GKE GitHub App Secret
#
# One-shot script to create the Kubernetes Secret that ARC needs for GitHub App auth.
# Pulls credentials from GCP Secret Manager and creates a k8s Secret in arc-runners namespace.
#
# Prerequisites:
#   1. GKE cluster is provisioned and kubectl context is set
#   2. GCP Secret Manager secrets are populated:
#      - matchpoint-gke-runners-app-id
#      - matchpoint-gke-runners-installation-id
#      - matchpoint-gke-runners-private-key
#   3. gcloud CLI authenticated with access to the secrets
#
# Usage:
#   ./scripts/bootstrap-gke-secrets.sh [project-id]
#
# Phase 2 follow-up: Replace this with External Secrets Operator (ESO)

set -euo pipefail

PROJECT_ID="${1:-project-beta-407300}"
SECRET_NAME="arc-gke-github-app-secret"
NAMESPACE="arc-runners"

echo "=== Bootstrap GKE GitHub App Secret ==="
echo "Project: $PROJECT_ID"
echo "Secret:  $SECRET_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Ensure namespace exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Fetch secrets from GCP Secret Manager
echo "Fetching secrets from GCP Secret Manager..."
APP_ID=$(gcloud secrets versions access latest --secret=matchpoint-gke-runners-app-id --project="$PROJECT_ID")
INSTALLATION_ID=$(gcloud secrets versions access latest --secret=matchpoint-gke-runners-installation-id --project="$PROJECT_ID")
PRIVATE_KEY=$(gcloud secrets versions access latest --secret=matchpoint-gke-runners-private-key --project="$PROJECT_ID")

# Validate we got values
if [[ -z "$APP_ID" || -z "$INSTALLATION_ID" || -z "$PRIVATE_KEY" ]]; then
  echo "ERROR: One or more secrets are empty. Check GCP Secret Manager."
  exit 1
fi

# Create the Kubernetes secret
echo "Creating Kubernetes secret..."
kubectl create secret generic "$SECRET_NAME" \
  --namespace="$NAMESPACE" \
  --from-literal=github_app_id="$APP_ID" \
  --from-literal=github_app_installation_id="$INSTALLATION_ID" \
  --from-literal=github_app_private_key="$PRIVATE_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Done ==="
echo "Secret '$SECRET_NAME' created in namespace '$NAMESPACE'."
echo "Verify: kubectl get secret $SECRET_NAME -n $NAMESPACE"
