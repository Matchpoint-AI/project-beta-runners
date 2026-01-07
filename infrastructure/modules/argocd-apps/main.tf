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
# GitHub Token Secret for Runner Registration
# Uses PAT with admin:org and manage_runners:org scopes
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "github_token" {
  metadata {
    name      = "arc-org-github-secret"
    namespace = local.runner_namespace
  }

  data = {
    github_token = var.github_token
  }

  depends_on = [kubernetes_namespace.arc_runners]
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

  # All configuration via values block for helm provider compatibility
  values = [yamlencode({
    # GitHub configuration
    githubConfigUrl    = "https://github.com/${var.github_org}"
    githubConfigSecret = kubernetes_secret.github_token.metadata[0].name

    # Runner label (this is what workflows use: runs-on: project-beta-runners)
    runnerScaleSetName = var.runner_label

    # Autoscaling
    minRunners = var.min_runners
    maxRunners = var.max_runners

    # Controller namespace reference
    controllerServiceAccount = {
      namespace = local.arc_namespace
      name      = "arc-controller-gha-rs-controller"
    }

    # Runner pod template with DinD sidecar
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
            name            = "dind"
            image           = "docker:24-dind"
            securityContext = { privileged = true }
            env             = [{ name = "DOCKER_TLS_CERTDIR", value = "" }]
            volumeMounts    = [{ name = "dind-storage", mountPath = "/var/lib/docker" }]
          }
        ]
        volumes = [{ name = "dind-storage", emptyDir = { sizeLimit = "20Gi" } }]
      }
    }
  })]

  depends_on = [
    helm_release.arc_controller,
    kubernetes_namespace.arc_runners,
    kubernetes_secret.github_token
  ]
}
