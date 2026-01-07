# spotctl - Rackspace Spot CLI

This document describes how to use `spotctl` for managing and troubleshooting Rackspace Spot cloudspaces.

## Installation

### Download from GitHub Releases

```bash
# Linux (amd64)
curl -sL https://github.com/rackspace-spot/spotctl/releases/download/v0.1.1/spotctl-linux-amd64 -o spotctl

# macOS (arm64)
curl -sL https://github.com/rackspace-spot/spotctl/releases/download/v0.1.1/spotctl-darwin-arm64 -o spotctl

# macOS (amd64)
curl -sL https://github.com/rackspace-spot/spotctl/releases/download/v0.1.1/spotctl-darwin-amd64 -o spotctl

# Make executable and install
chmod +x spotctl
sudo mv spotctl /usr/local/bin/
```

### Verify Installation

```bash
spotctl --version
```

## Configuration

Run the interactive configuration wizard:

```bash
spotctl configure
```

Or create config manually:

```bash
mkdir -p ~/.spotctl
cat > ~/.spotctl/config.json << EOF
{
  "organization": "matchpoint",
  "region": "us-central-ord-1",
  "refresh_token": "YOUR_RACKSPACE_SPOT_API_TOKEN"
}
EOF
```

## Common Commands

### Cloudspace Management

```bash
# List all cloudspaces
spotctl cloudspaces list --output table

# Get detailed status of a cloudspace
spotctl cloudspaces get mp-runners-v3 --output json

# Get kubeconfig
spotctl cloudspaces get-config mp-runners-v3 --file ~/.kube/config-mp-runners

# Delete a cloudspace (use with caution!)
spotctl cloudspaces delete --name mp-runners-v3
```

### Node Pool Management

```bash
# List spot node pools
spotctl nodepools spot list --cloudspace mp-runners-v3 --output table

# List on-demand node pools
spotctl nodepools ondemand list --cloudspace mp-runners-v3 --output table

# Create a spot node pool
spotctl nodepools spot create \
  --name workers \
  --cloudspace mp-runners-v3 \
  --serverclass gp.vs1.medium-ord \
  --desired 2 \
  --bidprice 0.08
```

### Server Classes & Regions

```bash
# List available server classes
spotctl serverclasses list --output table

# List available regions
spotctl regions list --output table

# Get pricing
spotctl pricing get-all
```

## Troubleshooting Stuck Provisioning

If a cloudspace is stuck in "Provisioning" state:

### 1. Check Current Status

```bash
spotctl cloudspaces get mp-runners-v3 --output json | jq '.status'
```

### 2. Check Node Pools

```bash
spotctl nodepools spot list --cloudspace mp-runners-v3
```

### 3. If Stuck for > 2 hours, Delete and Recreate

```bash
# Delete the stuck cloudspace
spotctl cloudspaces delete --name mp-runners-v3

# Re-run the deployment workflow
gh workflow run deploy.yml
```

### 4. Use the Status Workflow

```bash
# Run the cloudspace status workflow
gh workflow run cloudspace-status.yml -f cloudspace_name=mp-runners-v3 -f action=full-diagnostics
```

## CI/CD Integration

The deploy workflow automatically:
1. Installs spotctl
2. Runs pre-flight cloudspace status check
3. Reports status after deployment

See `.github/workflows/deploy.yml` for implementation.

## References

- [spotctl GitHub Repository](https://github.com/rackspace-spot/spotctl)
- [Rackspace Spot Documentation](https://spot.rackspace.com/docs/en)
- [Deploy via spotctl](https://spot.rackspace.com/docs/en/deploy-via-spotctl)
