################################################################################
# Worker Pool Module - Outputs
################################################################################

output "job_name" {
  description = "Name of the Cloud Run Job"
  value       = google_cloud_run_v2_job.runner.name
}

output "job_id" {
  description = "Full resource ID of the Cloud Run Job"
  value       = google_cloud_run_v2_job.runner.id
}

output "job_uri" {
  description = "URI of the Cloud Run Job"
  value       = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.runner.name}"
}

output "location" {
  description = "Location/region of the Cloud Run Job"
  value       = google_cloud_run_v2_job.runner.location
}
