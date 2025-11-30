#!/bin/bash
################################################################################
# Bootstrap Terraform State Bucket
################################################################################
# This script creates the GCS bucket for storing Terraform state.
# Run this ONCE before running terraform init for the first time.
#
# Usage: ./scripts/bootstrap-state.sh <PROJECT_ID>
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/6
################################################################################

set -euo pipefail

# Configuration
BUCKET_NAME="project-beta-runners-tf-state"
REGION="us-central1"

# Validate arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <PROJECT_ID>"
    echo "Example: $0 my-gcp-project"
    exit 1
fi

PROJECT_ID="$1"

echo "============================================================"
echo "Terraform State Bucket Bootstrap"
echo "============================================================"
echo "Project ID:  ${PROJECT_ID}"
echo "Bucket Name: ${BUCKET_NAME}"
echo "Region:      ${REGION}"
echo "============================================================"
echo ""

# Check if bucket already exists
if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" &>/dev/null; then
    echo "✅ Bucket gs://${BUCKET_NAME} already exists"
    echo "   Skipping creation..."
else
    echo "📦 Creating bucket gs://${BUCKET_NAME}..."
    gcloud storage buckets create "gs://${BUCKET_NAME}" \
        --project="${PROJECT_ID}" \
        --location="${REGION}" \
        --uniform-bucket-level-access
    echo "✅ Bucket created"
fi

# Enable versioning
echo "🔄 Enabling versioning..."
gcloud storage buckets update "gs://${BUCKET_NAME}" \
    --versioning
echo "✅ Versioning enabled"

# Set lifecycle policy (keep last 30 versions)
echo "📋 Setting lifecycle policy (keep 30 versions)..."
cat > /tmp/lifecycle-policy.json << 'LIFECYCLE'
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"numNewerVersions": 30}
    }
  ]
}
LIFECYCLE

gcloud storage buckets update "gs://${BUCKET_NAME}" \
    --lifecycle-file=/tmp/lifecycle-policy.json

rm /tmp/lifecycle-policy.json
echo "✅ Lifecycle policy applied"

# Verify bucket configuration
echo ""
echo "============================================================"
echo "Bucket Configuration"
echo "============================================================"
gcloud storage buckets describe "gs://${BUCKET_NAME}" \
    --format="table(name,location,versioning.enabled,iamConfiguration.uniformBucketLevelAccess.enabled)"

echo ""
echo "============================================================"
echo "✅ Bootstrap Complete!"
echo "============================================================"
echo ""
echo "Next steps:"
echo "1. Run 'cd terraform/environments/dev && terraform init'"
echo "2. Run 'terraform plan' to verify configuration"
echo ""
