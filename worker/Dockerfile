# GitHub Actions Runner for Cloud Run
# Based on the official actions/runner image with Cloud Run adaptations

# TODO: Full implementation tracked in Issue #X

FROM ghcr.io/actions/runner:latest

# Install additional tools needed by project-beta workflows
# TODO: Add based on workflow requirements

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
