# Cloudspace Module - Imports
#
# These import blocks handle adopting existing resources that were created
# outside of this Terraform configuration or by a previous configuration.
# Import blocks are idempotent - they only run if the resource isn't in state.

# Import existing cloudspace by name
import {
  to = spot_cloudspace.this
  id = var.cluster_name
}
