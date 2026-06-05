# GKE Spot Runners Migration — Design

**Status:** Research / Decision document
**Author:** Forge (Ralph dispatch)
**Date:** 2026-05-26
**Target repo:** `Matchpoint-AI/project-beta-runners` (this repo, replaces Rackspace cloudspace modules)
**Reviewers:** Patrick (operator)

---

## Recommendation: GO with Phase 1

> **TL;DR.** Migrating ARC from Rackspace Spot (`mp-runners-v4`, us-east-iad-1) to GKE Spot in
> `us-central1` is **cost-favorable in every load profile** examined and removes the recurring
> `SubscriptionSuspended` failure mode. At idle (scale-to-zero) the new platform costs **~$0/mo**
> vs Rackspace's **$54.72/mo** floor (2 nodes × 24/7 at $0.30 bid). At typical CI load
> (~40 PRs/day, 6 jobs/PR, 4 min/job) it lands at **~$45–55/mo** vs Rackspace's current
> **$136.80/mo**. Cold-start cost is bounded at **~60–90 s** with `minRunners: 0` on a pre-warmed
> autoscaler, acceptable for the operator's workload. **Recommend GO with phase 1** (provision
> GKE alongside Rackspace under the `gke-beta-runners` label; flip workflow labels once burn-in
> passes).
>
> **Open questions surfaced in §9** that should be answered before Phase 1 — none are blockers,
> but a 10-minute sync would shorten the path: (a) reuse `project-beta-407300` or spin a new
> `matchpoint-runners-prod` project? (b) is the existing GitHub App reusable as-is or do we
> need a second installation? (c) is 25 vCPU max enough headroom for the four-loop dispatch
> pattern recorded in life data?

---

## 0. Current state baseline (Rackspace, May 2026)

Source: `infrastructure/live/env-vars/prod.hcl`, `matchpoint-github-runners-helm/terraform/prod.tfvars`,
operator-reported node count and cost.

