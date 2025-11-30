################################################################################
# Docker Host Module - Outputs
################################################################################

output "internal_ip" {
  description = "Internal IP address of the Docker host"
  value       = google_compute_instance.docker_host.network_interface[0].network_ip
}

output "docker_host_url" {
  description = "URL for DOCKER_HOST environment variable"
  value       = "tcp://${google_compute_instance.docker_host.network_interface[0].network_ip}:2375"
}

output "instance_name" {
  description = "Name of the Docker host instance"
  value       = google_compute_instance.docker_host.name
}

output "instance_self_link" {
  description = "Self-link of the Docker host instance"
  value       = google_compute_instance.docker_host.self_link
}

output "zone" {
  description = "Zone where the Docker host is deployed"
  value       = google_compute_instance.docker_host.zone
}
