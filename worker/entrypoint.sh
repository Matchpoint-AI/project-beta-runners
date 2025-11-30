#!/bin/bash
################################################################################
# GitHub Actions Runner Entrypoint for Cloud Run
################################################################################
# Handles runner registration, execution, and graceful cleanup.
# Uses GitHub App authentication for secure token generation.
#
# Required Environment Variables:
#   GITHUB_APP_ID           - GitHub App ID
#   GITHUB_APP_PRIVATE_KEY  - GitHub App private key (PEM format)
#   GITHUB_APP_INSTALLATION_ID - Installation ID for the organization
#
# Optional Environment Variables:
#   GITHUB_ORG     - GitHub organization (default: Matchpoint-AI)
#   RUNNER_NAME    - Runner name (default: cloud-run-<hostname>)
#   RUNNER_LABELS  - Comma-separated labels (default: self-hosted,cloud-run,linux,x64)
#   RUNNER_WORKDIR - Working directory for jobs (default: _work)
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/7
################################################################################

set -euo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
GITHUB_ORG="${GITHUB_ORG:-Matchpoint-AI}"
RUNNER_NAME="${RUNNER_NAME:-cloud-run-$(hostname | cut -c1-8)-$(date +%s | tail -c5)}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,cloud-run,linux,x64}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"

#------------------------------------------------------------------------------
# Logging (all logs go to stderr to avoid mixing with function return values)
#------------------------------------------------------------------------------
log() {
    echo "[$(date -Iseconds)] $*" >&2
}

log_error() {
    echo "[$(date -Iseconds)] ERROR: $*" >&2
}

#------------------------------------------------------------------------------
# GitHub App JWT Generation
#------------------------------------------------------------------------------
generate_jwt() {
    local app_id="$1"
    local private_key="$2"

    local now=$(date +%s)
    local iat=$((now - 60))  # Issued 60 seconds ago (clock skew buffer)
    local exp=$((now + 540)) # Expires in 9 minutes

    # Header
    local header='{"alg":"RS256","typ":"JWT"}'
    local header_b64=$(echo -n "$header" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')

    # Payload
    local payload="{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${app_id}\"}"
    local payload_b64=$(echo -n "$payload" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')

    # Write private key to temp file (avoids process substitution issues)
    local keyfile=$(mktemp)
    trap "rm -f $keyfile" EXIT
    printf '%s\n' "$private_key" > "$keyfile"
    chmod 600 "$keyfile"

    # Signature
    local unsigned="${header_b64}.${payload_b64}"
    local signature=$(echo -n "$unsigned" | openssl dgst -sha256 -sign "$keyfile" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')

    rm -f "$keyfile"
    echo "${unsigned}.${signature}"
}

#------------------------------------------------------------------------------
# Get Installation Access Token
#------------------------------------------------------------------------------
get_installation_token() {
    local jwt="$1"
    local installation_id="$2"

    local response=$(curl -s -X POST \
        -H "Authorization: Bearer ${jwt}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/app/installations/${installation_id}/access_tokens")

    local token=$(echo "$response" | jq -r '.token // empty')

    if [ -z "$token" ]; then
        log_error "Failed to get installation token: $response"
        return 1
    fi

    echo "$token"
}

#------------------------------------------------------------------------------
# Get Runner Registration Token
#------------------------------------------------------------------------------
get_runner_token() {
    local access_token="$1"
    local org="$2"

    local response=$(curl -s -X POST \
        -H "Authorization: token ${access_token}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/orgs/${org}/actions/runners/registration-token")

    local token=$(echo "$response" | jq -r '.token // empty')

    if [ -z "$token" ]; then
        log_error "Failed to get runner registration token: $response"
        return 1
    fi

    echo "$token"
}

#------------------------------------------------------------------------------
# Generate Runner Token (combines all steps)
#------------------------------------------------------------------------------
generate_runner_token() {
    log "Generating runner registration token..."

    # Validate required environment variables
    if [ -z "${GITHUB_APP_ID:-}" ]; then
        log_error "GITHUB_APP_ID is required"
        return 1
    fi

    if [ -z "${GITHUB_APP_PRIVATE_KEY:-}" ]; then
        log_error "GITHUB_APP_PRIVATE_KEY is required"
        return 1
    fi

    if [ -z "${GITHUB_APP_INSTALLATION_ID:-}" ]; then
        log_error "GITHUB_APP_INSTALLATION_ID is required"
        return 1
    fi

    # Step 1: Generate JWT
    log "  Generating JWT..."
    local jwt=$(generate_jwt "$GITHUB_APP_ID" "$GITHUB_APP_PRIVATE_KEY")

    # Step 2: Get Installation Access Token
    log "  Getting installation access token..."
    local access_token=$(get_installation_token "$jwt" "$GITHUB_APP_INSTALLATION_ID")
    if [ -z "$access_token" ]; then
        return 1
    fi

    # Step 3: Get Runner Registration Token
    log "  Getting runner registration token..."
    local runner_token=$(get_runner_token "$access_token" "$GITHUB_ORG")
    if [ -z "$runner_token" ]; then
        return 1
    fi

    echo "$runner_token"
}

#------------------------------------------------------------------------------
# Cleanup Handler
#------------------------------------------------------------------------------
cleanup() {
    log "Received shutdown signal, deregistering runner..."

    # Generate fresh token for removal
    local token=$(generate_runner_token 2>/dev/null || true)

    if [ -n "$token" ]; then
        ./config.sh remove --token "$token" 2>/dev/null || true
        log "Runner deregistered successfully"
    else
        log_error "Could not generate token for deregistration"
    fi

    exit 0
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    log "============================================================"
    log "GitHub Actions Runner - Cloud Run"
    log "============================================================"
    log "Organization: ${GITHUB_ORG}"
    log "Runner Name:  ${RUNNER_NAME}"
    log "Labels:       ${RUNNER_LABELS}"
    log "Work Dir:     ${RUNNER_WORKDIR}"
    log "============================================================"

    # Set up signal handlers
    trap cleanup SIGTERM SIGINT SIGQUIT

    # Generate registration token
    RUNNER_TOKEN=$(generate_runner_token | tr -d '\n\r')
    if [ -z "$RUNNER_TOKEN" ]; then
        log_error "Failed to generate runner token"
        exit 1
    fi
    log "Runner token generated successfully (length: ${#RUNNER_TOKEN})"

    # Configure runner
    log "Configuring runner..."
    ./config.sh \
        --url "https://github.com/${GITHUB_ORG}" \
        --token "${RUNNER_TOKEN}" \
        --name "${RUNNER_NAME}" \
        --labels "${RUNNER_LABELS}" \
        --work "${RUNNER_WORKDIR}" \
        --unattended \
        --ephemeral \
        --replace

    log "Runner configured successfully"

    # Start runner
    log "Starting runner..."
    ./run.sh &
    RUNNER_PID=$!

    # Wait for runner to complete
    wait $RUNNER_PID
    EXIT_CODE=$?

    log "Runner exited with code: ${EXIT_CODE}"
    exit $EXIT_CODE
}

# Run main function
main "$@"
