# ADR-0009: Move kagent to 1.0 (api.kagent.dev/v1alpha3) in place in `ai`, with Agent Substrate

## Status
Proposed

## Context
kagent 0.10.3 serves `kagent.dev/v1alpha2`. Its `AgentHarness` supports only `hermes` and `openclaw`, Agent Substrate is disabled in the mlops overlay, and `harness/hermes.yaml` referenced a WorkerPool that was never created. The software factory needs kagent's Claude Harness, which exists only in kagent 1.0 (`v1.0.0-alpha`, API group `api.kagent.dev/v1alpha3`). 1.0 splits an agent into an `AgentTemplate` (model, prompt, tools, skills, plugins) and a `Harness` (runtime on Substrate), and every Harness runs on Substrate.

1.0 ships only the new API. It doesn't serve or convert `kagent.dev/v1alpha2`, and upstream's upgrade tests cover only 1.0 alpha-to-alpha upgrades.

## Decision Drivers
* **Must** run the Claude Harness for software factory builders
* **Should** keep everything in the `ai` namespace
* **Should** keep a single kagent release (no long-lived side-by-side install)

## Considered Options
### Option 1: Stay on 0.10.3
- **Pros**: stable
- **Cons**: no Claude Harness, no AgentTemplate/Harness split
### Option 2: Side-by-side 1.0 in a new namespace, migrate, then remove 0.10.3
- **Pros**: zero-downtime migration
- **Cons**: two controllers, two kmcp installs, a second namespace
### Option 3: In-place cutover in `ai`
- **Pros**: one release, one namespace; the four agents are small enough to recreate
- **Cons**: agents are down between the CRD swap and the first successful 1.0 revision; 0.10 sessions and memories are lost

## Decision
**Option 3.** Hermes is dropped and not replaced.

## What changed in the repo
- `platform/ai/kubernetes/overlays/mlops/kustomization.yaml`: kagent chart `0.10.3` → `1.0.0-alpha9`; values moved to the 1.0 layout (`podSecurityContext`, `securityContext`, `otel.exporter/traces/logs`); built-in agents block removed; `substrate.enabled` and `controller.substrate.enabled` on; `substrateWorkerPool` created as `kagent-default` (gVisor, `ateom-gvisor` pinned by digest); credential provider grants atespace `ai` access to Secrets in `ai`; `../../harness` added to resources
- `platform/ai/Taskfile.yml`: `kagent-crds` pinned to `1.0.0-alpha9` with `kmcp.enabled` and `substrate.enabled`
- `platform/ai/kubernetes/substrate/`: kustomize Job `substrate-identity-bootstrap` (+ RBAC) creates CA/JWT pool Secrets and `ate-api-authentication` idempotently (Helm does not; secrets are not committed). Included from the mlops overlay.
- `platform/ai/kubernetes/substrate/podcert/`: installs `substrate-podcert` 0.5.0-alpha1 (the `*.podcert.ate.dev` signer controller) into `podcertificate-controller-system`, which no chart deploys. The parent kustomization's `namespace: ate-system` transformer was removed so it is not rewritten into `ate-system`; every resource underneath already sets its own namespace
- `platform/ai/kubernetes/substrate/postgres/`: vendored upstream cert-auth PostgreSQL (PVC 20Gi) and a setup Job creating the `substrate-postgres-{readwrite,owner}` Secrets; `operator/values.yaml` sets `postgres.clientCertificates.enabled: true`
- `platform/ai/kubernetes/harness/`: `hermes.yaml` removed; new Harnesses `kagent` (Go ADK) and `claude` (Claude Code), images pinned by digest
- `platform/ai/kubernetes/runtime/` removed (substrate-crds 0.0.7 and a placeholder operator; neither was deployed)
- ModelConfig (9) and RemoteMCPServer (2) moved to `api.kagent.dev/v1alpha3`; the Bedrock ModelConfig moved off `kagent.dev/v1alpha1` (`apiKeySecretRef` → `apiKeySecret`, `modelInfo` dropped)
- Agents split into `AgentTemplate` + `Agent` (`harnessRef: kagent`): `solutions-architect`, `llmd-inference-agent`, `devbot` (chart), and `scraping-service-agent`
- `scraping-service-agent` moved from `automation` to `ai`, because v1alpha3 references (ModelConfig, RemoteMCPServer, Harness, WorkerPool) must be in the Agent's namespace. It now uses the `firecrawl` RemoteMCPServer; the old `firecrawl-mcp` reference pointed at a RemoteMCPServer that didn't exist
- KMCP `MCPServer` resources are unchanged (`kagent.dev/v1alpha1`)

