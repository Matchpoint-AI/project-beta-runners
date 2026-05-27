# GKE Cluster Module

Provisions a zonal GKE cluster with a Spot node pool for GitHub Actions runners,
plus the deployer service account and WIF binding for CI/CD.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| google | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| google_container_cluster.runners | resource |
| google_container_node_pool.spot | resource |
| google_service_account.deployer | resource |
| google_service_account_iam_member.deployer_wif | resource |
| google_project_iam_member.deployer_container_admin | resource |
| google_project_iam_member.deployer_secret_accessor | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| cluster_name | Name of the GKE cluster | `string` | n/a | yes |
| zone | GCP zone for the zonal cluster | `string` | n/a | yes |
| machine_type | Machine type for the Spot node pool | `string` | `"e2-standard-4"` | no |
| disk_size_gb | Boot disk size in GB for each node | `number` | `50` | no |
| min_node_count | Minimum number of nodes in the Spot pool | `number` | `0` | no |
| max_node_count | Maximum number of nodes in the Spot pool | `number` | `25` | no |
| wif_pool_name | Full resource name of the WIF pool | `string` | n/a | yes |
| github_repo | GitHub repository in org/repo format for WIF binding | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | Name of the GKE cluster |
| cluster_endpoint | Endpoint for the GKE cluster API server |
| cluster_ca_certificate | Base64-encoded CA certificate for the cluster |
| deployer_service_account_email | Email of the deployer service account for CI/CD |
<!-- END_TF_DOCS -->
