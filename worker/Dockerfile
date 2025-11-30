################################################################################
# GitHub Actions Runner for Cloud Run
################################################################################
# Production-ready container image for self-hosted GitHub Actions runners.
# Built from Ubuntu with GitHub Actions runner installed manually.
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/7
################################################################################

FROM ubuntu:22.04

# Build arguments for tool versions
ARG RUNNER_VERSION=2.321.0
ARG TERRAFORM_VERSION=1.5.7
ARG GO_VERSION=1.21.5
ARG NODE_VERSION=20

ENV DEBIAN_FRONTEND=noninteractive

#------------------------------------------------------------------------------
# Create runner user
#------------------------------------------------------------------------------
RUN useradd -m -s /bin/bash runner \
    && mkdir -p /home/runner \
    && chown -R runner:runner /home/runner

#------------------------------------------------------------------------------
# System Dependencies
#------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    unzip \
    git \
    jq \
    ca-certificates \
    gnupg \
    lsb-release \
    openssh-client \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

#------------------------------------------------------------------------------
# Terraform
#------------------------------------------------------------------------------
RUN wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && mv terraform /usr/local/bin/ \
    && rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && terraform version

#------------------------------------------------------------------------------
# Google Cloud CLI
#------------------------------------------------------------------------------
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/* \
    && gcloud version

#------------------------------------------------------------------------------
# Node.js
#------------------------------------------------------------------------------
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version

#------------------------------------------------------------------------------
# Python 3.11
#------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && python3 --version

#------------------------------------------------------------------------------
# Go
#------------------------------------------------------------------------------
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm "go${GO_VERSION}.linux-amd64.tar.gz"
ENV PATH="${PATH}:/usr/local/go/bin"
RUN go version

#------------------------------------------------------------------------------
# Docker CLI (for docker commands, not daemon)
#------------------------------------------------------------------------------
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/* \
    && docker --version

#------------------------------------------------------------------------------
# GitHub Actions Runner
#------------------------------------------------------------------------------
WORKDIR /home/runner
RUN curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | tar xz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /home/runner

#------------------------------------------------------------------------------
# Entrypoint
#------------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch back to runner user
USER runner
WORKDIR /home/runner

# Health check - verify runner binary exists
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -f /home/runner/run.sh || exit 1

ENTRYPOINT ["/entrypoint.sh"]
