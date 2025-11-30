"""
GitHub Actions Autoscaler for Cloud Run

Receives GitHub workflow_job webhook events and executes Cloud Run Jobs
to provide ephemeral self-hosted runners.

Architecture:
  GitHub webhook (workflow_job.queued) -> This service -> Cloud Run Job execution
  Background polling (fallback) -> Check for stuck jobs -> Cloud Run Job execution

Each job execution handles exactly one workflow job, then terminates.

Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/10
Polling: https://github.com/Matchpoint-AI/project-beta-runners/issues/25
"""

import os
import hmac
import hashlib
import logging
import threading
import time
from typing import Optional
from datetime import datetime, timedelta
from collections import deque

import requests
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
GITHUB_ORG = os.environ.get("GITHUB_ORG", "Matchpoint-AI")

# GitHub App credentials for API polling
GITHUB_APP_ID = os.environ.get("GITHUB_APP_ID")
GITHUB_APP_PRIVATE_KEY = os.environ.get("GITHUB_APP_PRIVATE_KEY")
GITHUB_APP_INSTALLATION_ID = os.environ.get("GITHUB_APP_INSTALLATION_ID")

# Polling configuration
POLL_INTERVAL_SECONDS = int(os.environ.get("POLL_INTERVAL_SECONDS", "30"))
POLL_ENABLED = os.environ.get("POLL_ENABLED", "true").lower() == "true"

# Track recently triggered jobs to avoid duplicates (thread-safe deque)
# Stores (job_id, timestamp) tuples
RECENTLY_TRIGGERED = deque(maxlen=1000)
RECENTLY_TRIGGERED_LOCK = threading.Lock()
TRIGGER_COOLDOWN_SECONDS = 30  # Don't re-trigger same job within 30 seconds
MAX_CONCURRENT_TRIGGERS = 10  # Max jobs to trigger per poll cycle


def verify_webhook_signature(payload: bytes, signature: str) -> bool:
    """
    Verify the GitHub webhook HMAC-SHA256 signature.
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
    """
    job_label_set = set(labels)
    required_labels = set(RUNNER_LABELS)
    return required_labels.issubset(job_label_set)


def was_recently_triggered(job_id: int) -> bool:
    """
    Check if a job was recently triggered to avoid duplicates.
    """
    now = datetime.now()
    cutoff = now - timedelta(seconds=TRIGGER_COOLDOWN_SECONDS)

    with RECENTLY_TRIGGERED_LOCK:
        for triggered_job_id, triggered_time in RECENTLY_TRIGGERED:
            if triggered_job_id == job_id and triggered_time > cutoff:
                return True
    return False


def mark_as_triggered(job_id: int):
    """
    Mark a job as triggered to prevent duplicate triggers.
    """
    with RECENTLY_TRIGGERED_LOCK:
        RECENTLY_TRIGGERED.append((job_id, datetime.now()))


def execute_runner_job(run_id: str, wait_for_result: bool = False) -> Optional[str]:
    """
    Execute a Cloud Run Job to handle the workflow job.

    Args:
        run_id: Identifier for logging/tracking
        wait_for_result: If True, wait for execution to start (blocking).
                         If False, fire and forget (non-blocking).
    """
    if not GCP_PROJECT_ID:
        logger.error("GCP_PROJECT_ID not configured")
        return None

    try:
        client = run_v2.JobsClient()
        job_name = f"projects/{GCP_PROJECT_ID}/locations/{GCP_REGION}/jobs/{RUNNER_JOB_NAME}"

        logger.info(f"Executing job: {job_name}")
        operation = client.run_job(name=job_name)

        if wait_for_result:
            # Blocking: wait for execution to start
            execution = operation.result()
            logger.info(f"Job execution started: {execution.name}")
            return execution.name
        else:
            # Non-blocking: fire and forget
            # The operation is already submitted, we just return a placeholder
            logger.info(f"Job execution triggered (async): {job_name}")
            return f"{job_name}/executions/triggered-{run_id}"

    except Exception as e:
        logger.error(f"Failed to execute runner job: {e}")
        return None


# =============================================================================
# GitHub App Authentication for Polling
# =============================================================================

