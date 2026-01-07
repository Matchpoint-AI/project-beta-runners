# project-beta-runners

[![Infrastructure](https://img.shields.io/badge/Terragrunt-3%20States-blue)](https://terragrunt.gruntwork.io/)
[![State](https://img.shields.io/badge/State-GCS-yellow)](https://cloud.google.com/storage)
[![Runners](https://img.shields.io/badge/ARC-v0.9.x-green)](https://github.com/actions/actions-runner-controller)
[![Platform](https://img.shields.io/badge/Rackspace%20Spot-Kubernetes-purple)](https://spot.rackspace.com/)

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
│  │                     Kubernetes Cluster (mp-runners-v3)             │ │
│  │                                                                    │ │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐ │ │
│  │  │   ArgoCD     │───▶│ ARC Controller│───▶│   Runner Pods       │ │ │
│  │  │  (GitOps)    │    │              │    │   (5-25 runners)     │ │ │
│  │  └──────────────┘    └──────────────┘    │   ┌────┐ ┌────┐     │ │ │
│  │                                          │   │Pod1│ │Pod2│ ... │ │ │
│  │                                          │   └────┘ └────┘     │ │ │
│  │                                          └──────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

### Terragrunt 3-Stage Architecture

| State | Purpose | Duration | Timeout |
|-------|---------|----------|---------|
| 1-cloudspace | Rackspace Spot K8s cluster + node pool | 50-60 min | 90 min |
| 2-cluster-base | Kubeconfig fetch + ArgoCD install | 5-10 min | 20 min |
| 3-argocd-apps | ARC controller + runner ScaleSet | 2-5 min | 15 min |

---

## Repository Structure

```
project-beta-runners/
├── infrastructure/
│   ├── modules/                      # Reusable Terraform modules
│   │   ├── cloudspace/               # Rackspace Spot cluster
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── cluster-base/             # Kubeconfig + ArgoCD
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── argocd-apps/              # ARC + runners
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── live/                         # Terragrunt configurations
│       ├── root.hcl                  # Root config (GCS backend)
│       ├── env-vars/
│       │   └── prod.hcl              # Production variables
│       └── prod/
│           ├── 1-cloudspace/
│           │   └── terragrunt.hcl    # → modules/cloudspace
│           ├── 2-cluster-base/
│           │   └── terragrunt.hcl    # → modules/cluster-base
│           └── 3-argocd-apps/
│               └── terragrunt.hcl    # → modules/argocd-apps
│
├── .github/
│   └── workflows/
│       ├── deploy.yml                # Plan on PR, Apply on merge
│       ├── verify-runners.yml        # Test runners after deploy
│       └── manual.yml                # Destroy, force-apply
│
└── README.md
```

---

## Runner Specifications

| Spec | Value |
|------|-------|
| Label | `project-beta-runners` |
| Runner CPU/Memory | 4 vCPU, 15 GB RAM |
| DinD Sidecar | `docker:24-dind` |
| Autoscaling | 5 min → 25 max |
| Warm Runners | 5 always-on |
| DOCKER_HOST | `tcp://localhost:2375` |
| DOCKER_API_VERSION | `1.43` |

---

## CI/CD Workflows

### Deploy (`deploy.yml`)

- **On PR**: Runs `terragrunt plan` for preview
- **On merge to main**: Applies sequentially (Stage 1 → 2 → 3)
- **Auto-triggers**: `verify-runners.yml` after successful deploy

### Verify (`verify-runners.yml`)

- Runs **on** `project-beta-runners` (tests the runners themselves)
- Validates: runner online, Docker available, build/run works

### Manual (`manual.yml`)

- `plan-all`: Preview all changes
- `apply-state-N`: Apply individual state
- `destroy-all`: Destroy infrastructure (requires confirmation)

---

## Required Secrets

| Secret | Purpose |
|--------|---------|
| `GCP_PROJECT` | GCP project for state bucket |
| `GCS_BUCKET` | Terraform state bucket |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider |
| `GCP_SERVICE_ACCOUNT` | Service account for WIF |
| `RACKSPACE_SPOT_API_TOKEN` | Rackspace API |
| `ARC_GITHUB_APP_ID` | Runner registration |
| `ARC_GITHUB_APP_PRIVATE_KEY` | Runner auth |
| `ARC_GITHUB_APP_INSTALLATION_ID` | Org installation |

---

## Local Development

```bash
# Prerequisites
brew install terragrunt terraform

# Set credentials
export RACKSPACE_SPOT_TOKEN="your-token"
export GCP_PROJECT="your-project"
export GCS_BUCKET="your-bucket"

# Plan all states
cd infrastructure/live/prod
terragrunt run-all plan

# Apply specific state
cd infrastructure/live/prod/1-cloudspace
terragrunt apply
```

---

## Related

- [project-beta](https://github.com/Matchpoint-AI/project-beta) - Main infrastructure
- [project-beta-api](https://github.com/Matchpoint-AI/project-beta-api) - Uses these runners
- [project-beta-frontend](https://github.com/Matchpoint-AI/project-beta-frontend) - Uses GitHub-hosted

---

## License

Proprietary - Matchpoint AI
