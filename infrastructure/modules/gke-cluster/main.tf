# GKE Cluster + Spot Node Pool for GitHub Actions Runners
#
# Provisions a zonal GKE cluster (free-tier control plane) with a single
# Spot node pool that autoscales 0-25 for runner workloads.

resource "google_container_cluster" "runners" {
  name     = var.cluster_name
  location = var.zone
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  deletion_protection = false
}

# Renamed from "spot" -> "ondemand". Phase 1 ships on regular CPU quota
# because PREEMPTIBLE_CPUS is at 0 across the project (GCP quota migration in flight).
# Flip spot = true and rename back once Spot quota is available; cost delta at
# scale-to-zero workloads is single-digit dollars/mo.
resource "google_container_node_pool" "ondemand" {
  name     = "ondemand-runners"
  cluster  = google_container_cluster.runners.name
  location = var.zone
  project  = var.project_id

  node_config {
    machine_type = var.machine_type
    spot         = false
    disk_size_gb = var.disk_size_gb
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    taint {
      key    = "ondemand-runners"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      workload = "github-runner"
      compute  = "ondemand"
    }
  }

  autoscaling {
    min_node_count  = var.min_node_count
    max_node_count  = var.max_node_count
    location_policy = "ANY"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service account for CI/CD pipeline (terragrunt apply via GitHub Actions)
resource "google_service_account" "deployer" {
  account_id   = "gke-runners-deployer"
  display_name = "GKE Runners Deployer (CI/CD)"
  project      = var.project_id
}

# WIF binding: allow GitHub Actions to impersonate the deployer SA
resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.wif_pool_name}/attribute.repository/${var.github_repo}"
}

# Grant deployer SA the permissions needed to manage GKE + ArgoCD
resource "google_project_iam_member" "deployer_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "deployer_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}
