"""
GitHub Actions Autoscaler for Cloud Run

Receives GitHub workflow_job webhook events and executes Cloud Run Jobs
to provide ephemeral self-hosted runners.

Architecture:
  GitHub webhook (workflow_job.queued) -> This service -> Cloud Run Job execution

Each job execution handles exactly one workflow job, then terminates.

Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/10
"""

import os
import json
import hmac
import hashlib
import logging
from typing import Optional

from flask import Flask, request, jsonify
from google.cloud import run_v2

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment
GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID")
GCP_REGION = os.environ.get("GCP_REGION", "us-central1")
RUNNER_JOB_NAME = os.environ.get("RUNNER_JOB_NAME", "github-runner")
WEBHOOK_SECRET = os.environ.get("GITHUB_WEBHOOK_SECRET")
RUNNER_LABELS = os.environ.get("RUNNER_LABELS", "self-hosted,cloud-run").split(",")


def verify_webhook_signature(payload: bytes, signature: str) -> bool:
    """
    Verify the GitHub webhook HMAC-SHA256 signature.

    Args:
        payload: Raw request body bytes
        signature: X-Hub-Signature-256 header value

    Returns:
        True if signature is valid, False otherwise
    """
    if not WEBHOOK_SECRET:
        logger.warning("GITHUB_WEBHOOK_SECRET not configured - skipping signature verification")
        return True

    if not signature:
        logger.warning("No signature provided in request")
        return False

    expected = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        payload,
        hashlib.sha256
    ).hexdigest()

    expected_signature = f"sha256={expected}"
    return hmac.compare_digest(expected_signature, signature)


def should_handle_job(labels: list[str]) -> bool:
    """
    Check if this autoscaler should handle a job based on labels.

    Args:
        labels: List of labels from the workflow job

    Returns:
        True if all configured runner labels are present in job labels
    """
    job_label_set = set(labels)
    required_labels = set(RUNNER_LABELS)

    # Check if all required labels are present
    return required_labels.issubset(job_label_set)


def execute_runner_job(run_id: str) -> Optional[str]:
    """
    Execute a Cloud Run Job to handle the workflow job.

    Args:
        run_id: Unique identifier for this run (used in job execution name)

    Returns:
        Execution name if successful, None otherwise
    """
    if not GCP_PROJECT_ID:
        logger.error("GCP_PROJECT_ID not configured")
        return None

    try:
        client = run_v2.JobsClient()

        # Construct the job resource name
        job_name = f"projects/{GCP_PROJECT_ID}/locations/{GCP_REGION}/jobs/{RUNNER_JOB_NAME}"

        logger.info(f"Executing job: {job_name}")

        # Run the job
        operation = client.run_job(name=job_name)

        # Get the execution resource
        execution = operation.result()

        logger.info(f"Job execution started: {execution.name}")
        return execution.name

    except Exception as e:
        logger.error(f"Failed to execute runner job: {e}")
        return None


@app.route("/webhook", methods=["POST"])
def handle_webhook():
    """
    Handle incoming GitHub webhook events.

    Processes workflow_job events and triggers Cloud Run Job executions
    when jobs are queued and match our runner labels.
    """
    # Verify signature
    signature = request.headers.get("X-Hub-Signature-256", "")
    if not verify_webhook_signature(request.data, signature):
        logger.warning("Invalid webhook signature")
        return jsonify({"error": "Invalid signature"}), 401

    # Get event type
    event_type = request.headers.get("X-GitHub-Event")
    delivery_id = request.headers.get("X-GitHub-Delivery", "unknown")

    logger.info(f"Received webhook: event={event_type}, delivery={delivery_id}")

    # Only process workflow_job events
    if event_type != "workflow_job":
        logger.debug(f"Ignoring event type: {event_type}")
        return jsonify({
            "status": "ignored",
            "reason": f"event type {event_type} not handled"
        })

    # Parse payload
    try:
        payload = request.json
    except Exception as e:
        logger.error(f"Failed to parse payload: {e}")
        return jsonify({"error": "Invalid JSON payload"}), 400

    action = payload.get("action")
    workflow_job = payload.get("workflow_job", {})
    job_id = workflow_job.get("id")
    job_name = workflow_job.get("name", "unknown")
    labels = workflow_job.get("labels", [])

    logger.info(f"workflow_job event: action={action}, job_id={job_id}, name={job_name}, labels={labels}")

    # Only process queued jobs
    if action != "queued":
        logger.debug(f"Ignoring action: {action}")
        return jsonify({
            "status": "ignored",
            "reason": f"action {action} not handled",
            "job_id": job_id
        })

    # Check if we should handle this job
    if not should_handle_job(labels):
        logger.info(f"Job labels {labels} do not match required labels {RUNNER_LABELS}")
        return jsonify({
            "status": "ignored",
            "reason": "labels do not match",
            "job_id": job_id,
            "job_labels": labels,
            "required_labels": RUNNER_LABELS
        })

    # Execute a runner job
    run_id = f"{job_id}-{delivery_id[:8]}"
    execution_name = execute_runner_job(run_id)

    if execution_name:
        logger.info(f"Runner job execution started for workflow job {job_id}")
        return jsonify({
            "status": "processed",
            "action": action,
            "job_id": job_id,
            "execution": execution_name
        })
    else:
        logger.error(f"Failed to start runner for workflow job {job_id}")
        return jsonify({
            "status": "error",
            "error": "Failed to execute runner job",
            "job_id": job_id
        }), 500


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint for Cloud Run probes."""
    return jsonify({
        "status": "healthy",
        "config": {
            "project": GCP_PROJECT_ID,
            "region": GCP_REGION,
            "runner_job": RUNNER_JOB_NAME,
            "labels": RUNNER_LABELS
        }
    })


@app.route("/", methods=["GET"])
def root():
    """Root endpoint with service information."""
    return jsonify({
        "service": "github-runner-autoscaler",
        "description": "Webhook receiver for GitHub Actions self-hosted runners on Cloud Run",
        "endpoints": {
            "/webhook": "POST - GitHub webhook receiver",
            "/health": "GET - Health check"
        }
    })


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logger.info(f"Starting autoscaler on port {port}")
    app.run(host="0.0.0.0", port=port)
