# ArgoCD Apps Module
#
# Deploys ARC controller and runner ScaleSet.

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

locals {
  arc_namespace    = "arc-systems"
  runner_namespace = "arc-runners"
}

# -----------------------------------------------------------------------------
# ARC System Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = local.arc_namespace
  }
}

# -----------------------------------------------------------------------------
# ARC Runners Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = local.runner_namespace
  }
}

# -----------------------------------------------------------------------------
# GitHub App Secret for Runner Registration
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "github_app" {
  metadata {
    name      = "github-app-secret"
    namespace = local.arc_namespace
  }

  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  }

  depends_on = [kubernetes_namespace.arc_systems]
}

# -----------------------------------------------------------------------------
# ARC Controller (gha-runner-scale-set-controller)
# -----------------------------------------------------------------------------
resource "helm_release" "arc_controller" {
  name       = "arc-controller"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = var.arc_version
  namespace  = local.arc_namespace
  
  wait    = true
  timeout = 300

  depends_on = [kubernetes_namespace.arc_systems]
}

# -----------------------------------------------------------------------------
# ARC Runner ScaleSet
# -----------------------------------------------------------------------------
resource "helm_release" "arc_runners" {
  name       = "arc-runners"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = var.arc_version
  namespace  = local.runner_namespace
  
  wait    = true
  timeout = 300

  # GitHub configuration
  set {
    name  = "githubConfigUrl"
    value = "https://github.com/${var.github_org}"
  }

  set {
    name  = "githubConfigSecret"
    value = kubernetes_secret.github_app.metadata[0].name
  }

  # Runner label (this is what workflows use: runs-on: project-beta-runners)
  set {
    name  = "runnerScaleSetName"
    value = var.runner_label
  }

  # Autoscaling
  set {
    name  = "minRunners"
    value = var.min_runners
  }

  set {
    name  = "maxRunners"
    value = var.max_runners
  }

  # Controller namespace reference
  set {
    name  = "controllerServiceAccount.namespace"
    value = local.arc_namespace
  }

  set {
    name  = "controllerServiceAccount.name"
    value = "arc-controller-gha-rs-controller"
  }

  # Runner pod template with DinD sidecar
  values = [yamlencode({
    template = {
      spec = {
        containers = [
          {
            name  = "runner"
            image = "ghcr.io/actions/actions-runner:latest"
            env = [
              { name = "DOCKER_HOST", value = "tcp://localhost:2375" },
              { name = "DOCKER_API_VERSION", value = "1.43" }
            ]
            securityContext = { runAsUser = 1000 }
          },
          {
            name  = "dind"
            image = "docker:24-dind"
            securityContext = { privileged = true }
            env = [{ name = "DOCKER_TLS_CERTDIR", value = "" }]
            volumeMounts = [{ name = "dind-storage", mountPath = "/var/lib/docker" }]
          }
        ]
        volumes = [{ name = "dind-storage", emptyDir = { sizeLimit = "20Gi" } }]
      }
    }
  })]

  depends_on = [
    helm_release.arc_controller,
    kubernetes_namespace.arc_runners,
    kubernetes_secret.github_app
  ]
}
