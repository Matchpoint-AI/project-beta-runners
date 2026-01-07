# project-beta-runners

[![Infrastructure](https://img.shields.io/badge/Terragrunt-3%20Stages-blue)](https://terragrunt.gruntwork.io/)
[![Runners](https://img.shields.io/badge/ARC-v0.9.x-green)](https://github.com/actions/actions-runner-controller)
[![Platform](https://img.shields.io/badge/Rackspace%20Spot-Kubernetes-purple)](https://spot.rackspace.com/)
[![GitOps](https://img.shields.io/badge/ArgoCD-GitOps-orange)](https://argo-cd.readthedocs.io/)

Self-hosted GitHub Actions runner infrastructure for the Project Beta ecosystem.

---

## Quick Start for Developers

**Using the runners in your workflow:**

```yaml
jobs:
  build:
    runs-on: project-beta-runners  # <-- Use this label
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  docker-build:
    runs-on: project-beta-runners
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp .
      - run: docker compose up -d
```

**What works automatically:** `docker build`, `docker run`, `docker compose`, Testcontainers

---

## Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              GitHub Cloud                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │ project-    │  │ project-    │  │ project-    │  │ project-    │   │
│  │ beta-api    │  │ beta-       │  │ beta        │  │ beta-       │   │
│  │             │  │ frontend    │  │ (infra)     │  │ runners     │   │
│  └──────┬──────┘  └──────┬──────┘  └─────────────┘  └──────┬──────┘   │
│         │                │                                  │          │
│         └────────────────┼──────────────────────────────────┘          │
│                          │ runs-on: project-beta-runners               │
└──────────────────────────┼─────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        Rackspace Spot Cloudspace                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                 Kubernetes Cluster (matchpoint-runners)            │ │
│  │                                                                    │ │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐ │ │
│  │  │   ArgoCD     │───▶│ ARC Controller│───▶│   Runner Pods       │ │ │
│  │  │  (GitOps)    │    │              │    │   (5-25 runners)     │ │ │
│  │  └──────┬───────┘    └──────────────┘    │   ┌────┐ ┌────┐     │ │ │
│  │         │                                │   │Pod1│ │Pod2│ ... │ │ │
│  │         │ syncs from                     │   └────┘ └────┘     │ │ │
│  │         │ argocd/applications/           └──────────────────────┘ │ │
│  │         ▼                                                         │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │  project-beta-runners repo (argocd/applications/)            │ │ │
│  │  │  ├── arc-controller.yaml (ARC controller Helm)               │ │ │
│  │  │  └── arc-runners.yaml (ARC runner scale set)                 │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

### GitOps Flow (App-of-Apps Pattern)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────────┐
│ Terragrunt  │────▶│   ArgoCD    │────▶│  argocd/applications/   │
│  Stage 3    │     │  Bootstrap  │     │  ├── arc-controller.yaml│
│             │     │    App      │     │  └── arc-runners.yaml   │
└─────────────┘     └─────────────┘     └───────────┬─────────────┘
                                                    │
                          ArgoCD syncs              ▼
                    ┌────────────────────────────────────────┐
                    │  Kubernetes Cluster                    │
                    │  ├── arc-systems/      (controller)    │
                    │  └── arc-runners/      (runner pods)   │
                    └────────────────────────────────────────┘
```

**Benefits of GitOps:**
- **Self-healing**: ArgoCD automatically reconciles drift
- **Auditability**: All changes tracked in Git
- **Declarative**: Runner config is YAML in this repo
- **Rollback**: Revert to any previous commit

---

### Terragrunt 3-Stage Architecture

| Stage | Purpose | Duration | Timeout |
|-------|---------|----------|---------|
| 1-cloudspace | Rackspace Spot K8s cluster + node pool | 50-60 min | 90 min |
| 2-cluster-base | Kubeconfig fetch + ArgoCD install | 5-10 min | 20 min |
| 3-argocd-apps | Bootstrap Application + secrets | 1-2 min | 15 min |

> **Note:** Stage 3 creates a bootstrap ArgoCD Application that syncs the `argocd/applications/` directory. ArgoCD then manages ARC deployment, not Terraform directly.

### ⚠️ Cloudspace Recreation Warning

**Changing the cloudspace name forces full recreation, which takes 50-60 minutes.**

The cloudspace name (`cluster_name` in `prod.hcl`) is the primary identifier. Any change triggers:
1. Destruction of existing cloudspace (immediate)
2. Creation of new cloudspace (immediate)
3. Control plane provisioning (50-60 minutes)
4. Kubeconfig fetch and remaining stages

**Avoid cloudspace recreation unless absolutely necessary.** Safe changes that don't trigger recreation:
- Node pool scaling (`min_nodes`, `max_nodes`)
- ArgoCD application configs (`argocd/applications/`)
- Runner configuration changes

---

## Repository Structure

```
project-beta-runners/
├── argocd/                          # ArgoCD GitOps manifests
│   ├── applications/                # App-of-Apps pattern
│   │   ├── arc-controller.yaml      # ARC controller Helm Application
│   │   └── arc-runners.yaml         # ARC runner scale set Application
│   └── bootstrap.yaml               # Reference bootstrap manifest
│
├── infrastructure/
│   ├── modules/                     # Reusable Terraform modules
│   │   ├── cloudspace/              # Rackspace Spot cluster
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── cluster-base/            # Kubeconfig + ArgoCD
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── argocd-apps/             # Bootstrap Application + secrets
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── live/                        # Terragrunt configurations
│       ├── root.hcl                 # Root config (TFstate.dev backend)
│       ├── env-vars/
│       │   └── prod.hcl             # Production variables
│       └── prod/
│           ├── 1-cloudspace/
│           │   └── terragrunt.hcl   # → modules/cloudspace
│           ├── 2-cluster-base/
│           │   └── terragrunt.hcl   # → modules/cluster-base
│           └── 3-argocd-apps/
│               └── terragrunt.hcl   # → modules/argocd-apps
│
├── .github/
│   └── workflows/
│       ├── ci.yml                   # Format, validate, docs checks
│       ├── deploy.yml               # Plan on PR, Apply on merge
│       ├── verify-runners.yml       # Test runners after deploy
│       └── manual.yml               # Destroy, force-apply
│
└── README.md
```

---

## Runner Configuration

Runner settings are defined in `argocd/applications/arc-runners.yaml`:

| Spec | Value | Location |
|------|-------|----------|
| Label | `project-beta-runners` | `runnerScaleSetName` |
| Runner Image | `ghcr.io/actions/actions-runner:latest` | `template.spec.containers[0].image` |
| DinD Sidecar | `docker:24-dind` | `template.spec.containers[1].image` |
| Min Runners | 5 | `minRunners` |
| Max Runners | 25 | `maxRunners` |
| DOCKER_HOST | `tcp://localhost:2375` | `template.spec.containers[0].env` |

**To change runner configuration:**
1. Edit `argocd/applications/arc-runners.yaml`
2. Commit and push to `main`
3. ArgoCD auto-syncs within 3 minutes

---

## CI/CD Workflows

### CI (`ci.yml`)

| Check | Description |
|-------|-------------|
| Terraform Format | `terraform fmt -check -recursive` |
| Terraform Validate | `terraform validate` per module |
| Terraform Docs | `terraform-docs --output-check` |
| Terragrunt Plan | Preview changes (after validation) |

### Deploy (`deploy.yml`)

- **On PR**: Runs `terragrunt plan` for preview
- **On merge to main**: Applies sequentially (Stage 1 → 2 → 3)
- **Auto-triggers**: `verify-runners.yml` after successful deploy

### Verify (`verify-runners.yml`)

- Runs **on** `project-beta-runners` (tests the runners themselves)
- Validates: runner online, Docker available, build/run works

### Manual (`manual.yml`)

- `plan-all`: Preview all changes
- `apply-stage-N`: Apply individual stage
- `destroy-all`: Destroy infrastructure (requires confirmation)

---

## Required Secrets

| Secret | Source | Purpose |
|--------|--------|---------|
| `RACKSPACE_SPOT_API_TOKEN` | Org secret | Rackspace Spot API |
| `INFRA_GH_TOKEN` | Org secret | TFstate.dev backend + ARC runner registration |

> **Note:** Both secrets are org-level and already granted to this repository.

---

## Local Development

```bash
# Prerequisites
brew install terragrunt terraform

# Set credentials
export RACKSPACE_SPOT_TOKEN="your-token"
export TF_HTTP_PASSWORD="your-github-token"  # For TFstate.dev backend
export INFRA_GH_TOKEN="your-github-token"    # For ARC runner registration

# Plan all stages
cd infrastructure/live/prod
terragrunt run-all plan

# Apply specific stage
cd infrastructure/live/prod/1-cloudspace
terragrunt apply
```

### Modifying Runner Configuration

Since runner configuration is managed by ArgoCD (GitOps), changes to runner settings are made via Git:

```bash
# Edit runner configuration
vim argocd/applications/arc-runners.yaml

# Commit and push
git add argocd/applications/arc-runners.yaml
git commit -m "chore: increase max runners to 30"
git push origin main

# ArgoCD auto-syncs (or manually sync in ArgoCD UI)
```

---

## Troubleshooting

### ArgoCD Sync Status

```bash
# Port-forward ArgoCD UI (requires kubeconfig)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Default admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Runner Pod Issues

```bash
# Check runner pods
kubectl get pods -n arc-runners

# Check runner logs
kubectl logs -n arc-runners -l app.kubernetes.io/component=runner -f

# Check DinD sidecar
kubectl logs -n arc-runners <pod-name> -c dind
```

### ArgoCD Application Status

```bash
# Check all ArgoCD applications
kubectl get applications -n argocd

# Check specific application status
kubectl describe application arc-runners -n argocd
```

---

## Related

- [project-beta](https://github.com/Matchpoint-AI/project-beta) - Main infrastructure
- [project-beta-api](https://github.com/Matchpoint-AI/project-beta-api) - Uses these runners
- [project-beta-frontend](https://github.com/Matchpoint-AI/project-beta-frontend) - Uses GitHub-hosted
- [ARC Documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

---

## License

Proprietary - Matchpoint AI
