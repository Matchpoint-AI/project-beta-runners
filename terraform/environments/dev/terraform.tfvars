# Development environment variables

project_id = "project-beta-dev"
# Issue #44: Moved to us-west1 for 100% carbon-free energy and to avoid quota congestion
region     = "us-west1"

# Runner resource allocation
# Increased from 4Gi default to 8Gi to prevent OOM during npm ci
# See: https://github.com/Matchpoint-AI/project-beta-runners/issues/26
# See: https://github.com/Matchpoint-AI/project-beta-frontend/issues/615
runner_cpu    = "2"
runner_memory = "8Gi"
