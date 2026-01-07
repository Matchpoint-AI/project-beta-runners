# project-beta-runners

[![Infrastructure](https://img.shields.io/badge/Terragrunt-3%20States-blue)](https://terragrunt.gruntwork.io/)
[![State](https://img.shields.io/badge/State-GCS-yellow)](https://cloud.google.com/storage)
[![Runners](https://img.shields.io/badge/ARC-v0.9.x-green)](https://github.com/actions/actions-runner-controller)
[![Docker](https://img.shields.io/badge/Docker--in--Docker-v24-orange)](https://hub.docker.com/_/docker)
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

Terragrunt 3-state architecture with GCS backend:

| State | Resources | Duration |
|-------|-----------|----------|
| 1-cloudspace | Rackspace Spot K8s cluster + node pool | 50-60 min |
| 2-cluster-base | Kubeconfig fetch + ArgoCD install | 5-10 min |
| 3-argocd-apps | ARC controller + runner ScaleSet | 2-5 min |

---

## Runner Specifications

| Spec | Value |
|------|-------|
| Label | `project-beta-runners` |
| Runner CPU/Memory | 2 CPU, 8-10 GB RAM |
| DinD Sidecar | 1 CPU, 3-6 GB RAM |
| Autoscaling | 5 min → 25 max |
| Warm Runners | 5 always-on |

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

## Documentation

- **Full README:** See Issue #56 for complete documentation
- **Runbooks:** `docs/RUNBOOKS.md` (coming soon)
- **Troubleshooting:** `docs/TROUBLESHOOTING.md` (coming soon)

---

## License

Proprietary - Matchpoint AI