def generate_jwt() -> Optional[str]:
    """
    Generate a JWT for GitHub App authentication.
    """
    if not GITHUB_APP_ID or not GITHUB_APP_PRIVATE_KEY:
        return None

    try:
        import jwt

        now = int(time.time())
        payload = {
            "iat": now - 60,  # Issued 60 seconds ago (clock skew buffer)
            "exp": now + 540,  # Expires in 9 minutes
            "iss": GITHUB_APP_ID
        }

        return jwt.encode(payload, GITHUB_APP_PRIVATE_KEY, algorithm="RS256")
    except ImportError:
        logger.error("PyJWT not installed - polling disabled")
        return None
    except Exception as e:
        logger.error(f"Failed to generate JWT: {e}")
        return None


def get_installation_token() -> Optional[str]:
    """
    Get an installation access token for GitHub API calls.
    """
    jwt_token = generate_jwt()
    if not jwt_token:
        return None

    if not GITHUB_APP_INSTALLATION_ID:
        logger.error("GITHUB_APP_INSTALLATION_ID not configured")
        return None

    try:
        response = requests.post(
            f"https://api.github.com/app/installations/{GITHUB_APP_INSTALLATION_ID}/access_tokens",
            headers={
                "Authorization": f"Bearer {jwt_token}",
                "Accept": "application/vnd.github+json"
            },
            timeout=10
        )
        response.raise_for_status()
        return response.json().get("token")
    except Exception as e:
        logger.error(f"Failed to get installation token: {e}")
        return None


# =============================================================================
# Polling for Queued Jobs
# =============================================================================

def get_queued_jobs_for_org(token: str) -> list[dict]:
    """
    Get all queued workflow jobs for the organization that match our labels.

    Note: GitHub API doesn't have a direct "get queued jobs" endpoint.
    We need to list workflow runs and their jobs.
    """
    queued_jobs = []

    try:
        # Get list of repos in the org (simplified - may need pagination for large orgs)
        repos_response = requests.get(
            f"https://api.github.com/orgs/{GITHUB_ORG}/repos",
            headers={
                "Authorization": f"token {token}",
                "Accept": "application/vnd.github+json"
            },
            params={"per_page": 100, "type": "all"},
            timeout=30
        )
        repos_response.raise_for_status()
        repos = repos_response.json()

        for repo in repos:
            repo_name = repo["name"]

            # Get queued workflow runs for this repo
            runs_response = requests.get(
                f"https://api.github.com/repos/{GITHUB_ORG}/{repo_name}/actions/runs",
                headers={
                    "Authorization": f"token {token}",
                    "Accept": "application/vnd.github+json"
                },
                params={"status": "queued", "per_page": 20},
                timeout=30
            )

            if runs_response.status_code != 200:
                continue

            runs = runs_response.json().get("workflow_runs", [])

            for run in runs:
                # Get jobs for this run
                jobs_response = requests.get(
                    f"https://api.github.com/repos/{GITHUB_ORG}/{repo_name}/actions/runs/{run['id']}/jobs",
                    headers={
                        "Authorization": f"token {token}",
                        "Accept": "application/vnd.github+json"
                    },
                    timeout=30
                )

                if jobs_response.status_code != 200:
                    continue

                jobs = jobs_response.json().get("jobs", [])

                for job in jobs:
                    if job["status"] == "queued":
                        labels = job.get("labels", [])
                        if should_handle_job(labels):
                            queued_jobs.append({
                                "id": job["id"],
                                "name": job["name"],
                                "repo": repo_name,
                                "labels": labels,
                                "queued_at": job.get("started_at")
                            })

        return queued_jobs

    except Exception as e:
        logger.error(f"Failed to get queued jobs: {e}")
        return []


def poll_and_trigger():
    """
    Poll for queued jobs and trigger runners for any that need them.
    Uses non-blocking job execution to trigger multiple runners quickly.
    """
    logger.info("Polling for queued jobs...")

    token = get_installation_token()
    if not token:
        logger.warning("Could not get GitHub token for polling")
        return

    queued_jobs = get_queued_jobs_for_org(token)
    logger.info(f"Found {len(queued_jobs)} queued jobs matching our labels")

    triggered_count = 0
    for job in queued_jobs:
        # Limit concurrent triggers to avoid overwhelming the system
        if triggered_count >= MAX_CONCURRENT_TRIGGERS:
            logger.info(f"Reached max concurrent triggers ({MAX_CONCURRENT_TRIGGERS}), will continue next poll")
            break

        job_id = job["id"]

        if was_recently_triggered(job_id):
            logger.debug(f"Job {job_id} was recently triggered, skipping")
            continue

        logger.info(f"Triggering runner for stuck job: {job['name']} (id={job_id}, repo={job['repo']})")

        # Use non-blocking mode for polling to trigger multiple runners quickly
        execution_name = execute_runner_job(f"poll-{job_id}", wait_for_result=False)
        if execution_name:
            mark_as_triggered(job_id)
            triggered_count += 1

    if triggered_count > 0:
        logger.info(f"Triggered {triggered_count} runners for stuck jobs")


