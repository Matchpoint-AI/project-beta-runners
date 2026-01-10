## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_spot"></a> [spot](#requirement\_spot) | >= 0.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.5 |
| <a name="provider_spot"></a> [spot](#provider\_spot) | 0.1.4 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [spot_cloudspace.primary](https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/cloudspace) | resource |
| [spot_cloudspace.secondary](https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/cloudspace) | resource |
| [spot_spotnodepool.primary](https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/spotnodepool) | resource |
| [spot_spotnodepool.secondary](https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/spotnodepool) | resource |
| [terraform_data.ha_gate](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.setup_spotctl_config](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.wait_for_cluster](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.wait_for_nodepool](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.wait_for_secondary_cluster](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.wait_for_secondary_nodepool](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [external_external.kubeconfig](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.secondary_kubeconfig](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bid_price"></a> [bid\_price](#input\_bid\_price) | Bid price per node per hour in USD. Target 70-75% of on-demand equivalent for reliability. Safe to change (no nodepool replacement). | `number` | `0.35` | no |
| <a name="input_cloudspace_poll_interval"></a> [cloudspace\_poll\_interval](#input\_cloudspace\_poll\_interval) | Seconds between cloudspace status polling attempts | `number` | `30` | no |
| <a name="input_cloudspace_poll_max_attempts"></a> [cloudspace\_poll\_max\_attempts](#input\_cloudspace\_poll\_max\_attempts) | Maximum polling attempts for cloudspace to become ready (30s intervals) | `number` | `240` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the primary Kubernetes cluster | `string` | n/a | yes |
| <a name="input_enable_ha"></a> [enable\_ha](#input\_enable\_ha) | Enable High Availability mode with dual cloudspaces. When enabled, both primary and secondary cloudspaces must be healthy before HA is active. | `bool` | `false` | no |
| <a name="input_max_nodes"></a> [max\_nodes](#input\_max\_nodes) | Maximum number of nodes in the pool | `number` | `30` | no |
| <a name="input_min_nodes"></a> [min\_nodes](#input\_min\_nodes) | Minimum number of nodes in the pool | `number` | `4` | no |
| <a name="input_nodepool_poll_interval"></a> [nodepool\_poll\_interval](#input\_nodepool\_poll\_interval) | Seconds between nodepool status polling attempts | `number` | `30` | no |
| <a name="input_nodepool_poll_max_attempts"></a> [nodepool\_poll\_max\_attempts](#input\_nodepool\_poll\_max\_attempts) | Maximum polling attempts for nodepool to become ready (30s intervals) | `number` | `60` | no |
| <a name="input_rackspace_org"></a> [rackspace\_org](#input\_rackspace\_org) | Rackspace Spot organization ID for spotctl | `string` | `"matchpoint-ai"` | no |
| <a name="input_rackspace_spot_token"></a> [rackspace\_spot\_token](#input\_rackspace\_spot\_token) | Rackspace Spot API token | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Rackspace Spot region | `string` | n/a | yes |
| <a name="input_secondary_cluster_name"></a> [secondary\_cluster\_name](#input\_secondary\_cluster\_name) | Name of the secondary Kubernetes cluster (required when enable\_ha=true) | `string` | `""` | no |
| <a name="input_secondary_region"></a> [secondary\_region](#input\_secondary\_region) | Rackspace Spot region for secondary cloudspace (required when enable\_ha=true) | `string` | `""` | no |
| <a name="input_secondary_server_class"></a> [secondary\_server\_class](#input\_secondary\_server\_class) | Node pool server class for secondary cloudspace. Should match primary for balanced HA. | `string` | `""` | no |
| <a name="input_server_class"></a> [server\_class](#input\_server\_class) | Node pool server class. WARNING: Changing forces nodepool destruction (5-10 min outage)! | `string` | `"gp.vs1.xlarge-dfw"` | no |
| <a name="input_spotctl_version"></a> [spotctl\_version](#input\_spotctl\_version) | Version of spotctl CLI to install if not present | `string` | `"v0.1.1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudspace_name"></a> [cloudspace\_name](#output\_cloudspace\_name) | Name of the primary Kubernetes cluster |
| <a name="output_cloudspace_status"></a> [cloudspace\_status](#output\_cloudspace\_status) | Current primary cloudspace status from spotctl |
| <a name="output_cloudspaces"></a> [cloudspaces](#output\_cloudspaces) | Map of all cloudspaces for multi-cluster operations |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Base64-encoded primary cluster CA certificate |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Primary Kubernetes API server endpoint |
| <a name="output_cluster_token"></a> [cluster\_token](#output\_cluster\_token) | Authentication token for the primary cluster |
| <a name="output_ha_enabled"></a> [ha\_enabled](#output\_ha\_enabled) | Whether HA mode is enabled |
| <a name="output_ha_status"></a> [ha\_status](#output\_ha\_status) | HA status information including both cloudspaces |
| <a name="output_kubeconfig_raw"></a> [kubeconfig\_raw](#output\_kubeconfig\_raw) | Raw kubeconfig YAML for primary cluster (fetched fresh via spotctl) |
| <a name="output_node_scaling"></a> [node\_scaling](#output\_node\_scaling) | Node pool scaling configuration |
| <a name="output_nodepool_name"></a> [nodepool\_name](#output\_nodepool\_name) | Name of the primary node pool |
| <a name="output_region"></a> [region](#output\_region) | Region where the primary cluster is deployed |
| <a name="output_secondary_cloudspace_name"></a> [secondary\_cloudspace\_name](#output\_secondary\_cloudspace\_name) | Name of the secondary Kubernetes cluster (HA mode only) |
| <a name="output_secondary_cluster_ca_certificate"></a> [secondary\_cluster\_ca\_certificate](#output\_secondary\_cluster\_ca\_certificate) | Base64-encoded secondary cluster CA certificate (HA mode only) |
| <a name="output_secondary_cluster_endpoint"></a> [secondary\_cluster\_endpoint](#output\_secondary\_cluster\_endpoint) | Secondary Kubernetes API server endpoint (HA mode only) |
| <a name="output_secondary_cluster_token"></a> [secondary\_cluster\_token](#output\_secondary\_cluster\_token) | Authentication token for the secondary cluster (HA mode only) |
| <a name="output_secondary_kubeconfig_raw"></a> [secondary\_kubeconfig\_raw](#output\_secondary\_kubeconfig\_raw) | Raw kubeconfig YAML for secondary cluster (HA mode only) |
| <a name="output_secondary_nodepool_name"></a> [secondary\_nodepool\_name](#output\_secondary\_nodepool\_name) | Name of the secondary node pool (HA mode only) |
| <a name="output_secondary_region"></a> [secondary\_region](#output\_secondary\_region) | Region of the secondary cluster (HA mode only) |
| <a name="output_server_class"></a> [server\_class](#output\_server\_class) | Server class of the primary node pool |
