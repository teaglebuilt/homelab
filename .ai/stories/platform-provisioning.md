# Helmfile-Controlled Platform Provisioning

## Status

Implemented in-repo (Helmfile stages, scripts, Taskfile wrappers, chart/overlay split).
Live adoption of existing kubectl-applied releases is still a controlled, one-release-at-a-time
cutover — do not bulk-sync until adoption labels are applied.

## Goal

Move Kubernetes platform provisioning from Taskfile-controlled `kustomize build | kubectl apply` pipelines to staged Helmfile synchronization.

Taskfile remains as a thin command wrapper and continues to host operational tasks such as backups and tests. Helmfile becomes responsible for dependency ordering, chart installation, readiness gates, and post-chart manifest application.

Helmfile `postsync` hooks operate independently of ArgoCD.

## Target Deployment Flow

```text
Taskfile
  -> select cluster kubeconfig
  -> helmfile sync
     -> Helm chart releases
     -> CRD readiness gates
     -> operator and webhook readiness gates
     -> chart-free Kustomize overlays
```

The intended user-facing command remains:

```bash
task platform:deploy CLUSTER=mlops
```

Internally, it runs:

```bash
KUBECONFIG=kubernetes/generated/mlops/kubeconfig \
  helmfile -f kubernetes/clusters/mlops/helmfile.yaml sync
```

## Helmfile Stage Layout

1. `00-prepare` — namespaces and prerequisites
2. `01-bootstrap` — Cilium, DNS, Spegel, and storage
3. `02-core` — cert-manager, Gateway API, Cloudflare, and CNPG
4. `03-hardware` — GPU and hardware operators
5. `04-monitoring` — complete observability stack
6. `05-platform` — data, AI, automation, and research workloads
7. `06-gitops` — optional ArgoCD handoff

The existing `05-gitops` stage should be renamed to `06-gitops`. Platform services depend on core and monitoring services and therefore belong before the optional GitOps handoff.

## Provisioning Pattern

Use direct Helmfile releases whenever an upstream Helm chart exists. Kustomize remains appropriate for post-chart custom resources and plain manifests.

Each operator-backed workload follows this sequence:

```text
CRD release
  -> wait for CRDs to become Established
  -> controller/operator release using needs:
  -> wait for Deployment availability
  -> wait for webhook Certificate
  -> wait for webhook endpoints and CA injection
  -> server-side dry-run the dependent CR
  -> postsync apply the chart-free Kustomize overlay
```

An operator chart and its custom resources must not be rendered into the same `kubectl apply` stream.

### Hook Requirements

Shared hook scripts must:

- require an explicit kubeconfig;
- verify the expected cluster before changing resources;
- use `set -euo pipefail`;
- be idempotent;
- wait for required CRDs to report `Established`;
- wait for operator Deployments to become available;
- wait for cert-manager Certificates to become Ready;
- verify that webhook EndpointSlices contain ready endpoints;
- verify that admission webhook CA bundles are populated;
- perform `kubectl apply --dry-run=server` before applying dependent CRs.

Suggested scripts:

- `kubernetes/scripts/apply-kustomization.sh`
- `kubernetes/scripts/wait-for-crds.sh`
- `kubernetes/scripts/wait-for-webhook.sh`

## Stage 04: Monitoring

Modify `kubernetes/helmfile.d/04-monitoring.gotmpl.yaml` to own:

- Vector
- Grafana operator
- kube-prometheus-stack
- OpenTelemetry operator
- Loki
- Tempo

Refactor observability Kustomize overlays so they contain only resources layered on top of those charts:

- Prometheus rules
- `PrometheusAgent`
- `ServiceMonitor` and `PodMonitor` resources
- mesh Services
- Grafana instances, datasources, and dashboards
- `OpenTelemetryCollector` resources
- supporting routes and policies

### OpenTelemetry Ordering

```text
cert-manager
  -> OpenTelemetry CRDs/operator
  -> Certificate Ready
  -> operator Deployment Available
  -> webhook EndpointSlice Ready
  -> webhook CA bundle populated
  -> dry-run OpenTelemetryCollector
  -> apply OpenTelemetryCollector
```

This ordering prevents both observed failure modes:

- admission webhook Service without endpoints;
- webhook certificate signed by an unknown or stale CA.

Use cert-manager for webhook certificates. Do not restore Kustomize `autoGenerateCert`, because it generates a new CA during each render.

## Stage 05: Platform

