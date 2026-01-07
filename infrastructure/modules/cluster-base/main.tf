# Cluster Base Module
#
# Installs ArgoCD on the cluster using kubeconfig from cloudspace module.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Kubernetes Provider Configuration
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = var.cluster_token
}

provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = var.cluster_token
  }
}

# -----------------------------------------------------------------------------
# ArgoCD Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# -----------------------------------------------------------------------------
# ArgoCD Installation via Helm
# -----------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  wait    = true
  timeout = 600 # 10 minutes

  # Core settings
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Disable dex (we use GitHub App auth)
  set {
    name  = "dex.enabled"
    value = "false"
  }

  # Enable repo server for GitOps
  set {
    name  = "repoServer.replicas"
    value = "1"
  }

  depends_on = [kubernetes_namespace.argocd]
}