All migrated resources validate against the 1.0.0-alpha9 CRD schemas. CEL rules weren't checked offline.

## Prerequisites (cluster)
1. **Kubernetes version and feature gates.** The Substrate chart requires the `ClusterTrustBundle`, `ClusterTrustBundleProjection`, and `PodCertificateRequest` feature gates. On 1.32 the apiserver rejects `projected.sources[].podCertificate` as an unknown field (strict decoding), so kagent 1.0 cannot apply. Repo desired state for mlops: `kubernetes_version = 1.37.1`, `pod_certificates = true` in `kubernetes/terraform/mlops/main.tf`, which adds `patches/controlplane/pod-certificates.yaml` (apiserver `runtime-config: certificates.k8s.io/v1beta1=true`) and `patches/worker/pod-certificates.yaml` (kubelet feature gates). On 1.37 the cluster serves `podcertificaterequests` and `clustertrustbundles` at `certificates.k8s.io/v1`. Apply via Terraform machine-config refresh + `talosctl upgrade-k8s` — not done by `task platform:ai:deploy`.
2. **Agent Substrate identity bootstrap.** The bundled substrate subchart does **not** create CA/JWT pool Secrets or the `ate-api-authentication` ConfigMap. The mlops overlay includes `platform/ai/kubernetes/substrate/`, which applies Job `substrate-identity-bootstrap`. That Job downloads pinned `kubectl-ate` v0.5.0-alpha1 and creates, idempotently: `service-dns-ca-pool`, `pod-identity-ca-pool` and `postgres-ca-pool` in `podcertificate-controller-system`; `actor-id-jwt-pool`, `actor-id-ca-pool`, `egress-mitm-ca-pool`, and `actor-id-ca-certs` in `ate-system`; and `ate-api-authentication` in `ate-system` with the cluster OIDC issuer and audience `api.ate-system.svc`. All three CA pools are required: the signer controller mounts them unconditionally. Plaintext CA private keys are never committed to git. Substrate pods may `FailedMount` until the Job finishes.
3. **Pod-certificate signers.** Neither the substrate chart nor `substrate-crds` deploys the signers for `*.podcert.ate.dev`; its README says so outright. `platform/ai/kubernetes/substrate/podcert/` installs `substrate-podcert` 0.5.0-alpha1 into `podcertificate-controller-system`. Without it every `podCertificate` projection fails with `credential bundle is not issued yet`, every `clusterTrustBundle` projection with `matched zero ClusterTrustBundles`, and PodCertificateRequests stay `Pending` indefinitely — nothing signs them and no trust bundle is ever published. The controller is a cluster singleton at `replicas: 1` and signs for any namespace.
4. **PostgreSQL.** `ate-api-server` reads two non-optional Secrets, `substrate-postgres-readwrite` and `substrate-postgres-owner`. CNPG is not installed on mlops, so nothing provides them by default. `platform/ai/kubernetes/substrate/postgres/` vendors upstream's `manifests/ate-install/postgres/postgres.yaml` (certificate-only auth, no passwords; PVC 500Gi → 20Gi, since `local-path` is hostPath without a quota and the request is advisory — the effective limit is the node filesystem) plus a setup Job that runs `pkg/postgressetup/setup.sql` over the pod's local socket and writes both connection-string Secrets. `postgres.clientCertificates.enabled: true` in `operator/values.yaml` is required: without it `ate-api-server` never mounts `/run/postgres.podcert.ate.dev`, which both connection strings reference.
5. **HTTPS credential injection.** Substrate intercepts HTTPS egress to inject credentials and needs an `egress-mitm-ca-pool` Secret plus actor trust (Substrate credential provider docs). The bootstrap task creates `egress-mitm-ca-pool`; required before the Claude Harness can call Anthropic. Also confirm whether Claude Harness traffic can still go through `ai-gateway`.
6. **Snapshot storage.** Harnesses use `s3://ate-snapshots/<harness>/` on Substrate's in-cluster RustFS (1Gi PVC, default credentials `rustfsadmin`). Set real credentials (SOPS) and size before relying on snapshots. The location format is taken from upstream examples and is unverified.
7. **Privileged workloads.** Substrate's `atelet` DaemonSet adds capabilities and mounts host paths. `ai` is already `pod-security.kubernetes.io/enforce: privileged`, as is `ate-system`. Neither chart creates the `podcertificate-controller-system` namespace; `platform/ai/kubernetes/substrate/podcert/namespace.yaml` declares it.

