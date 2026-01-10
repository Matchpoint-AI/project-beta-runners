# Terraform Module Version Configuration
#
# This file centralizes module version management for all terragrunt configurations.
# To upgrade modules, change the version here and run `terragrunt plan` to verify.
#
# Usage in terragrunt.hcl:
#   locals {
#     source_config = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
#   }
#   terraform {
#     source = "${local.source_config.locals.tf_modules_repo}//module-name?ref=${local.source_config.locals.tf_modules_version}"
#   }

locals {
  # Module repository configuration
  # Using HTTPS for CI compatibility (SSH not configured for agents)
  tf_modules_base    = "github.com/Matchpoint-AI/spot-argocd-cloudspace.git"
  tf_modules_repo    = "git::https://${local.tf_modules_base}"

  # Centralized version pin
  # Change this to upgrade all modules at once
  tf_modules_version = "v1.1.0"
}
