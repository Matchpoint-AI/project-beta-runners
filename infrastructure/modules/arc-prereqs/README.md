# ARC Prerequisites Module

Local module that creates Kubernetes resources required for GitHub Actions Runner Controller (ARC).

## Overview

This module provisions:
- **arc-systems namespace** - For the ARC controller
- **arc-runners namespace** - For runner pods
- **GitHub token secret** - For runner registration with GitHub

This is a **local** module specific to project-beta-runners. Generic infrastructure modules are sourced from [spot-argocd-cloudspace](https://github.com/Matchpoint-AI/spot-argocd-cloudspace).

## Usage

```hcl
module "arc_prereqs" {
  source = "../modules/arc-prereqs"

  cluster_endpoint       = dependency.cloudspace.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.cloudspace.outputs.cluster_ca_certificate
  cluster_token          = dependency.cloudspace.outputs.cluster_token

  github_token = var.github_token
}
```

## GitHub Token Requirements

The GitHub PAT requires these scopes:
- `admin:org` - For organization-level runner management
- `manage_runners:org` - For creating/deleting runners

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_endpoint | Kubernetes API server endpoint | string | - | yes |
| cluster_ca_certificate | Base64-encoded cluster CA certificate | string | - | yes |
| cluster_token | Authentication token for the cluster | string | - | yes |
| github_token | GitHub PAT for runner registration | string | - | yes |
| arc_namespace | Namespace for ARC controller | string | `"arc-systems"` | no |
| arc_runners_namespace | Namespace for runner pods | string | `"arc-runners"` | no |
| github_secret_name | Name of the K8s secret for GitHub token | string | `"arc-org-github-secret"` | no |

## Outputs

| Name | Description |
|------|-------------|
| arc_namespace | Namespace for ARC controller |
| runner_namespace | Namespace for runner pods |
| github_secret_name | Name of the GitHub token secret |
| github_secret_namespace | Namespace containing the secret |
