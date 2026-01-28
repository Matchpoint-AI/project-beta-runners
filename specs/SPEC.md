# Project Beta Runners Specification

## Overview

This repository provides self-hosted GitHub Actions runner infrastructure for the Project Beta ecosystem. The runners execute CI/CD workflows for all repositories in the hub-and-spoke architecture.

## Role in Hub-and-Spoke Architecture

### Architecture Position

The runners repository occupies a unique position in Project Beta:

- **Not a runtime component**: Does not participate in the hub-and-spoke message flow
- **Infrastructure component**: Provides CI/CD capabilities for all services
- **Cross-cutting concern**: Deploys and validates every service in the ecosystem

### Services Deployed

The runners deploy the following components:

| Component Type | Service | Deployment Target |
|---------------|---------|-------------------|
| Hub | API (`project-beta-api`) | Cloud Run |
| Spoke | Content Designer (`project-beta-agentic-content-designer`) | Cloud Run |
| Spoke | Post Generator (`project-beta-post-generator`) | Cloud Run |
| Spoke | Brand Crawler (`project-beta-agentic-brand-crawler`) | Cloud Run |
| Spoke | Campaign Publisher (`project-beta-campaign-publisher`) | Cloud Run |
| Client | Frontend (`project-beta-frontend`) | Cloud Run / CDN |
| Client | Slack Bot (`project-beta-slack-bot`) | Cloud Run |

## Technical Specifications

### Infrastructure Stack

- **Orchestration**: Kubernetes (Rackspace Spot)
- **GitOps**: ArgoCD
- **Runner Controller**: Actions Runner Controller (ARC)
- **IaC**: Terraform + Terragrunt

### Runner Capabilities

- Docker-in-Docker (DinD) support
- Testcontainers support
- Parallel job execution (5-25 runners)
- Auto-scaling based on job queue

### Deployment Flow

```
Code Push → GitHub Actions → Self-hosted Runners → Build → Test → Deploy to Cloud Run
```

## Design Decisions

### Why Self-hosted Runners?

1. **Docker-in-Docker**: Required for building container images
2. **Cost**: More economical for high-volume CI/CD
3. **Performance**: Dedicated resources, no queue wait times
4. **Security**: Network isolation, controlled environment

### Why GitOps with ArgoCD?

1. **Self-healing**: Automatic drift detection and reconciliation
2. **Auditability**: All changes tracked in Git
3. **Rollback**: Easy revert to previous configurations
4. **Declarative**: Infrastructure as code

## Integration Points

### GitHub Organization

- Org-level secrets: `RACKSPACE_SPOT_API_TOKEN`, `INFRA_GH_TOKEN`
- Runner label: `project-beta-runners`
- Auto-registration with GitHub Actions

### Other Repositories

All Project Beta repositories can use these runners by specifying:

```yaml
jobs:
  build:
    runs-on: project-beta-runners
```

## Maintenance

### Scaling

- Minimum runners: 5 (always warm)
- Maximum runners: 25 (auto-scale)
- Configuration: `argocd/applications/arc-runners.yaml`

### Updates

1. ARC controller updates: Modify `argocd/applications/arc-controller.yaml`
2. Runner image updates: Modify `argocd/applications/arc-runners.yaml`
3. ArgoCD auto-syncs changes within 3 minutes
