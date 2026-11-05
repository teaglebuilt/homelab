# Runbook: mlops-work-00 Node and GPU Recovery

**Scope:** Talos worker `mlops-work-00`, Proxmox VM `102` on `pve2`, NVIDIA RTX 4070 SUPER PCI passthrough using mapping `nvidia_4070_super` (historically `0000:2e:00.0`, audio function `0000:2e:00.1`).

**Status:** Proposed runbook, not applied or tested on running infrastructure. Values and locations are from supplied homelab repository snapshot; verify actual live Proxmox VM configuration and device topology.

**Objective:** Restore a healthy, schedulable Kubernetes node, and when configured as a GPU node, a functional GPU, while preventing data loss, infinite reboot loops, or unsafe PCIe/host resets.

## Preconditions and safety

- Run control actions from an **out-of-band runner** outside VM 102 and preferably outside `pve2` (secondary physical node or Raspberry Pi), with narrowly scoped Proxmox API and Talos credentials.
- Record current state, events and log excerpts before recovery; preserve evidence around recurring Xid errors.
- One recovery operation at a time. Add a distributed lock keyed by `pve2/vm/102`, a cooldown and a maximum retry budget.
- Never assume `Node NotReady` implies the VM has stopped. Check control-plane/API health, Talos reachability and Proxmox state independently.
- **No automatic** `qm stop`, PCI reset/remove, `pve2` reboot, Thunderbolt deauthorization or enclosure power cycle until explicit fencing and safety gates are defined and exercised.
- A host-wide outage is not automatically recoverable by an in-cluster controller because the supplied configuration places the control plane and both workers on `pve2`.
- Do not run `talosctl reset`, `tofu apply`, or `tofu destroy` as incident recovery actions. Those are destructive or configuration-changing workflows, not first-line repair actions.
- Persistent workloads, single-writer volumes, unfinished GPU jobs and PDBs must be considered before draining/fencing.

## Environment setup (admin workstation)

```bash
NODE=mlops-work-00
NODE_IP="${WORKER_00_NODE_IP:?Set WORKER_00_NODE_IP from your environment}"
export TALOSCONFIG="$PWD/kubernetes/generated/talosconfig"
export KUBECONFIG="$PWD/kubernetes/generated/kubeconfig"
```

Run commands from the homelab repository root; verify Kubeconfig/Talosconfig endpoints first.

## Detection / classification

Monitor *independent* signals:

1. Kubernetes: Ready condition, Lease freshness, DiskPressure, MemoryPressure, PIDPressure, `container_runtime` and kubelet health, workload failures.
2. Talos: API availability, service state (`kubelet`, `containerd` / CRI), system messages.
3. Proxmox: host API reachability, VM 102 run state, QEMU process and VM configuration.
4. GPU guest: NVML probe (`nvidia-smi -L` via privileged/driver-enabled probe), expected GPU UUID, NVIDIA device-plugin availability, Xid / AER errors, CUDA smoke test.
5. GPU host: `lspci` device presence, driver bound to `vfio-pci`, PCIe link state, Thunderbolt authorization and kernel logs.
6. End-to-end: known small inference request through AI Gateway to an explicitly GPU-backed model, not just GPU memory/utilization metrics.

If telemetry is absent, distinguish `unknown` from `healthy`. Prometheus or DCGM exporter disappearing is not sufficient proof the GPU has failed.

## Runbook A — node outage (ordinary Talos/Kubernetes issues)

### A1. Diagnose without mutation

```bash
kubectl get nodes -o wide
kubectl describe node "$NODE"
kubectl get pods -A --field-selector spec.nodeName="$NODE" -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -80

talosctl -n "$NODE_IP" services
talosctl -n "$NODE_IP" logs kubelet
talosctl -n "$NODE_IP" dmesg

ssh root@pve2 'qm status 102; qm config 102'
```

### A2. Narrowly repair

