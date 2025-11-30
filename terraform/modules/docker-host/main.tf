################################################################################
# Docker Host Module - GCE VM for Remote Docker Daemon
################################################################################
# Provides Docker daemon access for Cloud Run Jobs that need to run containers
# (e.g., testcontainers for integration tests).
#
# Cloud Run cannot run privileged containers, so we use a remote Docker daemon.
# Cloud Run Jobs connect via DOCKER_HOST=tcp://<internal-ip>:2375
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/31
################################################################################

#------------------------------------------------------------------------------
# Compute Instance - Docker Host VM
#------------------------------------------------------------------------------
resource "google_compute_instance" "docker_host" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  # Use Container-Optimized OS for better Docker performance
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = var.disk_size_gb
      type  = "pd-ssd"
    }
  }

  # Internal IP only - no external access needed
  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    # No external IP - access only from within VPC
    # access_config {} # Commented out intentionally
  }

  # Service account with minimal permissions
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  # Startup script to configure Docker daemon for TCP access
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Wait for Docker to be ready (COS has Docker pre-installed)
    until docker info > /dev/null 2>&1; do
      echo "Waiting for Docker..."
      sleep 2
    done

    echo "Docker is ready, configuring TCP listener..."

    # Configure Docker daemon to listen on TCP (internal network only)
    # No TLS since traffic stays within VPC
    cat > /etc/docker/daemon.json <<'DAEMON_CONFIG'
    {
      "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"],
      "storage-driver": "overlay2",
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "100m",
        "max-file": "3"
      }
    }
    DAEMON_CONFIG

    # Restart Docker to apply configuration
    systemctl restart docker

    # Create cleanup cron job to remove old containers/images
    cat > /etc/cron.hourly/docker-cleanup <<'CLEANUP'
    #!/bin/bash
    # Remove stopped containers older than 1 hour
    docker container prune -f --filter "until=1h"
    # Remove unused images older than 24 hours
    docker image prune -af --filter "until=24h"
    # Remove unused volumes
    docker volume prune -f
    CLEANUP
    chmod +x /etc/cron.hourly/docker-cleanup

    echo "Docker host configured successfully!"
  EOF

  # Allow the instance to be preemptible for cost savings
  # Set to false for production stability
  scheduling {
    preemptible       = var.preemptible
    automatic_restart = !var.preemptible
  }

  # Metadata
  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    component  = "docker-host"
    managed-by = "terraform"
    purpose    = "ci-runner-docker"
  }

  tags = ["docker-host", "allow-internal-docker"]

  # Ensure proper shutdown
  lifecycle {
    create_before_destroy = true
  }
}

#------------------------------------------------------------------------------
# Firewall Rule - Allow Docker Access from Cloud Run
#------------------------------------------------------------------------------
resource "google_compute_firewall" "allow_docker" {
  name    = "${var.name}-allow-docker"
  network = var.network
  project = var.project_id

  description = "Allow Docker TCP access from Cloud Run Jobs"

  allow {
    protocol = "tcp"
    ports    = ["2375"]
  }

  # Allow from Cloud Run's serverless VPC connector range
  # and from any internal IP (for testing)
  source_ranges = var.allowed_source_ranges

  target_tags = ["docker-host"]
}

#------------------------------------------------------------------------------
# Health Check (Optional - for monitoring)
#------------------------------------------------------------------------------
resource "google_compute_health_check" "docker_host" {
  count = var.enable_health_check ? 1 : 0

  name    = "${var.name}-health"
  project = var.project_id

  tcp_health_check {
    port = 2375
  }

  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3
}
