# State 2: Cluster Base - Outputs
#
# These outputs are consumed by State 3 (argocd-apps) via dependency blocks.

output "kubeconfig_raw" {
  description = "Raw kubeconfig YAML for the cluster"
  value       = data.rackspace-spot_kubeconfig.runners.raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = yamldecode(data.rackspace-spot_kubeconfig.runners.raw)["clusters"][0]["cluster"]["server"]
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_release_name" {
  description = "Helm release name for ArgoCD"
  value       = helm_release.argocd.name
}

output "argocd_version" {
  description = "Installed ArgoCD Helm chart version"
  value       = helm_release.argocd.version
}