- Single failed Deployment: check causes/probes and use its workload controller; avoid reboot.
- `kubelet` down while Talos responds: `talosctl -n "$NODE_IP" service kubelet restart`.
- CRI/containerd down: inspect `talosctl ... services` and restart only the relevant service (verify exact service name on live Talos).
- Cilium unhealthy: inspect `kubectl -n kube-system get pods -o wide | grep cilium`; inspect affected agent log, networking and configuration before changing it.
- DiskPressure: inspect disk usage, expand disk or safely remove disposable caches; never delete Talos state/etcd or persistent application data indiscriminately.
- VM `stopped`: verify it is *supposed* to run, then on pve2 run `qm start 102` and observe task output.

### A3. Escalate to controlled guest reboot

```bash
kubectl cordon "$NODE"
# Only after impact assessment; may be blocked by PDBs/stateful workloads:
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s
# If the drain cannot safely complete, stop here and obtain approval.
talosctl -n "$NODE_IP" reboot
```

If Talos is unreachable, investigate Proxmox/VM console. Prefer a graceful shutdown and boot over a forced stop. **Never force-stop solely on a K8s NotReady signal.**

### A4. Validation

```bash
kubectl get node "$NODE" -o wide
kubectl get pods -A --field-selector spec.nodeName="$NODE"
talosctl -n "$NODE_IP" services
```

Require Ready, node-pressure conditions clear, Cilium healthy, app endpoints and storage healthy and 2–5 minutes stable. Run GPU validation before uncordon for the GPU worker.

## Runbook B — GPU unavailable while node may be Ready

### B1. Diagnose guest side

```bash
kubectl get node "$NODE" -o json | jq '{capacity: .status.capacity, allocatable: .status.allocatable, labels: .metadata.labels}'
kubectl get pods -n kube-system -o wide | grep -Ei 'nvidia|dcgm|feature-discovery'
talosctl -n "$NODE_IP" dmesg | grep -Ei 'NVRM|Xid|nvidia|pcie|AER'
```

Check NVML using an **existing** NVIDIA-enabled diagnostic pod or a daemon operating on the affected node; a new pod requesting `nvidia.com/gpu` may not schedule when the GPU is gone. For example, in a confirmed healthy GPU-enabled pod:

```bash
kubectl exec -n <namespace> <nvidia-enabled-pod> -- nvidia-smi -L
```

Critical Xid (`79` = GPU fallen off bus), lost NVML access, absent GPU allocatable, and repeated model initialization failures each require different classification. Under GPU time-slicing the advertised allocatable quantity can be greater than one; use observed known-good baseline, not `== 1`.

### B2. Inspect Proxmox GPU/Thunderbolt host

```bash
ssh root@pve2
qm status 102
qm config 102 | grep -E 'hostpci|hookscript'
lspci -nnk -s 2e:00.0
lspci -nnk -s 2e:00.1
lspci -vv -s 2e:00.0 | grep -E 'LnkCap|LnkSta'
readlink /sys/bus/pci/devices/0000:2e:00.0/driver || true
journalctl -k --since '30 minutes ago' | grep -Ei 'vfio|thunderbolt|pcie|AER|reset|2e:00'
find /sys/bus/thunderbolt/devices -maxdepth 2 -name authorized -print -exec cat {} \; 2>/dev/null
```

If `2e:00.0` is absent, search all NVIDIA PCI devices with `lspci -Dnn | grep -i 10de` to detect a changed bus address and verify the Proxmox PCI mapping before modification.

### B3. Recovery decision tree

**Case 1: Host PCI device present, `vfio-pci` bound, guest NVML healthy, plugin/capacity broken**

- Review NVIDIA device-plugin logs/config and Node Feature Discovery. Restart **only** the affected plugin pod or reconcile DaemonSet if diagnosis supports it; retest advertised resources. Do not reboot hardware.

**Case 2: Host PCI present, `vfio-pci` bound, guest missing/broken GPU or Xid**

- Quarantine GPU scheduling; checkpoint/stop GPU jobs; collect guest and QEMU logs.
- Attempt **one** graceful VM shutdown followed by a full stop/start of VM 102. Guest reboot may be insufficient for passthrough/GPU reset.
- Validate GPU, VFIO and inference; if still bad, stop retrying and require host-level review.

**Case 3: Host PCI device present but VFIO binding missing or wrong**