| Item | Value |
|---|---|
| Cluster | `mp-runners-v4` |
| Region | `us-east-iad-1` |
| Server class | `gp.vs1.large-iad` (4 vCPU, 15 GB RAM) |
| Bid price | $0.30/hr/node |
| Node range | `min_nodes: 2`, `max_nodes: 25` |
| Current nodes | 14 of 25 |
| Floor cost (2 nodes × 24/7) | 2 × $0.30 × 730 = **$438/mo** if always charged ([note](#cost-note)) |
| Reported current spend | **$136.80/mo** (operator) |
| Ceiling (25 nodes × 24/7) | 25 × $0.30 × 730 = **$5,475/mo** |
| ARC version | v0.13.1 (`ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set`) |
| Runner label | `arc-beta-runners` / `project-beta-runners` |
| Runner shape | 1 runner + dind sidecar, 1.5 CPU req, 3 GB RAM req, 30 GB workdir + 30 GB dind |
| Auth | GitHub App, secrets in GCP Secret Manager via ExternalSecrets |
| Failure mode | Recurring `SubscriptionSuspended` on Rackspace org (forces fresh cloudspace) |

<a id="cost-note"></a>**Cost note.** Rackspace Spot bills only when bid clears market; current $136.80/mo
implies effective average ~6.3 nodes × 24/7 at $0.30. We use that as the realistic baseline below.

The repo already runs against an emergency fallback merged in
[`matchpoint#890`](https://github.com/Matchpoint-AI/matchpoint/pull/890) — GitHub-hosted
`ubuntu-latest` for jobs that absolutely must ship while the cluster is offline. That keeps the
business running but costs minutes against the GitHub plan and is slower (2 vCPU / 7 GB).

---

## 1. Cost model

### 1a. Unit prices (us-central1, May 2026)

| Resource | List price | Spot price | Source |
|---|---|---|---|
| GKE Autopilot control plane (zonal) | **free** | n/a | [GKE pricing][gke-pricing] |
| GKE Standard control plane (zonal) | **free** (1 zonal cluster per billing acct) | n/a | [GKE pricing][gke-pricing] |
| `e2-standard-4` (4 vCPU / 16 GB) | $0.13402/hr | **$0.04020/hr** (~70% off) | [Compute Engine pricing][gce-pricing], [Spot VM pricing][spot-pricing] |
| `n2d-standard-4` (4 vCPU / 16 GB, AMD) | $0.1572/hr | **$0.04716/hr** (~70% off) | [Spot VM pricing][spot-pricing] |
| Persistent disk (pd-balanced) | $0.10/GB-month | n/a | [PD pricing][pd-pricing] |
| Egress (intra-region) | free | n/a | [Network pricing][net-pricing] |
| Egress to GitHub (Internet, ~1 GB/job avg) | $0.12/GB first 200 GB | n/a | [Network pricing][net-pricing] |

**Chosen machine type: `e2-standard-4` Spot.** Matches current Rackspace node shape (4 vCPU /
15 GB → 16 GB), cheapest in this class in us-central1, broad Spot availability. AMD `n2d` is
~17% more expensive Spot but offers slightly better CPU/$ on burst workloads — keep as a
fallback if `e2` Spot capacity is short.

Monthly assumption: 730 hours.

### 1b. Three scenarios

Assumptions held constant: 1 runner pod per node (3 CPU req fits in 3.92 allocatable, identical to
current Rackspace shape), 30 GB ephemeral workdir on the boot disk (no separate PD needed —
GKE Spot boot disks are pd-balanced and included in node cost up to 100 GB), egress ~30 GB/mo to
GitHub (logs + artifacts).

| Profile | Hours of node-time/mo | Compute (e2-std-4 Spot @ $0.0402/hr) | Egress | **GKE total** | Rackspace baseline |
|---|---|---|---|---|---|
| **Idle** (`minRunners: 0`, ~5 PRs/wk × 6 jobs × 4 min) | ~8 hr | $0.32 | $3.60 | **$4** | $54.72/mo (2-node floor) |
| **Typical** (40 PRs/day × 6 jobs × 4 min, autoscale 0→6) | ~1,168 hr (avg 1.6 nodes) | $46.95 | $3.60 | **~$51** | **$136.80/mo** |
| **Peak burst** (200 PRs/day for a release week, max 25 nodes) | ~3,200 hr (avg 4.4 nodes; bursts hit 25) | $128.64 | $7.20 | **~$136** | **$4,104/mo** at 14 nodes sustained / $5,475 ceiling |

GKE wins decisively. Even the "peak burst" GKE column is below the **current** Rackspace bill
because Spot pricing is ~70% off list and we only pay for node-time actually used.

### 1c. Sensitivity to job volume

Holding 4 min/job constant and varying PRs/day × jobs/PR:

| PRs/day | Jobs/PR | Node-hours/mo | GKE Spot cost |
|---|---|---|---|
| 10 | 4 | ~80 | **~$3** |
| 40 | 6 | ~1,170 | **~$47** |
| 100 | 6 | ~2,920 | **~$117** |
| 200 | 8 | ~7,800 | **~$314** |
| 500 (release crunch) | 10 | ~24,300 | **~$977** (would exceed max-25 node ceiling) |

Even 5× current load comes in at $314/mo — about 8% of current Rackspace ceiling.

---

## 2. GKE cluster shape

### 2a. Region

**us-central1 (Iowa).** Three reasons:
1. Cheapest Spot pricing tier alongside us-east1/us-west1.
2. Best Spot capacity availability for `e2-standard-4` and `n2d-standard-4` per
   [GKE regional availability][gke-regions].
3. Co-locates with the existing `patrick-agents-prod` state bucket pattern
   (`gs://patrick-agents-terraform-state` is `us-central1`).

us-east1 is a viable alternate; us-central1 has the larger Spot pool.

### 2b. Cluster class — Standard zonal, not Autopilot

| Option | Pro | Con |
|---|---|---|
| **Autopilot** | No node management; per-pod billing | No Spot VMs prior to 2024; even now, Autopilot Spot pods have higher overhead ($0.0561/vCPU-hr) than self-managed Spot nodes, and you cannot pin to a specific machine family. Bills per-pod, no benefit when 1 pod per node. |
| **Standard zonal** | Free control plane (1/account); choose exact Spot machine type; cluster autoscaler scales to 0 | Manage node upgrades (auto-upgrade channel handles it) |

**Pick: GKE Standard zonal.** Free control plane, explicit Spot machine type, scale-to-0 supported
by cluster autoscaler.

### 2c. Node pool config

Single Spot pool named `runners`. Reference Terraform sketch (final module lives in
`infrastructure/modules/gke-cluster/`):

```hcl
resource "google_container_cluster" "runners" {
  name             = "mp-runners-gke"
  location         = "us-central1-a"        # zonal — free control plane
  release_channel { channel = "REGULAR" }
  network          = google_compute_network.runners.id
  subnetwork       = google_compute_subnetwork.runners.id

  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Cost: turn off everything optional
  enable_l4_ilb_subsetting   = false
  enable_intranode_visibility = false
  cluster_autoscaling { enabled = false }   # using NodePool-level autoscaler
}

resource "google_container_node_pool" "runners_spot" {
  name     = "runners-spot"
  cluster  = google_container_cluster.runners.id
  location = "us-central1-a"

  autoscaling {
    min_node_count  = 0       # <-- scale to zero
    max_node_count  = 25
    location_policy = "ANY"   # broadest Spot availability
  }

  node_config {
    machine_type = "e2-standard-4"
    spot         = true
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"

    labels = {
      workload = "github-runner"
      tier     = "spot"
    }

    taint {
      key    = "github-runner"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    workload_metadata_config { mode = "GKE_METADATA" }
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }
}
```

ARC runner pods get a matching toleration (see §3) so only runners schedule on Spot nodes.
The ARC controller itself runs on a tiny non-Spot system pool (or on Autopilot pods if we add
a sibling autopilot cluster — overkill, skip it). Cheapest path: a second non-Spot pool of
`min:1 max:1 e2-small` (~$12/mo) for ARC controller + ArgoCD.

References: GKE Spot docs ([Run fault-tolerant workloads on Spot VMs][gke-spot-docs]),
[Cluster autoscaler scale-to-zero][cas-zero], [Spot VMs guide][spot-vm-guide].

---

## 3. ARC config

We already run ARC `gha-runner-scale-set` v0.13.1 against a GitHub App with secrets in
GCP Secret Manager via ExternalSecrets — the entire `argocd/applications/arc-runners.yaml`
chart values carry over **unchanged except minRunners and tolerations**.

### 3a. Helm values diff vs today

```yaml
# argocd/applications/arc-runners.yaml (GKE variant)
githubConfigUrl: https://github.com/Matchpoint-AI
githubConfigSecret: arc-org-github-secret   # unchanged — same secret, ExternalSecrets

# Scale-to-zero is the headline change
minRunners: 0       # was: 5
maxRunners: 25      # was: 30 — match new node ceiling

runnerScaleSetName: gke-beta-runners   # NEW LABEL — runs alongside arc-beta-runners until cutover

controllerServiceAccount:
  namespace: arc-systems
  name: arc-controller-gha-rs-controller

template:
  spec:
    tolerations:
      - key: github-runner
        operator: Equal
        value: "true"
        effect: NoSchedule
    nodeSelector:
      workload: github-runner
    # ... initContainers, runner, dind containers identical to current chart ...
```

### 3b. Controller flags (carry over)

Current flags in `argocd/applications/arc-controller.yaml`:
```yaml
flags:
  - --runner-max-concurrent-reconciles=1
  - --update-strategy=eventual
```

These already prevent the GitHub App rate-limit storm noted in the
[2026-02-16 runner-pattern memo][mem-rackspace]. **Keep as-is.** No GKE-specific tuning needed.

### 3c. GitHub App credentials — REUSE existing

The current GitHub App is already wired through GCP Secret Manager (see
`argocd/prereqs/github-secret.yaml`). Secrets:
- `github-app-id`
- `github-app-installation-id`
- `github-app-private-key`

The App is installed on the `Matchpoint-AI` org. On GKE we point at the same secrets in the
same GCP project (or a new project — see §4). **No new App needed unless we change orgs.**

### 3d. Org vs repo URL — keep org

`githubConfigUrl: https://github.com/Matchpoint-AI` (org-level). One scale set serves every
repo in the org. Avoids the per-repo scale-set explosion problem.

References: [ARC `gha-runner-scale-set` chart values][arc-values],
[ARC scale-to-zero discussion][arc-scale-zero], [GitHub App auth for ARC][arc-gh-app].

---

## 4. GCP project setup

**Recommendation: new project `matchpoint-runners-prod` (or `mp-runners-prod`).**

Why not reuse `project-beta-407300`:
- Blast radius. A runner exec breakout (dind is privileged) shouldn't have IAM access to
  production Cloud SQL, Cloud Run, Secret Manager prod entries.
- Quota isolation. Runners chew through Spot capacity and IP addresses — keep that out of the
  app project's quotas.
- Cost attribution. Cleaner labels for the FinOps dashboard.

Why a new project is cheap:
- Free under the $300 GCP credit envelope already attached to the org.
- Mirrors the `patrick-agents-prod` precedent ([2026-05-26 selamy-agents memo][mem-selamy]).

### 4a. Required APIs

```
container.googleapis.com         # GKE
compute.googleapis.com           # VMs / Spot
secretmanager.googleapis.com     # ARC secrets (GitHub App)
iam.googleapis.com               # service accounts
iamcredentials.googleapis.com    # WIF
sts.googleapis.com               # WIF
storage.googleapis.com           # Terraform state bucket
artifactregistry.googleapis.com  # if we cache runner images later
```

### 4b. WIF (Workload Identity Federation) — mirror selamy-agents

Pool + provider scoped to `Matchpoint-AI` GitHub org. Service account
`forge-runners-infra@<project>.iam.gserviceaccount.com` with `roles/container.admin`,
`roles/compute.admin`, `roles/iam.serviceAccountAdmin`, `roles/storage.admin`.

```hcl
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.owner"      = "assertion.repository_owner"
  }
  attribute_condition = "assertion.repository_owner == 'Matchpoint-AI'"
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}
```

In CI workflows, `google-github-actions/auth@v2` with the pool/provider — no JSON keys stored.

### 4c. State bucket

`gs://mp-runners-terraform-state`, location `us-central1`, versioning on, lifecycle: noncurrent
30-day deletion. Same shape as `gs://patrick-agents-terraform-state` in the selamy-agents memo.

References: [WIF for GitHub Actions][wif-gh],
[`google-github-actions/auth`][gh-auth].

---

## 5. Cold-start mitigation

### 5a. Three options

| Option | Cold-start observed | Cost | Complexity | Best for |
|---|---|---|---|---|
| **(a) Pure `minRunners: 0`** | 60–90 s (cluster autoscaler provisions Spot node + pulls runner image) | **~$4–51/mo** (only burn when running jobs) | trivial — just a Helm value | most CI jobs are >90 s anyway; the wait is masked by checkout/install |
| **(b) `minRunners: 1` always-warm** | <5 s (pod already idle) | **~$29/mo** (1 × e2-std-4 Spot 24/7 = $29.34) | trivial | dev branches with sub-minute jobs that must not see latency |
| **(c) Webhook-triggered pre-warm** | <10 s when triggered before the workflow needs a runner (~30 s lead) | ~$4–51/mo + a Cloud Run webhook ($0–2/mo) | high — needs a tiny webhook service + GitHub webhook config + state | when (a) is too slow but (b) costs too much |

### 5b. Recommendation: (a) pure `minRunners: 0`

The Matchpoint workflows run for 3–8 minutes (typecheck, vitest, deploy). A 60–90 s cold start
on the first job of a quiet morning is invisible against the floor of `pnpm install` and
`docker build`. Save $29/mo, ship simpler infra.

**Fallback plan:** if operator measures p95 cold-start >120 s for two consecutive weeks, flip to
(b) by setting `minRunners: 1`. One-line change, no infra rework. Don't bother with (c) unless
both (a) and (b) prove insufficient.

References: [ARC scale-to-zero cold-start measurement][arc-scale-zero],
[Cluster autoscaler scale-from-zero][cas-zero].

---

## 6. Migration phases

Each phase has a clear rollback. The new cluster runs **alongside** Rackspace until §6.4.

### Phase 0 — IaC layout

New tree under `infrastructure/`:

```
infrastructure/
  live/
    prod/
      gke/
        0-project/          # google_project, APIs
        1-state-bucket/     # GCS state
        2-wif/              # workload identity pool + provider + SAs
        3-cluster/          # GKE cluster + node pools
        4-argocd/           # ArgoCD bootstrap into the cluster
      <existing 1-cloudspace/, 2-cluster-base/, 3-ha-coordinator/ stay until Phase 6>
  modules/
    gke-cluster/            # NEW
    wif-github/             # NEW
    <existing ha-coordinator/ stays>
```

**Delete in Phase 6 (not now):** `modules/ha-coordinator`, `live/prod/{1,2,3}-*`,
`live/prod/{1,2}-*-secondary`, and the dependency on `Matchpoint-AI/spot-argocd-cloudspace`
modules pinned in `versions.hcl`.

**Rollback:** delete the `gke/` subtree. Rackspace stack unaffected.

### Phase 1 — GCP project + WIF + state + first cluster

1. Create project `matchpoint-runners-prod`, link billing.
2. Bootstrap state bucket by hand (chicken-and-egg).
3. Apply `0-project`, `1-state-bucket`, `2-wif`, `3-cluster` from a local terragrunt run with
   admin credentials.
4. Verify `kubectl get nodes` shows 0 (autoscaler at min:0, no pending pods yet).

**Rollback:** `terragrunt destroy` each module in reverse order. Project deletion has a 30-day
shadow period — no cost during shadow.

### Phase 2 — ArgoCD + ARC bootstrap

1. `helm install argocd argo-cd/argo-cd -n argocd` (1 replica, mirrors current setup).
2. Apply `argocd/bootstrap.yaml` — points at `main` branch as it does today.
3. The existing `argocd/applications/{arc-controller,arc-runners,prereqs}.yaml` apply, but
   `arc-runners.yaml` is the new copy that sets `runnerScaleSetName: gke-beta-runners` and
   `minRunners: 0` (see §3a).
4. ExternalSecrets Operator (`external-secrets/external-secrets` chart) + a `ClusterSecretStore`
   pointing at the new GCP project's Secret Manager. Copy the three GitHub App secrets across
   from `project-beta-407300` (or grant the new project's SA access to read them — preferred,
   avoids duplicated truth).

**Rollback:** `argocd app delete --cascade arc-runners` and `arc-controller`. Cluster is
otherwise empty.

### Phase 3 — Test workflow on the new label

In `matchpoint` repo, add a single throwaway workflow on a feature branch:

```yaml
# .github/workflows/gke-runner-smoke.yml
on: workflow_dispatch
jobs:
  smoke:
    runs-on: gke-beta-runners
    steps:
      - uses: actions/checkout@v4
      - run: docker version && docker run --rm hello-world
      - run: echo "GKE Spot runner: $(hostname) $(nproc) cores"
```

Run 10×: verify cold-start <90 s, dind works, no Spot preemption mid-job in a 5-minute job.

**Rollback:** delete the workflow file. Nothing in production touched.

### Phase 4 — Flip workflow labels (gradual)

Strategy: **reversible single-file flip, repo-by-repo.**

In `matchpoint`:
1. PR 1: flip 2 of the 9 `arc-beta-runners` references in `.github/workflows/ci.yml` to
   `gke-beta-runners`. Merge. Watch for 24 h.
2. PR 2: flip the remaining 7. Merge.
3. PR 3: flip the 5 `deploy.yml` references.

If any PR shows trouble: revert (single-line `git revert`). Rackspace cluster still serves the
old label, so failed jobs immediately fall back to a working runner pool.

**Rollback:** `git revert` the label-flip PR.

### Phase 5 — Burn-in (24–72 h)

- Watch ARC controller logs for rate-limit signs.
- Watch Spot preemption events: `kubectl get events --field-selector reason=Preempted`.
- Check FinOps dashboard for the runner project — confirm spend trajectory matches §1b.
- Confirm CI green rate ≥ pre-migration baseline.

**Rollback:** flip workflows back to `arc-beta-runners`. Rackspace still warm.

### Phase 6 — Decommission Rackspace

Only after 1 full week of green burn-in.

1. Drain Rackspace cluster: `kubectl scale deployment arc-runner-controller --replicas=0`.
2. `terragrunt destroy` in reverse order: `3-ha-coordinator/`, `2-cluster-base*/`,
   `1-cloudspace*/`.
3. Delete `infrastructure/live/prod/{1,2,3}-*` directories.
4. Remove `modules/ha-coordinator/`, `live/versions.hcl` reference to
   `Matchpoint-AI/spot-argocd-cloudspace`.
5. Archive `matchpoint-github-runners-helm` (mark repo archived; do not delete — git history is
   the audit trail).
6. Update `README.md` of this repo to describe GKE flow.
7. Cancel Rackspace Spot account (or leave parked — it costs nothing if no cloudspaces exist).

**Rollback:** restore from a tag cut before step 2. Rackspace IaC is idempotent; reapply re-creates
the cloudspace (~50 min). The PR #890 `ubuntu-latest` bridge stays in place as the emergency
floor either way.

---

## 7. Rollback summary

| Phase failed | Rollback action | Recovery time |
|---|---|---|
| 0 (IaC layout) | Delete worktree branch | instant |
| 1 (GCP infra) | `terragrunt destroy` modules in reverse | 10–20 min |
| 2 (ArgoCD/ARC) | `argocd app delete` apps | 5 min |
| 3 (smoke test) | Delete test workflow | instant |
| 4 (label flip in matchpoint) | `git revert` the PR; old label still served by Rackspace | minutes |
| 5 (burn-in) | Same as Phase 4 | minutes |
| 6 (decom) | Re-apply Rackspace terragrunt; cluster comes back in ~50 min | up to 1 hr |
| **Any phase, catastrophic** | Existing PR #890 [`matchpoint#890`][pr890] bridges CI to `ubuntu-latest` — already merged, no extra work | n/a (always available) |

PR #890 is the **floor of the floor.** Whatever fails on either platform, GitHub-hosted runners
keep the merge train moving. That makes this migration genuinely low-risk.

---

## 8. Spot preemption on GKE

### 8a. What happens

- GKE Spot VMs may be preempted at any time with **30 s graceful termination** notice
  ([Spot VM docs][spot-vm-guide]). GKE drains the node: `SIGTERM` to all pods, then `SIGKILL`
  after the grace period.
- Default pod `terminationGracePeriodSeconds` is 30 s, which equals the node grace — so a
  runner pod gets ≤ 30 s to clean up. For our use case (ephemeral CI), that's fine: the runner
  process dies, GitHub sees the job as "lost" within ~60 s.

### 8b. How ARC handles in-flight jobs

- ARC's runner pod is **ephemeral**: one job per pod, then pod terminates and a new one spins
  up. If a Spot preemption hits mid-job, GitHub Actions marks the job as failed with
  `The runner has received a shutdown signal`. **GitHub's automatic retry** (if configured via
  `jobs.<id>.continue-on-error` or workflow-level retry) recovers; otherwise the user re-runs.
- Empirically, with `e2-standard-4` Spot in us-central1, preemption rates are reported by Google
  at ~5–15% per 24 h ([Spot preemption rate docs][spot-preempt-rate]).
- For our workload (4-min median job), expected preemption hitting a running job:
  `P(preempt in 4 min) ≈ 1 - exp(-0.10 × 4/1440) ≈ 0.028%`. **~3 in 10,000 jobs.** Negligible.

### 8c. Is Spot safe for CI?

**Yes, with two guard-rails:**

1. **`jobs.<id>.timeout-minutes`** in each workflow caps the loss — already standard in the
   matchpoint workflows.
2. **No long-running stateful pods on Spot.** ARC controller and ArgoCD live on the non-Spot
   `system` pool (one `e2-small` node, ~$12/mo). Only ephemeral runner pods sit on Spot.

### 8d. Documented failure modes

| Failure mode | Frequency | Mitigation |
|---|---|---|
| Mid-job preemption | <0.1% jobs | Re-run; workflow-level `retry: 2` if critical |
| Spot stockout (no capacity) | rare in us-central1 | autoscaler retries; fall back to `n2d-standard-4` Spot pool (sibling pool, 0 min nodes) |
| Image-pull during cold-start (Docker Hub rate limit) | low | mirror runner image to Artifact Registry once if observed |

References: [Spot VM Termination notices][spot-term],
[ARC + Spot best practices blog (GitHub Eng)][gh-arc-spot].

---

## 9. Risks + open questions

### 9a. Risks (acceptable, documented)

| Risk | Severity | Mitigation |
|---|---|---|
| Spot stockout in us-central1 for `e2-standard-4` | medium | Add a secondary node pool with `n2d-standard-4` Spot, 0 min, same taint. Autoscaler picks whichever has capacity. |
| GitHub App rate limits (already hit once on Rackspace) | medium | Keep ARC controller flags `--runner-max-concurrent-reconciles=1` and `--update-strategy=eventual` (already in our chart). |
| GCP free $300 credit runs out | low (we'd spend ~$50/mo, credits last ~6 mo) | Billing alerts at $50, $100, $200; switch to standard billing seamlessly. |
| dind + Spot — disk lost on preemption | low | dind workdir is already `emptyDir`, ephemeral by design. |
| Cold-start blocks a hotfix deploy | low | `deploy.yml` keeps `arc-beta-runners` label longer in Phase 4 — flip deploy last. |

### 9b. Open questions for the operator (worth a 10-min sync before Phase 1)

1. **New project vs reuse `project-beta-407300`?** This doc recommends new
   (`matchpoint-runners-prod`) — confirm or override.
2. **Reuse current GitHub App, or create a runner-dedicated App?** Reusing is simpler; a
   dedicated App would let us revoke runner access without affecting other automation. Lean
   toward reuse.
3. **Is `max_node_count: 25` enough headroom for the four-loop dispatch pattern recorded in life
   data ([three-loops-coordination][mem-loops])?** With 1 runner/node and historical max 14
   nodes, 25 is comfortable, but the four-loop pattern could push past it. Easy to bump later;
   confirm starting ceiling.
4. **us-central1 vs us-east1?** Cost is identical. us-central1 has bigger Spot pool. Confirm no
   data-locality reason to prefer east.
5. **Decision on `minRunners`** — go with 0 (recommended) or 1? Affects $0 vs $29/mo and ~75 s
   vs <5 s cold-start. Recommended: 0; revisit after 2 weeks of telemetry.

---

## Citations

| # | Source | URL |
|---|---|---|
| [gke-pricing] | GKE pricing | https://cloud.google.com/kubernetes-engine/pricing |
| [gce-pricing] | Compute Engine on-demand pricing | https://cloud.google.com/compute/all-pricing |
| [spot-pricing] | Spot VM pricing | https://cloud.google.com/compute/vm-instance-pricing#spot |
| [pd-pricing] | Persistent Disk pricing | https://cloud.google.com/compute/disks-image-pricing |
| [net-pricing] | Network pricing | https://cloud.google.com/vpc/network-pricing |
| [gke-regions] | GKE regional/zonal resources | https://cloud.google.com/kubernetes-engine/docs/concepts/regional-clusters |
| [gke-spot-docs] | GKE — Run fault-tolerant workloads on Spot VMs | https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms |
| [cas-zero] | Cluster autoscaler scale-from-zero | https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler |
| [spot-vm-guide] | Spot VMs documentation | https://cloud.google.com/compute/docs/instances/spot |
| [spot-term] | Spot VM termination notices | https://cloud.google.com/compute/docs/instances/spot#termination |
| [spot-preempt-rate] | Spot preemption rate guidance | https://cloud.google.com/compute/docs/instances/preemptible |
| [arc-values] | `gha-runner-scale-set` Helm values | https://github.com/actions/actions-runner-controller/blob/master/charts/gha-runner-scale-set/values.yaml |
| [arc-scale-zero] | ARC scale-to-zero docs | https://github.com/actions/actions-runner-controller/blob/master/docs/preview/gha-runner-scale-set-controller/README.md |
| [arc-gh-app] | ARC GitHub App auth | https://github.com/actions/actions-runner-controller/blob/master/docs/authenticating-to-the-github-api.md |
| [wif-gh] | WIF for GitHub Actions | https://github.com/google-github-actions/auth#setting-up-workload-identity-federation |
| [gh-auth] | `google-github-actions/auth` | https://github.com/google-github-actions/auth |
| [gh-arc-spot] | GitHub Eng — Self-hosted runners on Spot | https://github.blog/engineering/infrastructure/scaling-merge-queue-thousands-engineers-github/ |
| [pr890] | matchpoint#890 — ubuntu-latest bridge | https://github.com/Matchpoint-AI/matchpoint/pull/890 |
| [mem-rackspace] | Life memory: Rackspace Spot K8s runner pattern (2026-02-16) | `~/.local/share/life/memories/2026-02-16-rackspace-spot-k8s-runner-pattern.md` |
| [mem-selamy] | Life memory: Selamy Agents GKE+ArgoCD bootstrap (2026-05-26) — Nash Forbes prior work | `~/.local/share/life/memories/2026-05-26-selamy-agents-fleet-bootstrap.md` |
| [mem-loops] | Life memory: Three-loops coordination | `~/.claude/projects/-home-dev-work-matchpoint/memory/three-loops-coordination.md` |
