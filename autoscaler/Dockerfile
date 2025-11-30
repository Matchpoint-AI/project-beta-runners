################################################################################
# GitHub Actions Autoscaler for Cloud Run
################################################################################
# Lightweight container that receives GitHub webhooks and triggers
# Cloud Run Job executions for self-hosted runners.
#
# Issue: https://github.com/Matchpoint-AI/project-beta-runners/issues/10
################################################################################

FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY main.py .

# Run with gunicorn for production
ENV PORT=8080
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 main:app
