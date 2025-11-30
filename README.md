# Project Beta Runners

Infrastructure as Code for Cloud Run-based GitHub Actions self-hosted runners serving the project-beta ecosystem.

## Overview

This repository contains the Terraform modules and supporting infrastructure to deploy auto-scaling GitHub Actions self-hosted runners on Google Cloud Run. These runners serve:

- [project-beta](https://github.com/Matchpoint-AI/project-beta) (Terraform/Infrastructure)
- [project-beta-api](https://github.com/Matchpoint-AI/project-beta-api) (Backend API)
- [project-beta-frontend](https://github.com/Matchpoint-AI/project-beta-frontend) (Frontend Application)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ Cloud Run       │    │ Secret Manager  │                     │
│  │ Worker Pool     │◄───│ (GitHub App)    │                     │
│  │ (0-N scaling)   │    └─────────────────┘                     │
│  └────────┬────────┘              ▲                             │
│           │                       │                             │
│  ┌────────▼────────┐    ┌────────┴────────┐                     │
│  │ Artifact        │    │ Cloud Run       │                     │
│  │ Registry        │    │ Autoscaler Fn   │◄── webhook_job      │
│  │ (Runner Image)  │    └─────────────────┘    events           │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
.
├── terraform/
│   ├── modules/
│   │   ├── worker-pool/      # Cloud Run worker pool
│   │   ├── autoscaler/       # Autoscaler Cloud Run function
│   │   ├── secrets/          # Secret Manager configuration
│   │   └── iam/              # Service accounts & IAM bindings
│   └── environments/
│       ├── dev/              # Development environment
│       └── prod/             # Production environment
├── worker/
│   ├── Dockerfile            # Runner container image
│   └── entrypoint.sh         # Runner lifecycle script
├── autoscaler/
│   ├── main.py               # Webhook handler
│   └── requirements.txt      # Python dependencies
├── cloudbuild/
│   ├── deploy-infra.yaml     # Infrastructure deployment
│   └── build-worker.yaml     # Worker image build
└── scripts/
    └── setup-github-app.sh   # GitHub App creation helper
```

## Prerequisites

- Google Cloud Project with billing enabled
- Terraform >= 1.5.0
- gcloud CLI configured
- GitHub Organization admin access

## Quick Start

See individual issue tickets for detailed implementation steps.

## Related Issues

Track implementation progress via the GitHub Issues in this repository.
