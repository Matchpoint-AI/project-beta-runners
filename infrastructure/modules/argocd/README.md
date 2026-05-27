# ArgoCD Module

Installs ArgoCD via Helm and creates a bootstrap Application that watches
the GKE-specific applications directory (app-of-apps pattern).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| helm | ~> 2.12 |
| kubectl | ~> 2.0 |

## Resources

| Name | Type |
|------|------|
| helm_release.argocd | resource |
| kubectl_manifest.bootstrap | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| argocd_chart_version | Version of the argo-cd Helm chart | `string` | `"5.51.6"` | no |
| bootstrap_app_name | Name of the bootstrap ArgoCD Application | `string` | `"gke-runners-bootstrap"` | no |
| repo_url | Git repository URL for the bootstrap Application source | `string` | n/a | yes |
| target_revision | Git branch/tag/commit for the bootstrap Application | `string` | `"main"` | no |
| applications_path | Path in the repo to the ArgoCD applications directory | `string` | `"argocd/applications-gke"` | no |
| cluster_endpoint | GKE cluster endpoint | `string` | n/a | yes |
| cluster_ca_certificate | Base64-encoded CA certificate for the cluster | `string` | n/a | yes |

## Outputs

None.
<!-- END_TF_DOCS -->