- Stop VM 102 and confirm its QEMU process has exited.
- Verify actual GPU PCI functions, IOMMU group, kernel driver and ownership; check whether `post-stop` unbind hook is active.
- Rebind to `vfio-pci` **only with an audited host procedure** after ensuring neither the guest nor any host driver owns the device; recheck mapping, then start VM.
- Do not perform unconditional driver unbind/rebind as a generic repair action.

**Case 4: Host PCI GPU missing / Thunderbolt tunnel dropped**

- Stop VM gracefully before hardware work.
- Verify eGPU enclosure power, Thunderbolt cable/port, authorization and kernel hotplug errors.
- An approved, tested rescan of the *affected* PCIe bridge may work, but only while VM is stopped and bridge topology confirmed.
- If no device returns, escalate to manual enclosure power-cycle / physical intervention. A Proxmox host reboot is last resort and will take down other co-located VMs.
- After re-enumeration, discover the GPU's **current** PCI address and update/reconcile stale Proxmox mappings with change control.

**Case 5: GPU running hot, memory exhausted or app fault only**

- Fix model concurrency, VRAM exhaustion, application or cooling. Don't reset hardware for a capacity problem.

## Recovery gate and retry budget (proposal)

| Level | Typical precondition | Action | Maximum attempts |
|---|---|---|---|
| L0 | Workload crash | Reconcile workload/controller | 2 per 15 min |
| L1 | Talos responsive; service unhealthy | Restart specific Talos service | 1 per 30 min |
| L2 | Node unhealthy; guest responsive; PDB safe | Graceful Talos reboot | 1 per 60 min |
| L3 | GPU plugin broken, host VFIO+NVML healthy | Reconcile NVIDIA device plugin | 1 per 30 min |
| L4 | Proxmox VM stopped and approved auto-restart | `qm start 102` | 1 per 60 min |
| L5 | GPU guest lost, host PCI present | Graceful shutdown then VM stop/start | Approval until tested; then 1 per 6 h |
| L6 | VFIO binding, Thunderbolt, PCIe reset, enclosure/host reboot | Human-approved host operation | 0 automatic |

**Automatic promotion is prohibited** when management connectivity is unclear, stateful workloads can't be fenced, host PCI topology changed, storage is degraded, or `pve2` health is in doubt. Opening an incident is the safe terminal action after budget exhaustion.

## Reference automation flow

1. Prometheus Alertmanager or independent host watchdog emits signed incident to recovery controller (external runner).
2. Controller obtains per-VM lock and snapshots logs/metrics into persistent storage.
3. Controller probes API, Talos, Proxmox, GPU guest and host concurrently, classifies fault using fixed rules.
4. Choose a permitted action under retry budget and safety constraints; notify human before host-impacting action.
5. Execute one action, observe stable health, run GPU smoke test and inference request.
6. Only then uncordon/release quarantine. Otherwise escalate to a human with the full evidence bundle.
7. Expose `GET /incidents`, `POST /incidents/{id}/approve`, `POST /incidents/{id}/retry` with RBAC and audit logging; require operator authorization for impactful actions.

Recommended deployment: a small Go/Python service on an external Pi, secondary host, or independent management VM; Prometheus/Alertmanager for detection; Kagent for read-only investigation and incident summary; n8n for notifications and approvals, **not** as the critical out-of-band execution dependency.

### Suggested recovery policy document

```yaml
apiVersion: homelab.teaglebuilt.dev/v1alpha1 # conceptual, not an installed CRD
kind: NodeRecoveryPolicy
metadata:
  name: mlops-work-00
spec:
  target:
    kubernetesNode: mlops-work-00
    talosNodeEnv: WORKER_00_NODE_IP
    proxmoxNode: pve2
    vmid: 102
    gpu:
      pciVendorDevice: '10de:2783'
      mapping: nvidia_4070_super
      expectedPhysicalCount: 1
  health:
    unhealthyFor: 3m
    healthyFor: 5m
    requireGpuNvml: true
    requireCudaSmokeTest: true
    requireInferenceSmokeTest: true
  actions:
    restartKubelet: automatic
    restartGpuDevicePlugin: automatic-if-verified
    guestReboot: automatic-after-drain
    startStoppedVm: automatic-if-known-intended
    vmStopStart: approval-required
    vfioRebind: approval-required
    pciBridgeRescan: approval-required
    hostReboot: approval-required
    enclosurePowerCycle: approval-required
  limits:
    maxGuestRebootsPerHour: 1
    maxGpuVmCyclesPerSixHours: 1
    coolDown: 30m
```