def polling_loop():
    """
    Background polling loop that runs periodically.
    """
    logger.info(f"Starting polling loop (interval={POLL_INTERVAL_SECONDS}s)")

    while True:
        try:
            poll_and_trigger()
        except Exception as e:
            logger.error(f"Error in polling loop: {e}")

        time.sleep(POLL_INTERVAL_SECONDS)


# =============================================================================
# Webhook Handler
# =============================================================================

@app.route("/webhook", methods=["POST"])
def handle_webhook():
    """
    Handle incoming GitHub webhook events.
    """
    signature = request.headers.get("X-Hub-Signature-256", "")
    if not verify_webhook_signature(request.data, signature):
        logger.warning("Invalid webhook signature")
        return jsonify({"error": "Invalid signature"}), 401

    event_type = request.headers.get("X-GitHub-Event")
    delivery_id = request.headers.get("X-GitHub-Delivery", "unknown")

    logger.info(f"Received webhook: event={event_type}, delivery={delivery_id}")

    if event_type != "workflow_job":
        logger.debug(f"Ignoring event type: {event_type}")
        return jsonify({
            "status": "ignored",
            "reason": f"event type {event_type} not handled"
        })

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

    if action != "queued":
        logger.debug(f"Ignoring action: {action}")
        return jsonify({
            "status": "ignored",
            "reason": f"action {action} not handled",
            "job_id": job_id
        })

    if not should_handle_job(labels):
        logger.info(f"Job labels {labels} do not match required labels {RUNNER_LABELS}")
        return jsonify({
            "status": "ignored",
            "reason": "labels do not match",
            "job_id": job_id,
            "job_labels": labels,
            "required_labels": RUNNER_LABELS
        })

    # Check if already triggered (e.g., by polling)
    if was_recently_triggered(job_id):
        logger.info(f"Job {job_id} was already triggered recently")
        return jsonify({
            "status": "skipped",
            "reason": "already triggered",
            "job_id": job_id
        })

    run_id = f"{job_id}-{delivery_id[:8]}"
    # Use blocking mode for webhooks to provide immediate feedback
    execution_name = execute_runner_job(run_id, wait_for_result=True)

    if execution_name:
        mark_as_triggered(job_id)
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
            "labels": RUNNER_LABELS,
            "polling_enabled": POLL_ENABLED,
            "poll_interval": POLL_INTERVAL_SECONDS
        }
    })


@app.route("/poll", methods=["POST"])
def manual_poll():
    """
    Manually trigger a poll for queued jobs.
    Useful for testing or forcing an immediate check.
    """
    poll_and_trigger()
    return jsonify({"status": "poll_completed"})


@app.route("/", methods=["GET"])
def root():
    """Root endpoint with service information."""
    return jsonify({
        "service": "github-runner-autoscaler",
        "description": "Webhook receiver for GitHub Actions self-hosted runners on Cloud Run",
        "endpoints": {
            "/webhook": "POST - GitHub webhook receiver",
            "/health": "GET - Health check",
            "/poll": "POST - Manually trigger queue poll"
        }
    })


# =============================================================================
# Module Initialization - Start Polling Thread
# =============================================================================
# Start polling thread at module load time so it runs with gunicorn.
# Gunicorn workers import this module, so this code runs for each worker.
# The daemon=True flag ensures the thread stops when the main process exits.

_polling_thread_started = False

def start_polling_thread():
    """Start the polling thread if not already started."""
    global _polling_thread_started
    if _polling_thread_started:
        return

    if POLL_ENABLED and GITHUB_APP_ID and GITHUB_APP_PRIVATE_KEY:
        polling_thread = threading.Thread(target=polling_loop, daemon=True)
        polling_thread.start()
        logger.info("Polling thread started")
        _polling_thread_started = True
    else:
        logger.warning("Polling disabled or GitHub App credentials not configured")


# Auto-start polling when module is imported (works with gunicorn)
start_polling_thread()


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logger.info(f"Starting autoscaler on port {port}")
    app.run(host="0.0.0.0", port=port)
