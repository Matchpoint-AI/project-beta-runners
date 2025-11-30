################################################################################
# Autoscaler Module - Outputs
################################################################################

output "service_name" {
  description = "Name of the Cloud Run Service"
  value       = google_cloud_run_v2_service.autoscaler.name
}

output "service_id" {
  description = "Full resource ID of the Cloud Run Service"
  value       = google_cloud_run_v2_service.autoscaler.id
}

output "service_uri" {
  description = "URI of the Cloud Run Service (webhook endpoint)"
  value       = google_cloud_run_v2_service.autoscaler.uri
}

output "webhook_url" {
  description = "URL to configure in GitHub organization webhook settings"
  value       = "${google_cloud_run_v2_service.autoscaler.uri}/webhook"
}

output "location" {
  description = "Location/region of the Cloud Run Service"
  value       = google_cloud_run_v2_service.autoscaler.location
}