## Cutover runbook
1. Meet the prerequisites above.
2. Export anything worth keeping from the kagent UI (0.10 sessions and memories aren't migrated).
3. `task platform:ai:deploy CLUSTER=mlops`. `install-crds` upgrades `kagent-crds` to 1.0, which **removes the `kagent.dev` Agent, ModelConfig, RemoteMCPServer, and AgentHarness CRDs and deletes every resource of those kinds**. The kustomize apply installs kagent 1.0 with Substrate, the `substrate-podcert` signer controller and PostgreSQL, and runs Jobs `substrate-identity-bootstrap` (identity Secrets) and `substrate-postgres-setup` (schema, roles, connection-string Secrets). Both Jobs are idempotent; the signer controller and the Substrate pods `FailedMount` until their prerequisites land, then recover on kubelet retry.
4. Confirm the signer is working before anything else: `kubectl get clustertrustbundles` should list entries for `servicedns.podcert.ate.dev/identity` and `podidentity.podcert.ate.dev/identity` carrying label `podcert.ate.dev/canarying=live` (the projections select on it), and `kubectl get podcertificaterequests -A` should show `Issued`, not `Pending`. PodCertificateRequests queued before the controller existed may need deleting to force fresh ones.
5. Check: `kubectl get harnesses.api.kagent.dev,agenttemplates.api.kagent.dev,agents.api.kagent.dev -n ai`; every Agent should report a successful revision.
6. Invoke `llmd-inference-agent` (no external credentials) first, then `solutions-architect`.
7. Re-point anything using 0.10 A2A paths (`/api/a2a/<ns>/<agent>`). 1.0 serves A2A, MCP, and gRPC on controller port 8083 with a reworked A2A gateway; build the OpenWebUI A2A Pipe (ADR-0001) against 1.0.

**Rollback:** reinstall `kagent-crds` and `kagent` at 0.10.3 from git history and re-apply the old manifests. 1.0 resources and sessions are lost.

## Consequences
### Positive
- Claude Harness, AgentTemplates, plugins and skills from immutable sources, HITL as A2A `input-required`
- One namespace, one release
### Negative
- Alpha software: 9 releases in about 3 weeks. Pin exact versions and digests, keep kagent out of Renovate, read release notes before bumping
- Kubernetes upgrade and feature gates on mlops before anything runs
- The Claude Harness pins Claude Code 2.1.285; harness-repo mods (≥ 2.1.287) don't run inside it yet
- v1alpha2 `a2aConfig.skills` and `declarative.deployment` (env, resources) have no v1alpha3 equivalent and were dropped
- `kb-retrieval` (used by `solutions-architect`) and `devbot-computer-control` are referenced but not defined in this repo, as before

## Related Decisions
- ADR-0001 (A2A Pipe), ADR-0006 (code execution), ADR-0007 (tool tiers)
