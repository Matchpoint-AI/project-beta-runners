################################################################################
# Secrets Module - Outputs
################################################################################

#------------------------------------------------------------------------------
# Secret IDs (for reference in other modules)
#------------------------------------------------------------------------------

output "github_app_id_secret_id" {
  description = "Secret Manager secret ID for GitHub App ID"
  value       = google_secret_manager_secret.github_app_id.secret_id
}

output "github_app_installation_id_secret_id" {
  description = "Secret Manager secret ID for GitHub App Installation ID"
  value       = google_secret_manager_secret.github_app_installation_id.secret_id
}

output "github_app_private_key_secret_id" {
  description = "Secret Manager secret ID for GitHub App Private Key"
  value       = google_secret_manager_secret.github_app_private_key.secret_id
}

output "webhook_secret_id" {
  description = "Secret Manager secret ID for webhook secret"
  value       = google_secret_manager_secret.webhook_secret.secret_id
}

#------------------------------------------------------------------------------
# Secret Names (fully qualified for Cloud Run env var references)
#------------------------------------------------------------------------------

output "github_app_id_secret_name" {
  description = "Full resource name of the GitHub App ID secret"
  value       = google_secret_manager_secret.github_app_id.name
}

output "github_app_installation_id_secret_name" {
  description = "Full resource name of the GitHub App Installation ID secret"
  value       = google_secret_manager_secret.github_app_installation_id.name
}

output "github_app_private_key_secret_name" {
  description = "Full resource name of the GitHub App Private Key secret"
  value       = google_secret_manager_secret.github_app_private_key.name
}

output "webhook_secret_name" {
  description = "Full resource name of the webhook secret"
  value       = google_secret_manager_secret.webhook_secret.name
}

#------------------------------------------------------------------------------
# Webhook Secret Version (for initial GitHub webhook configuration)
#------------------------------------------------------------------------------

output "webhook_secret_version" {
  description = "Version resource name of the auto-generated webhook secret"
  value       = google_secret_manager_secret_version.webhook_secret.name
}
