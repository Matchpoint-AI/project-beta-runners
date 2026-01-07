# State 2: Cluster Base
#
# Fetches kubeconfig and installs ArgoCD on the cluster.

# -----------------------------------------------------------------------------
# Kubeconfig Data Source
# -----------------------------------------------------------------------------
# This is safe because State 1 must be applied first (via Terragrunt dependency)
data "rackspace-spot_kubeconfig" "runners" {
  cloudspace_name = var.cloudspace_name
}

# -----------------------------------------------------------------------------
# Kubernetes Provider Configuration
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = yamldecode(data.rackspace-spot_kubeconfig.runners.raw)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(data.rackspace-spot_kubeconfig.runners.raw)["clusters"][0]["cluster"]["certificate-authority-data"])
  token                  = yamldecode(data.rackspace-spot_kubeconfig.runners.raw)["users"][0]["user"]["token"]
}

provider "helm" {
  kubernetes {
    host                   = yamldecode(data.rackspace-spot_kubeconfig.runners.raw)["clusters"][0]["cluster"]["server"]
    cluster_ca_certificate = base64decode(yamldecode(data.rackspace-spot_kubeconfig.runners.raw)["clusters"][0]["cluster"]["certificate-authority-data"])
    token                  = yamldecode(data.rackspace-spot_kubeconfig.runners.raw)["users"][0]["user"]["token"]
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
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  
  # Wait for ArgoCD to be ready
  wait    = true
  timeout = 600  # 10 minutes
  
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
