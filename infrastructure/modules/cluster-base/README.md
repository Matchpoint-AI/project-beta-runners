# Cluster Base Module

Fetches kubeconfig from an existing Rackspace Spot cluster and installs ArgoCD.

## Usage

```hcl
module "cluster_base" {
  source = "./modules/cluster-base"

  cloudspace_name      = "mp-runners-v3"
  argocd_chart_version = "5.51.6"
}
```

## Dependencies

This module requires the cloudspace to be fully provisioned first.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23.0 |
| <a name="requirement_rackspace-spot"></a> [rackspace-spot](#requirement\_rackspace-spot) | >= 0.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.11.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23.0 |
| <a name="provider_rackspace-spot"></a> [rackspace-spot](#provider\_rackspace-spot) | >= 0.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.argocd](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [rackspace-spot_kubeconfig.this](https://registry.terraform.io/providers/rackerlabs/rackspace-spot/latest/docs/data-sources/kubeconfig) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argocd_chart_version"></a> [argocd\_chart\_version](#input\_argocd\_chart\_version) | ArgoCD Helm chart version | `string` | `"5.51.6"` | no |
| <a name="input_cloudspace_name"></a> [cloudspace\_name](#input\_cloudspace\_name) | Name of the Kubernetes cluster | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd_chart_version"></a> [argocd\_chart\_version](#output\_argocd\_chart\_version) | Installed ArgoCD Helm chart version |
| <a name="output_argocd_namespace"></a> [argocd\_namespace](#output\_argocd\_namespace) | Namespace where ArgoCD is installed |
| <a name="output_argocd_release_name"></a> [argocd\_release\_name](#output\_argocd\_release\_name) | Helm release name for ArgoCD |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API server endpoint |
| <a name="output_kubeconfig_raw"></a> [kubeconfig\_raw](#output\_kubeconfig\_raw) | Raw kubeconfig YAML for the cluster |
<!-- END_TF_DOCS -->
