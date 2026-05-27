output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.runners.name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster API server"
  value       = google_container_cluster.runners.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster"
  value       = google_container_cluster.runners.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "deployer_service_account_email" {
  description = "Email of the deployer service account for CI/CD"
  value       = google_service_account.deployer.email
}
