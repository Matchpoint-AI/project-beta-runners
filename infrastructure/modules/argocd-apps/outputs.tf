# ArgoCD Apps Module - Outputs

output "runner_label" {
  description = "GitHub Actions runner label for workflows"
  value       = var.runner_label
}

output "runner_namespace" {
  description = "Kubernetes namespace for runner pods"
  value       = local.runner_namespace
}

output "arc_controller_namespace" {
  description = "Kubernetes namespace for ARC controller"
  value       = local.arc_namespace
}

output "scaling_config" {
  description = "Runner autoscaling configuration"
  value = {
    min = var.min_runners
    max = var.max_runners
  }
}

output "github_org" {
  description = "GitHub organization runners are registered to"
  value       = var.github_org
}

output "arc_version" {
  description = "ARC Helm chart version"
  value       = helm_release.arc_controller.version
}
