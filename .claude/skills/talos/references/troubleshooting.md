---
source_product: Talos Linux troubleshooting
source_version: v1.11 baseline; always match the installed cluster version
retrieved: 2026-07-21
primary_sources:
  - https://docs.siderolabs.com/talos/v1.11/troubleshooting/faqs
  - https://docs.siderolabs.com/talos/v1.11/reference/cli
---

# Troubleshooting

Talos has no SSH or interactive shell. Use its API and resources to move from a
broad symptom to the smallest supported explanation.

## Diagnostic Ladder

### 1. Confirm Context

```bash
talosctl config info
talosctl version --nodes <node>
```

Confirm the context, endpoint, node address, client/server versions, and cluster.
Do not diagnose the wrong node or stale client context.

### 2. Check Cluster and Membership

```bash
talosctl health
talosctl get members --nodes <control-plane-node>
kubectl get nodes -o wide
```

Separate:

- Talos node health.
- etcd/control-plane membership.
- Kubernetes node readiness.

### 3. Discover Resources

Resource names vary by Talos version. Discover before querying:

```bash
talosctl get rd
talosctl get <resource> --nodes <node>
talosctl <command> --help
```

### 4. Inspect Services and Logs

```bash
talosctl service <service> --nodes <node>
talosctl logs <service> --nodes <node>
talosctl dmesg --nodes <node>
```

Use logs for the component implicated by evidence. Avoid dumping every service
log into context at once.

### 5. Inspect Hardware and Filesystem State

```bash
talosctl get extensions --nodes <node>
talosctl get disks --nodes <node>
talosctl get mounts --nodes <node>
talosctl get modules --nodes <node>   # when supported
```

For kernel configuration, the official FAQ documents API-based reads such as:

```bash
talosctl read /proc/config.gz --nodes <node>
```

Do not assume a shell is required.

### 6. Correlate With Kubernetes

Check:

- Node conditions and taints.
- Events.
- System daemonsets.
- Cilium status.
- CSI and storage health.
- RuntimeClass and device plugin state.
- Workload scheduling failures.

A Talos runtime or network problem often appears first as a Kubernetes symptom.

### 7. Compare Desired and Live State

Inspect Git inputs, rendered machine config, live resources, and deployed Helm
values. Explicitly identify drift rather than guessing which side is correct.

### 8. Support Bundle

Use `talosctl support` only after narrowing scope. Support bundles can contain
sensitive topology and configuration metadata. Store them outside the repo,
review before sharing, and avoid attaching them to public issues without
redaction.

## Symptom Map

| Symptom | Check first |
|---|---|
| Node NotReady | Talos health, kubelet service/logs, Cilium, time, disk pressure |
| API unavailable | Control-plane node, etcd membership/quorum, apid/kube-apiserver |
| DNS failures | Talos host DNS, kubelet cluster DNS, CoreDNS, Cilium service routing |
| Pod sandbox errors | Container runtime, CNI state, RuntimeClass, image filesystem |
| Disk pressure | Proxmox disk size, Talos disks/mounts, EPHEMERAL use, image GC |
| GPU disappeared | PCI mapping, extensions, modules, runtime, device plugin |
| Upgrade stuck | Installer image pull, extension compatibility, filesystem unmount, logs |
| Config rejected | Rendered config, matching schema, `talosctl validate --strict` |

## Recovery Boundaries

The following are not routine diagnostics:

- `bootstrap`
- `reset`
- `wipe`
- `recover`
- etcd restore or downgrade
- forced upgrade or rollback

Before any recovery action:

1. Determine whether quorum exists.
2. Record members and alarms.
3. Identify the newest valid snapshot.
4. Confirm the exact target node and control-plane topology.
5. Preserve logs and evidence.
6. State blast radius and expected downtime.
7. Use the exact documentation for the running Talos/etcd version.
8. Obtain explicit user confirmation immediately before the action.

Never bootstrap an initialized healthy cluster, and never wipe a node simply
because it is NotReady.

## Response Format

For each troubleshooting response, state:

1. What evidence is known.
2. What remains unknown.
3. Most likely fault domain and confidence.
4. One or two next read-only commands.
5. What result would confirm or reject the hypothesis.
6. A persistent remediation only after evidence supports it.
