# Terraform State Migration Guide

> **Status: COMPLETED (January 2026)**
> This one-time migration has been executed. The `argocd-apps` module was successfully
> split into `arc-prereqs` + `argocd-bootstrap`. This document is retained for historical
> reference only.

This document describes how to migrate terraform state from the old `argocd-apps` module
to the new split modules (`arc-prereqs` + `argocd-bootstrap`).

## Overview

The old `3-argocd-apps` stage has been split into:
- `3-arc-prereqs` - Creates namespaces and GitHub token secret (LOCAL module)
- `4-argocd-bootstrap` - Creates the ArgoCD Application CRD (REMOTE module)

## Architecture

```
Remote (spot-argocd-cloudspace)     Local (this repo)
─────────────────────────────────   ─────────────────────────
cloudspace, cluster-base,           infrastructure/modules/
argocd-bootstrap                    └── arc-prereqs/
```

## Migration Steps

### Step 1: Backup Current State

```bash
cd infrastructure/live/prod/3-arc-prereqs
terragrunt state pull > ../state-backup-argocd-apps.json
```

### Step 2: Import Resources into New Stages

Since we're splitting one state into two, we need to import the resources:

```bash
# In 3-arc-prereqs (uses LOCAL module)
cd infrastructure/live/prod/3-arc-prereqs
terragrunt import kubernetes_namespace_v1.arc_systems arc-systems
terragrunt import kubernetes_namespace_v1.arc_runners arc-runners
terragrunt import kubernetes_secret_v1.github_token arc-runners/arc-org-github-secret

# In 4-argocd-bootstrap (uses REMOTE argocd-bootstrap module)
cd infrastructure/live/prod/4-argocd-bootstrap
terragrunt import 'kubernetes_manifest.bootstrap_application' \
  'apiVersion=argoproj.io/v1alpha1,kind=Application,namespace=argocd,name=project-beta-runners-bootstrap'
```

### Step 3: Verify No Changes

After migration, run plan in both stages to verify no changes:

```bash
cd infrastructure/live/prod/3-arc-prereqs
terragrunt plan  # Should show: No changes

cd infrastructure/live/prod/4-argocd-bootstrap
terragrunt plan  # Should show: No changes
```

### Step 4: Remove Old State (if using separate state files)

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
rm -rf infrastructure/modules/arc-prereqs
```

## Module Source Reference

After migration:
- `3-arc-prereqs` uses `${local.versions.locals.local_modules}//arc-prereqs` (local)
- `4-argocd-bootstrap` uses `${local.versions.locals.remote_modules}//argocd-bootstrap?ref=...` (remote)
