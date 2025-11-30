################################################################################
# APIs Module - Outputs
################################################################################

output "enabled_apis" {
  description = "List of APIs that have been enabled"
  value       = [for api in google_project_service.apis : api.service]
}

output "api_services" {
  description = "Map of API service resources for dependency management in other modules"
  value       = google_project_service.apis
}
