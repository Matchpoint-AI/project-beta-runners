# Terraform State Migration Guide

This document describes how to migrate terraform state from the old `argocd-apps` module
to the new split modules (`arc-prereqs` + `argocd-bootstrap`).

## Overview

The old `3-argocd-apps` stage has been split into:
- `3-arc-prereqs` - Creates namespaces and GitHub token secret
- `4-argocd-bootstrap` - Creates the ArgoCD Application CRD

## Migration Steps

### Step 1: Backup Current State

```bash
cd infrastructure/live/prod/3-arc-prereqs
terragrunt state pull > ../state-backup-argocd-apps.json
```

### Step 2: Move Namespace and Secret Resources

The namespaces and secret need to be moved from the old module to the new `arc-prereqs` module:

```bash
cd infrastructure/live/prod/3-arc-prereqs

# Move arc-systems namespace
terragrunt state mv \
  'kubernetes_namespace_v1.arc_systems' \
  'kubernetes_namespace_v1.arc_systems'

# Move arc-runners namespace
terragrunt state mv \
  'kubernetes_namespace_v1.arc_runners' \
  'kubernetes_namespace_v1.arc_runners'

# Move GitHub token secret
terragrunt state mv \
  'kubernetes_secret_v1.github_token' \
  'kubernetes_secret_v1.github_token'
```

Note: The resource addresses are the same because we're moving between stages with the same
module resource names. The state migration happens when you:
1. Run `terragrunt init` in the new directory (creates new state)
2. Import existing resources

### Step 3: Import Resources into New Stages

Since we're splitting one state into two, we need to import the resources:

```bash
# In 3-arc-prereqs
cd infrastructure/live/prod/3-arc-prereqs
terragrunt import kubernetes_namespace_v1.arc_systems arc-systems
terragrunt import kubernetes_namespace_v1.arc_runners arc-runners
terragrunt import kubernetes_secret_v1.github_token arc-runners/arc-org-github-secret

# In 4-argocd-bootstrap
cd infrastructure/live/prod/4-argocd-bootstrap
terragrunt import 'kubernetes_manifest.bootstrap_application' 'apiVersion=argoproj.io/v1alpha1,kind=Application,namespace=argocd,name=project-beta-runners-bootstrap'
```

### Step 4: Verify No Changes

After migration, run plan in both stages to verify no changes:

```bash
cd infrastructure/live/prod/3-arc-prereqs
terragrunt plan  # Should show: No changes

cd infrastructure/live/prod/4-argocd-bootstrap
terragrunt plan  # Should show: No changes
```

### Step 5: Remove Old State (if using separate state files)

If each stage has its own state file, the old `3-argocd-apps` state is now obsolete.
The resources have been migrated to the new stages.

## Rollback

If migration fails, restore from backup:

```bash
cd infrastructure/live/prod/3-arc-prereqs
terragrunt state push ../state-backup-argocd-apps.json
```

Then rename the directory back:
```bash
mv 3-arc-prereqs 3-argocd-apps
rm -rf 4-argocd-bootstrap
```
