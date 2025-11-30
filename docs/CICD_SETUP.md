# CI/CD Setup Guide

This document describes how to configure CI/CD for the GitHub Runners infrastructure.

## Prerequisites

1. GCP Project with billing enabled
2. GitHub repository admin access
3. `gcloud` CLI installed and authenticated

## Step 1: Bootstrap Terraform State

Before any CI/CD can run, create the state bucket:

```bash
./scripts/bootstrap-state.sh <PROJECT_ID>
```

## Step 2: Create Workload Identity Federation

GitHub Actions uses Workload Identity Federation to authenticate with GCP without storing service account keys.

### Create the Workload Identity Pool

```bash
PROJECT_ID="your-project-id"
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-actions" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions"

# Create OIDC Provider for GitHub
gcloud iam workload-identity-pools providers create-oidc "github" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-actions" \
  --display-name="GitHub" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create "github-actions-terraform" \
  --project="${PROJECT_ID}" \
  --display-name="GitHub Actions Terraform"

# Grant required roles
for ROLE in \
  "roles/run.admin" \
  "roles/artifactregistry.admin" \
  "roles/secretmanager.admin" \
  "roles/iam.serviceAccountAdmin" \
  "roles/iam.serviceAccountUser" \
  "roles/storage.admin" \
  "roles/resourcemanager.projectIamAdmin" \
  "roles/serviceusage.serviceUsageAdmin"
do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:github-actions-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="${ROLE}"
done

# Allow GitHub Actions to impersonate this service account
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-actions/attribute.repository/Matchpoint-AI/project-beta-runners"
```

### Get the Provider Resource Name

```bash
echo "projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-actions/providers/github"
```

## Step 3: Configure GitHub Repository

### Required Repository Variables

Go to **Settings → Secrets and variables → Actions → Variables** and add:

| Variable Name | Value |
|--------------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `WIF_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/providers/github` |
| `WIF_SERVICE_ACCOUNT` | `github-actions-terraform@PROJECT_ID.iam.gserviceaccount.com` |

### Required Environments

Create environments for deployment approvals:

1. Go to **Settings → Environments**
2. Create `dev` environment
3. Create `prod` environment (with required reviewers if desired)

## Step 4: Test the Setup

1. Create a PR with a Terraform change
2. Verify CI workflow runs `validate` and `plan`
3. Merge the PR
4. Verify CD workflow runs `apply`

## Troubleshooting

### "Permission denied" errors

1. Verify WIF is configured correctly
2. Check service account has required roles
3. Verify repository name matches the WIF binding

### "Backend not initialized" errors

1. Ensure `bootstrap-state.sh` was run
2. Verify bucket exists: `gcloud storage buckets describe gs://project-beta-runners-tf-state`

### CI skipping plan step

The plan step only runs for PRs from the same repository (not forks) due to security restrictions around GCP credentials.