Create `kubernetes/helmfile.d/05-platform.gotmpl.yaml`.

### Data

```text
CNPG operator
  -> PostgreSQL Cluster resources

Qdrant chart
Redis manifests
ClusterMesh frontend Services
```

Stateful releases must be excluded from routine destroy operations.

### AI

```text
agentgateway CRDs
  -> agentgateway controller

kagent CRDs
  -> kagent controller

Substrate CRDs
  -> substrate operator
  -> SandboxConfig and WorkerPool

data services
  -> Open WebUI

OpenTelemetry collector
  -> AI telemetry resources

controllers
  -> models, agents, MCP servers, routes, and policies
```

### Automation

```text
data services
  -> n8n and supporting resources

kagent and MCP APIs
  -> automation MCP integrations
```

### Research

```text
namespace and prerequisites
  -> SearXNG
```

Per-cluster release gates should continue to use `kubernetes/clusters/<cluster>/environment.yaml`.

## CRD Lifecycle

Use dedicated CRD releases where upstream charts provide them:

- `agentgateway-crds`
- `kagent-crds`
- Prometheus operator CRDs, if a compatible standalone chart exists for the pinned version
- Grafana operator CRDs
- OpenTelemetry CRDs
- Substrate CRDs

CRD releases should carry a label such as:

```yaml
labels:
  tier: crds
```

Routine destroy commands must exclude `tier=crds`. Deleting a CRD also deletes every custom resource of that kind.

### Substrate

If no suitable standalone CRD chart exists, apply raw Substrate CRDs in a controller `presync` hook:

1. Build `platform/ai/kubernetes/substrate/crds`.
2. Apply the CRDs.
3. Wait for all `ate.dev` CRDs to become Established.
4. Install the Substrate controller.
5. Apply `SandboxConfig`, `WorkerPool`, and other CRs in `postsync`.

## Agentgateway Conflict

Two overlapping agentgateway definitions currently exist:

- `oci://ghcr.io/agentgateway/charts/agentgateway` version `v1.6.0`
- `oci://ghcr.io/kgateway-dev/charts/agentgateway` version `v2.2.1`

They deploy the same controller and overlapping object names. The standalone `v1.6.0` release is the recommended owner because:

- its Helm release already exists;
- its CRDs are installed in the cluster;
- those CRDs include `AgentgatewayModel`;
- the current Taskfile explicitly pins that distribution.

Remove the `kgateway-dev` agentgateway entry from `platform/ai/kubernetes/overlays/mlops/kustomization.yaml`.

Before cutover, render and compare both charts:

- controller image and arguments;
- CRDs and served versions;
- GatewayClass;
- proxy image;
- environment variables;
- RBAC and Services.

The first controlled cutover may require a forced Helm sync because a normal upgrade may not remove fields previously applied by Kustomize. Pin the proxy image before cutover to avoid an unintended proxy upgrade.

## Files

### Create

- `kubernetes/helmfile.d/05-platform.gotmpl.yaml`
- `kubernetes/scripts/apply-kustomization.sh`
- `kubernetes/scripts/wait-for-crds.sh`
- `kubernetes/scripts/wait-for-webhook.sh`
- chart-specific values files beside their existing applications

### Rename

- `kubernetes/helmfile.d/05-gitops.gotmpl.yaml`
- to `kubernetes/helmfile.d/06-gitops.gotmpl.yaml`

### Modify

- `kubernetes/helmfile.d/04-monitoring.gotmpl.yaml`
- `kubernetes/clusters/mlops/helmfile.yaml`
- `kubernetes/clusters/application/helmfile.yaml`
- `platform/Taskfile.yml`
- `platform/observability/Taskfile.yml`
- `platform/ai/Taskfile.yml`
- `platform/data/Taskfile.yml`
- `platform/automation/Taskfile.yml`
- `platform/research/Taskfile.yml`
- chart-containing Kustomize overlays under `platform/*/kubernetes/`
- deployment documentation describing stages `00` through `06`

Do not modify `kubernetes/generated/`.

## Taskfile Changes

`platform:deploy` becomes a thin wrapper around the existing cluster Helmfile:

```yaml
tasks:
  deploy:
    requires:
      vars: [CLUSTER]
    cmds:
      - task: kubernetes:sync-cluster
        vars:
          CLUSTER: '{{.CLUSTER}}'
```

Stack-specific deployments can use Helmfile labels:

```bash
helmfile -f clusters/${CLUSTER}/helmfile.yaml \
  sync --selector tier=platform,stack=ai
```

