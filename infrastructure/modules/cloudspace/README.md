# Cloudspace Module

Creates a Rackspace Spot managed Kubernetes cluster and node pool.

## Usage

```hcl
module "cloudspace" {
  source = "./modules/cloudspace"

  cluster_name = "mp-runners-v3"
  region       = "us-central-dfw-1"
  server_class = "gp.vs1.large"
  min_nodes    = 2
  max_nodes    = 15
}
```

## Timing

Control plane provisioning takes **50-60 minutes**. Plan workflows accordingly.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_spot"></a> [spot](#requirement\_spot) | >= 0.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_spot"></a> [spot](#provider\_spot) | >= 0.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [spot_cloudspace.this](https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/cloudspace) | resource |
| [spot_spotnodepool.this](https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/spotnodepool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bid_price"></a> [bid\_price](#input\_bid\_price) | Bid price per node per hour in USD (must be > 0 and < 1) | `number` | `0.28` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | n/a | yes |
| <a name="input_max_nodes"></a> [max\_nodes](#input\_max\_nodes) | Maximum number of nodes in the pool | `number` | `15` | no |
| <a name="input_min_nodes"></a> [min\_nodes](#input\_min\_nodes) | Minimum number of nodes in the pool | `number` | `2` | no |
| <a name="input_region"></a> [region](#input\_region) | Rackspace Spot region | `string` | n/a | yes |
| <a name="input_server_class"></a> [server\_class](#input\_server\_class) | Node pool server class (e.g., gp.vs1.large = 4 vCPU, 15GB RAM) | `string` | `"gp.vs1.large"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudspace_name"></a> [cloudspace\_name](#output\_cloudspace\_name) | Name of the created Kubernetes cluster |
| <a name="output_node_scaling"></a> [node\_scaling](#output\_node\_scaling) | Node pool scaling configuration |
| <a name="output_nodepool_id"></a> [nodepool\_id](#output\_nodepool\_id) | ID of the node pool |
| <a name="output_region"></a> [region](#output\_region) | Region where the cluster is deployed |
| <a name="output_server_class"></a> [server\_class](#output\_server\_class) | Server class of the node pool |
<!-- END_TF_DOCS -->
