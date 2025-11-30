################################################################################
# IAM Module - Outputs
################################################################################

#------------------------------------------------------------------------------
# Runner Service Account
#------------------------------------------------------------------------------

output "runner_service_account_email" {
  description = "Email of the runner service account"
  value       = google_service_account.runner.email
}

output "runner_service_account_id" {
  description = "Fully qualified ID of the runner service account"
  value       = google_service_account.runner.id
}

output "runner_service_account_name" {
  description = "Name of the runner service account (for IAM bindings)"
  value       = google_service_account.runner.name
}

#------------------------------------------------------------------------------
# Autoscaler Service Account
#------------------------------------------------------------------------------

output "autoscaler_service_account_email" {
  description = "Email of the autoscaler service account"
  value       = google_service_account.autoscaler.email
}

output "autoscaler_service_account_id" {
  description = "Fully qualified ID of the autoscaler service account"
  value       = google_service_account.autoscaler.id
}

output "autoscaler_service_account_name" {
  description = "Name of the autoscaler service account (for IAM bindings)"
  value       = google_service_account.autoscaler.name
}

#------------------------------------------------------------------------------
# Deployer Service Account
#------------------------------------------------------------------------------

output "deployer_service_account_email" {
  description = "Email of the deployer service account"
  value       = google_service_account.deployer.email
}

output "deployer_service_account_id" {
  description = "Fully qualified ID of the deployer service account"
  value       = google_service_account.deployer.id
}

output "deployer_service_account_name" {
  description = "Name of the deployer service account (for IAM bindings)"
  value       = google_service_account.deployer.name
}
