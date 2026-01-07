# ArgoCD Apps Module
#
# Creates the bootstrap ArgoCD Application that manages ARC deployment.
# This follows the "App of Apps" GitOps pattern:
# - Terraform creates namespaces and secrets
# - Terraform applies bootstrap Application CRD
# - ArgoCD syncs and manages ARC controller + runners from repo manifests

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
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

locals {
  arc_namespace    = "arc-systems"
  runner_namespace = "arc-runners"
  argocd_namespace = "argocd"
}

# -----------------------------------------------------------------------------
# ARC System Namespace (for controller)
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = local.arc_namespace
  }
}

# -----------------------------------------------------------------------------
# ARC Runners Namespace (for runner pods)
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = local.runner_namespace
  }
}

# -----------------------------------------------------------------------------
# GitHub Token Secret for Runner Registration
# Uses PAT with admin:org and manage_runners:org scopes
# This must exist before ArgoCD syncs the runner Application
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
# Bootstrap ArgoCD Application
# This creates an Application that points to argocd/applications/ in this repo.
# ArgoCD will then sync and manage:
# - arc-controller (ARC controller Helm chart)
# - arc-runners (ARC runner scale set Helm chart)
# -----------------------------------------------------------------------------
resource "kubernetes_manifest" "bootstrap_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "project-beta-runners-bootstrap"
      namespace = local.argocd_namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = "argocd/applications"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = local.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    kubernetes_namespace.arc_systems,
    kubernetes_namespace.arc_runners,
    kubernetes_secret.github_token
  ]
}
