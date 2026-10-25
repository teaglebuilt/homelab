---
name: k8s
description: >
  Kubernetes operations and troubleshooting for the homelab's two Talos clusters.
  Use for any question about the state, shape or health of a Kubernetes resource —
  pods, deployments, nodes, events, RBAC, CRDs, manifests, scaling and rollouts —
  and before any mutating kubectl-equivalent action. Carries the diagnostic order,
  the Talos-specific constraints, the patch-type rules for CRDs, and the GitOps
  safety rules for this estate.
---

# Kubernetes operations for the homelab

## Estate

Two Talos Linux clusters on Proxmox VMs.

| Cluster | Role | Notes |
| --- | --- | --- |
| `mlops` | GPU and agent stack, runs kagent itself | you execute here |
| `application` | observability hub: Prometheus, Grafana, Loki, Tempo | reached over ClusterMesh |

Cross-cluster reads go through Cilium ClusterMesh global Services, annotated
`service.cilium.io/global: "true"`. A local Service name from the other cluster
will not resolve.

GPU workloads and cert-manager are pinned to `mlops-work-01` with a
`kubernetes.io/hostname` node selector. A pod of that kind stuck Pending is
usually that selector plus a cordoned or full node, not a missing image.

## Talos constraints

There is no SSH and no host package manager. Node-level problems surface as node
conditions and kubelet state — there is nothing to shell into. Host-level change
means a machine-config patch, which is a Talos operation and not yours.

Read-only root filesystem, so a workload that expects to write outside an
`emptyDir` or a PVC fails in ways that look like permission bugs.

## Diagnostic order

Work cheapest first and stop when the evidence is conclusive.

1. `k8s_get_resources` with `output: wide` — what exists and what is unhealthy.
   Set `all_namespaces: true` deliberately; with neither flag you see only the
   namespace the tool runs in, which silently hides the rest of the cluster.
2. `k8s_describe_resource` — the detail and recent transitions.
3. `k8s_get_events` scoped to the namespace — scheduling, image and probe failures.
4. `k8s_get_pod_logs` for the specific container, with `previous: true` when it
   has restarted. A CrashLoopBackOff's cause is in the *previous* container's log.
5. `k8s_execute_command` only when nothing else can answer it.

Image versions are not in a pod listing. The wide output carries a
CONTAINERS/IMAGES column for workloads (deployment, daemonset, statefulset,
replicaset, job, cronjob) but not for pods. Read versions from a workload
listing, or `k8s_get_resource_yaml` for the authoritative spec. Node kubelet and
runtime versions come from `resource_type: node`.

## Reading common failures

| Symptom | Look at |
| --- | --- |
| Pending | events for scheduling; node selectors, taints, resource requests |
| CrashLoopBackOff | previous container logs, then the probe definitions |
| ImagePullBackOff | events for the exact registry error; then imagePullSecrets |
| OOMKilled | `lastState.terminated.reason` on the pod, then the memory limit |
| Ready but not serving | Service selector against pod labels, then the endpoints |
| Terminating forever | finalizers on the object |

## Mutating safely

Read the spec with `k8s_get_resource_yaml` before you change it.

`k8s_patch_resource` defaults to a strategic merge patch, which only works on
built-in types. For a CustomResource or CRD pass `patch_type: merge`, or the
call fails. Use `json` for an RFC 6902 patch.

State what you intend to change and wait for the operator to confirm before
`k8s_delete_resource`, `k8s_apply_manifest`, `k8s_patch_resource` or `k8s_scale`.

Never delete a namespace, CRD, PVC or StatefulSet without an explicit
instruction naming that object. Deleting a CRD deletes every resource of that
kind, cluster-wide and irreversibly.

Prefer the narrowest action that fixes it: patch one field over replacing a
manifest, `k8s_rollout` restart over deleting pods.

## GitOps

Most of this estate is managed by ArgoCD and Helmfile. A live change you make by
hand is reverted on the next sync, so a fix that is not in the repo is not a fix.

Say where the durable change belongs:

| Concern | Location |
| --- | --- |
| Helm values for an app | `kubernetes/apps/<category>/<app>/` |
| Staged deploys | `kubernetes/helmfile.d/` (`00-prepare` → `04-monitoring`) |
| Cluster definitions | `kubernetes/clusters/<cluster>/` |
| Talos / VM provisioning | `kubernetes/terraform/`, `tf_modules/talos_cluster` |

`kubernetes/generated/` is Helmfile output — never propose editing it.

## Reporting

Lead with what is wrong and why. Quote the specific condition, event or log line
that shows it — not a paraphrase. Then the fix, labelled **read-only** or
**mutating**, and how to verify it worked. Say when the real fix belongs in the
repo instead of the live cluster. Markdown.