Operational tasks remain in Taskfile:

- backups;
- diagnostics;
- image builds;
- tests;
- manual maintenance jobs.

## Existing Resource Adoption

Most platform charts were rendered by Kustomize and applied with `kubectl`; they are not currently owned by Helm.

Adoption must be performed one release at a time:

1. Render the proposed Helm release.
2. Diff it against live resources.
3. Add Helm ownership labels and annotations only to matching resources.
4. Run a targeted Helmfile sync.
5. Verify that no immutable field replacement or PVC deletion is proposed.
6. Continue to the next release.

Do not bulk-adopt the entire platform.

Likely adoption targets include:

- kube-prometheus-stack
- OpenTelemetry operator
- Loki
- Tempo
- Qdrant
- Open WebUI
- kagent
- agentgateway
- Substrate
- Firecrawl

The Firecrawl chart must be committed into the repository and its image versions pinned before Helmfile can own it reproducibly.

## Destroy Behavior

Define labels for release selection:

```yaml
labels:
  tier: platform
  stack: ai
  lifecycle: stateless
```

Routine destroy should select only explicitly disposable releases:

```bash
helmfile destroy --selector lifecycle=stateless
```

Exclude by default:

- CRD releases;
- PostgreSQL and CNPG resources;
- Qdrant and other stateful services;
- PVC-bearing observability services;
- secrets and encryption prerequisites.

Delete dependent custom resources before intentionally uninstalling their operator.

## Migration Sequence

1. Render and save current Kustomize output for both clusters.
2. Inventory live resources and their current ownership.
3. Split chart rendering from post-chart manifests.
4. Add reusable readiness scripts.
5. Migrate application-cluster observability.
6. Verify the OTel operator, webhook, and collector.
7. Migrate mlops observability.
8. Add the stage 05 data releases.
9. Add AI CRD releases and wait gates.
10. Add AI controllers.
11. Add AI custom resources and routes.
12. Add automation and research.
13. Adopt existing resources one Helm release at a time.
14. Replace `platform:deploy` with the Helmfile wrapper.
15. Remove obsolete deploy and destroy pipelines only after both clusters converge.
16. Rename the GitOps stage and update both cluster entrypoints.

## Validation

### Render

```bash
helmfile -f kubernetes/clusters/application/helmfile.yaml template
helmfile -f kubernetes/clusters/mlops/helmfile.yaml template
```

Confirm:

- every chart version is pinned;
- no duplicate Kubernetes object IDs are rendered;
- releases are correctly gated per cluster;
- all `needs:` references resolve;
- no decrypted secrets are rendered or committed.

### Diff

```bash
helmfile -f kubernetes/clusters/application/helmfile.yaml diff
helmfile -f kubernetes/clusters/mlops/helmfile.yaml diff
```

Run targeted diffs during adoption:

```bash
helmfile -f kubernetes/clusters/mlops/helmfile.yaml \
  diff --selector name=open-telemetry
```

### Runtime

Validate after each stage:

```bash
kubectl get crd
kubectl get certificates -A
kubectl get endpointslices -A
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
helm list -A
```

For every admission webhook:

1. confirm the operator Deployment is Available;
2. confirm its Certificate is Ready;
3. confirm its Service has ready EndpointSlices;
4. confirm webhook CA bundles are populated;
5. server-side dry-run one representative CR;
6. apply the CR and verify its Ready condition.

## Rollback

- Do not uninstall newly adopted releases during migration; uninstalling can delete existing workloads.
- Roll back release-by-release using pinned chart versions.
- To reverse adoption, detach Helm ownership instead of uninstalling the release.
- Preserve PVCs and stateful custom resources by default.
- Delete dependent CRs before intentionally removing an operator or CRD.
- Keep the previous Taskfile deployment commands until both clusters have completed at least one successful Helmfile reconciliation.
- Retain rendered before-and-after manifests for resource-level recovery.

## Decisions Before Implementation

1. Confirm observability remains in stage `04`.
2. Confirm creation of `05-platform` and renaming GitOps to `06-gitops`.
3. Confirm standalone agentgateway `v1.6.0` as the sole owner.
4. Decide whether to pin the agentgateway proxy image before cutover.
5. Commit and pin the Firecrawl chart and images.
6. Confirm stateful releases remain excluded from routine destroy.
7. Replace the MCP GitHub token copied into an `MCPServer` spec with a Secret reference.
