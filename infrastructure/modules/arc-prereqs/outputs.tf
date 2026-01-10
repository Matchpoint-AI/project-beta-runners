# ARC Prerequisites Module - Outputs

output "arc_namespace" {
  description = "Namespace for ARC controller"
  value       = kubernetes_namespace_v1.arc_systems.metadata[0].name
}

output "runner_namespace" {
  description = "Namespace for runner pods"
  value       = kubernetes_namespace_v1.arc_runners.metadata[0].name
}

output "github_secret_name" {
  description = "Name of the GitHub token secret"
  value       = kubernetes_secret_v1.github_token.metadata[0].name
}

output "github_secret_namespace" {
  description = "Namespace containing the GitHub token secret"
  value       = kubernetes_secret_v1.github_token.metadata[0].namespace
}
