# Terraform Module Version Configuration
#
# This file centralizes module version management for all terragrunt configurations.
# To upgrade modules, change the version here and run `terragrunt plan` to verify.
#
# Usage in terragrunt.hcl:
#   locals {
#     versions = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
#   }
#   terraform {
#     source = "${local.versions.locals.remote_modules}/cloudspace?ref=${local.versions.locals.modules_version}"
#   }

locals {
  # Remote modules from spot-argocd-cloudspace repository
  # v4.1.0: Provider config via terragrunt generate (fixes CI connection issues)
  remote_modules  = "git::https://github.com/Matchpoint-AI/spot-argocd-cloudspace.git"
  modules_version = "v4.1.0"
}
