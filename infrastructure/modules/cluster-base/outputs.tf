# Cluster Base Module - Outputs

output "kubeconfig_raw" {
  description = "Raw kubeconfig YAML for the cluster"
  value       = data.spot_kubeconfig.this.raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = local.kubeconfig["clusters"][0]["cluster"]["server"]
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_release_name" {
  description = "Helm release name for ArgoCD"
  value       = helm_release.argocd.name
}

output "argocd_chart_version" {
  description = "Installed ArgoCD Helm chart version"
  value       = helm_release.argocd.version
}
