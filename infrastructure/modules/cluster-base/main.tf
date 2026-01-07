# Cluster Base Module
#
# Fetches kubeconfig and installs ArgoCD on the cluster.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = ">= 0.1.0"
    }
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
# Kubeconfig Data Source
# -----------------------------------------------------------------------------
data "spot_kubeconfig" "this" {
  cloudspace_name = var.cloudspace_name
}

locals {
  kubeconfig = yamldecode(data.spot_kubeconfig.this.raw)
}

# -----------------------------------------------------------------------------
# Kubernetes Provider Configuration
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = local.kubeconfig["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(local.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
  token                  = local.kubeconfig["users"][0]["user"]["token"]
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig["clusters"][0]["cluster"]["server"]
    cluster_ca_certificate = base64decode(local.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
    token                  = local.kubeconfig["users"][0]["user"]["token"]
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
