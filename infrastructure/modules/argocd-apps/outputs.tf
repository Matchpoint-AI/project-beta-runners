# ArgoCD Apps Module - Outputs

output "bootstrap_application_name" {
  description = "Name of the bootstrap ArgoCD Application"
  value       = kubernetes_manifest.bootstrap_application.manifest.metadata.name
}

output "runner_namespace" {
  description = "Kubernetes namespace for runner pods"
  value       = local.runner_namespace
}

output "arc_controller_namespace" {
  description = "Kubernetes namespace for ARC controller"
  value       = local.arc_namespace
}

output "argocd_sync_source" {
  description = "ArgoCD sync source information"
  value = {
    repo_url        = var.repo_url
    target_revision = var.target_revision
    path            = "argocd/applications"
  }
}
