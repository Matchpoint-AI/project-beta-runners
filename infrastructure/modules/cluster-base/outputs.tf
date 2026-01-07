# Cluster Base Module - Outputs

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = var.cluster_endpoint
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "argocd_release_name" {
  description = "Helm release name for ArgoCD"
  value       = helm_release.argocd.name
}

output "argocd_chart_version" {
  description = "Installed ArgoCD Helm chart version"
  value       = helm_release.argocd.version
}
