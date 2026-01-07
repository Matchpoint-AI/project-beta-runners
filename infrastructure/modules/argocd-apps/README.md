# ArgoCD Apps Module

Deploys GitHub Actions Runner Controller (ARC) and runner ScaleSet with Docker-in-Docker support.

## Usage

```hcl
module "argocd_apps" {
  source = "./modules/argocd-apps"

  runner_label               = "project-beta-runners"
  min_runners                = 5
  max_runners                = 25
  github_org                 = "Matchpoint-AI"
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
}
```

## Runner Configuration

- **DinD Sidecar**: `docker:24-dind` with 20GB storage
- **DOCKER_HOST**: `tcp://localhost:2375`
- **Runner UID**: 1000 (non-root)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.11.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.arc_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.arc_runners](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.arc_runners](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.arc_systems](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.github_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_arc_version"></a> [arc\_version](#input\_arc\_version) | ARC Helm chart version | `string` | `"0.9.3"` | no |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organization for runner registration | `string` | `"Matchpoint-AI"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub PAT for runner registration (requires admin:org and manage\_runners:org scopes) | `string` | n/a | yes |
| <a name="input_max_runners"></a> [max\_runners](#input\_max\_runners) | Maximum number of runners under load | `number` | `25` | no |
| <a name="input_min_runners"></a> [min\_runners](#input\_min\_runners) | Minimum number of warm runners | `number` | `5` | no |
| <a name="input_runner_label"></a> [runner\_label](#input\_runner\_label) | GitHub Actions runner label | `string` | `"project-beta-runners"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arc_controller_namespace"></a> [arc\_controller\_namespace](#output\_arc\_controller\_namespace) | Kubernetes namespace for ARC controller |
| <a name="output_arc_version"></a> [arc\_version](#output\_arc\_version) | ARC Helm chart version |
| <a name="output_github_org"></a> [github\_org](#output\_github\_org) | GitHub organization runners are registered to |
| <a name="output_runner_label"></a> [runner\_label](#output\_runner\_label) | GitHub Actions runner label for workflows |
| <a name="output_runner_namespace"></a> [runner\_namespace](#output\_runner\_namespace) | Kubernetes namespace for runner pods |
| <a name="output_scaling_config"></a> [scaling\_config](#output\_scaling\_config) | Runner autoscaling configuration |
<!-- END_TF_DOCS -->
