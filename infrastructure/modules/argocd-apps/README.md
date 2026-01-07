# ArgoCD Apps Module

Creates the bootstrap ArgoCD Application that manages ARC deployment using the App-of-Apps GitOps pattern.

## Architecture

```
Terraform (Stage 3)           ArgoCD                     Kubernetes
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ - Namespaces    │────▶│ Bootstrap App   │────▶│ arc-systems/    │
│ - GitHub Secret │     │ (syncs repo)    │     │ arc-runners/    │
│ - Bootstrap App │     └─────────────────┘     └─────────────────┘
└─────────────────┘
```

This module:
1. Creates `arc-systems` and `arc-runners` namespaces
2. Creates the GitHub token secret for runner registration
3. Applies a bootstrap ArgoCD Application CRD

ArgoCD then syncs `argocd/applications/` from this repo and manages:
- ARC Controller (Helm chart)
- ARC Runner ScaleSet (Helm chart)

## Usage

```hcl
module "argocd_apps" {
  source = "./modules/argocd-apps"

  github_token    = var.github_token  # PAT with admin:org, manage_runners:org
  repo_url        = "https://github.com/Matchpoint-AI/project-beta-runners"
  target_revision = "main"
}
```

## Modifying Runner Configuration

Since runners are managed by ArgoCD (not Terraform), changes are made via Git:

```bash
# Edit argocd/applications/arc-runners.yaml
# Commit and push to main
# ArgoCD auto-syncs
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_manifest.bootstrap_application](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.arc_runners](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.arc_systems](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.github_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub PAT for runner registration (requires admin:org and manage\_runners:org scopes) | `string` | n/a | yes |
| <a name="input_repo_url"></a> [repo\_url](#input\_repo\_url) | Git repository URL for ArgoCD to sync from | `string` | `"https://github.com/Matchpoint-AI/project-beta-runners"` | no |
| <a name="input_target_revision"></a> [target\_revision](#input\_target\_revision) | Git branch/tag/commit for ArgoCD to sync | `string` | `"main"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arc_controller_namespace"></a> [arc\_controller\_namespace](#output\_arc\_controller\_namespace) | Kubernetes namespace for ARC controller |
| <a name="output_argocd_sync_source"></a> [argocd\_sync\_source](#output\_argocd\_sync\_source) | ArgoCD sync source information |
| <a name="output_bootstrap_application_name"></a> [bootstrap\_application\_name](#output\_bootstrap\_application\_name) | Name of the bootstrap ArgoCD Application |
| <a name="output_runner_namespace"></a> [runner\_namespace](#output\_runner\_namespace) | Kubernetes namespace for runner pods |
<!-- END_TF_DOCS -->