`NodeRecoveryPolicy` is proposed application-level configuration; it will not function by merely applying it to Kubernetes. Implement a controller/runner and schema validation first, or use equivalent configuration in a recovery workflow.

## Repository changes before enabling automation

1. **Fix inverted health loop** in `kubernetes/Taskfile.yml`: current `until ... grep NotReady` waits for a NotReady match, not a healthy state. Prefer explicit node conditions and `kubectl wait` plus a sensible timeout.
2. **Rework GPU hook** `tf_modules/talos_cluster/scripts/unbind-gpu-hook.sh`: it unconditionally unbinds both GPU functions on `post-stop`, without verifying VM identity, host state, remapping or pre-start readiness. Confirm whether VM 102 actually attaches that hook (`qm config 102`). Replace with idempotent, audited pre-start verification and safe, narrow post-stop cleanup if still required.
3. **Change GPU alert** `platform/observability/prometheus/rules/gpu-metric-alerts.yaml`: the current `rate(DCGM_FI_DEV_GPU_UTIL[15m]) > 0.85` is a rate calculation on a utilization gauge; use correctly scaled gauge aggregation for *utilization monitoring*, and separate GPU-loss alerts, Xid and absence checks for failures.
4. **Avoid stale static GPU labels** *(done)*: `tf_modules/talos_cluster/patches/worker/gpu-worker-label.yaml` now sets `homelab.teaglebuilt.dev/gpu-node=true` (desired role) only. `nvidia.com/gpu.present` is left to NVIDIA GFD. Workload `nodeSelector`s that key on `nvidia.com/gpu.present` stay correct — they stop matching when the device disappears. Under time slicing, compare observed allocatable against a calibrated baseline. Apply the Talos machine-config change and confirm the old static label is removed from the live node.
5. **Fix availability dependencies**: `mlops-ctrl-00`, `mlops-work-00`, and `mlops-work-01` are all defined on `pve2` in the supplied snapshot. True infrastructure HA and recovery during `pve2` outages require moving at least the management runner and relevant control-plane capacity to independent failure domains.
6. **Don't promote GPU link-speed test into remediation**: `platform/observability/scripts/gpu/check-link-speed.sh` writes to `max_link_speed` without validating sysfs support, acceptable values, or the exact device. Keep PCIe link diagnostics read-only until a hardware-specific tested procedure exists.
7. Add a host-side PCI/Thunderbolt GPU-present metric (node_exporter textfile or small exporter) so the automation can distinguish failure of metrics collection inside the guest from loss of host PCIe connectivity.

## Test scenarios before unattended enablement

- Kill a test application pod: no VM reboot; controller reconciliation restores workload.
- Restart kubelet in planned maintenance: node recovers without host action.
- Stop VM 102 cleanly: independently hosted controller detects and starts VM; validates GPU.
- Make device-plugin unhealthy with host PCI intact: reconcile plugin only; no PCI reset.
- Simulate GPU NVML probe failure but keep host healthy: isolate, propose one cold VM cycle, validate behavior.
- Disconnect or disable GPU in a controlled maintenance window: **no automatic PCIe reset** or host reboot; terminal state should be human approval.
- Disable Prometheus/DCGM scraping: alert telemetry missing, not automatic GPU hard reset.
- Repeated failure/flapping: demonstrate lock, cooldown, retry budget and escalation.
- Isolate control-plane networking: avoid treating partition as a dead VM or forcibly recovering stateful workloads.

## Useful docs

- Proxmox PCI passthrough: https://github.com/proxmox/pve-docs/blob/master/qm-pci-passthrough.adoc
- Proxmox hookscript lifecycle: https://github.com/proxmox/pve-docs/blob/master/examples/guest-example-hookscript.pl
- NVIDIA GPU troubleshooting: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/25.10/troubleshooting.html
- Kubernetes node conditions: https://kubernetes.io/docs/reference/node/node-status/
- Medik8s self-node remediation: https://www.medik8s.io/remediation/self-node-remediation/self-node-remediation/
