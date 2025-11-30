#!/bin/bash
# GitHub Actions Runner Entrypoint for Cloud Run
# Handles runner registration, execution, and graceful cleanup

# TODO: Full implementation tracked in Issue #X

set -e

# Configuration from environment variables
GITHUB_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
GITHUB_ORG="${GITHUB_ORG:-Matchpoint-AI}"
RUNNER_NAME="${RUNNER_NAME:-cloud-run-runner-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,cloud-run,linux,x64}"

# Trap signals for graceful shutdown
cleanup() {
    echo "Received shutdown signal, deregistering runner..."
    ./config.sh remove --token "${GITHUB_TOKEN}"
    exit 0
}
trap cleanup SIGTERM SIGINT

# Register the runner
echo "Registering runner ${RUNNER_NAME} with org ${GITHUB_ORG}..."
./config.sh \
    --url "https://github.com/${GITHUB_ORG}" \
    --token "${GITHUB_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --unattended \
    --ephemeral

# Run the runner
echo "Starting runner..."
./run.sh
