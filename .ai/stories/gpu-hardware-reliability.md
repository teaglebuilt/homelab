# Goal

Stop the recurring need to manually reboot `mlops-work-00` when the GPU fan spins up, by fixing
the actual cause (host memory over-allocation on `pve2`) rather than the symptom (the fan), and
make a recurrence visible before it requires human intervention.

Scope: the `mlops` Talos cluster on Proxmox host `pve2`, the NVIDIA stack in
`kubernetes/apps/hardware/nvidia/`, the `ai` namespace LLM workloads, and the mlops
observability overlay. The same ballooning defect exists on the `application` cluster and is
included as a scheduled follow-up.

---

# Diagnosis

## Root cause: `pve2` is allocated 99.5% of its RAM

`kubernetes/terraform/mlops/main.tf` allocates `ram_dedicated` 8096 + 16384 + 8120 =
**32,600 MiB** across the three mlops VMs, all on `pve2`, a 32 GiB (32,768 MiB) GEEKOM IT13
(`docs/hardware.md`). That leaves ~168 MiB for PVE itself.

Proxmox auto-ballooning only reclaims under host memory pressure. Because the host is fully
committed, the balloon sits permanently maxed and **every guest lives at roughly half its
nominal RAM indefinitely** — measured, with `virtio_balloon` loaded in all three:

| node | `ram_dedicated` | live `MemTotal` | balloon floor (`floating`, live state) |
|---|---|---|---|
| mlops-ctrl-00 | 8096 MiB | ~4.46 GiB | 4048 |
| mlops-work-00 | 16384 MiB | ~8.37 GiB | 8192 |
| mlops-work-01 | 8120 MiB | ~4.47 GiB | 4060 |

Ballooning is the mechanism that masks the problem. Over-allocation is the disease.

## Why ballooning is fatal on Talos

Every memory guardrail on a Talos node is computed once from boot-time `MemTotal` and never
revised: kubelet's node capacity, kubelet's reservations, and Talos's own non-configurable
cgroup limits for the `init`/`system`/`podruntime` groups. Ballooning invalidates all of them
at once. Kubelet on `mlops-work-00` still reports capacity `16148064Ki` (~16 GiB) against
~8.37 GiB of real RAM.

Upstream Talos lists **Ballooning: Disabled** in its Proxmox baseline — "Talos doesn't support
memory hotplug." This is unsupported, not a tuning preference.

## The chain from over-allocation to "reboot the GPU node"

1. Guests run permanently at their balloon floor.
2. `platform/ai/kubernetes/llm-providers/selfhosted/deployment.yaml` gives vLLM
   `requests.memory: 6Gi` / `limits.memory: 12Gi`. **12Gi exceeds the ballooned node's entire
   physical RAM**, so vLLM can never hit its own cgroup ceiling.
3. The kernel's **global** OOM killer fires instead, picking by `oom_score` across all tasks —
   including Talos system services. Observed victims: `kagent-adk` x8, `node` x5,
   `DelayedTaskSche` x1.
4. kagent agent pods are **BestEffort** (`platform/ai/kubernetes/llm-providers/selfhosted/agent.yaml`
   sets no resources; the agent runtime is a separate image from the kagent controller and the
   chart sets resources only for the controller). Highest `oom_score` → killed first → restarted →
   retries inference against vLLM → sustained GPU load.
5. Sustained GPU load heats a 220W card. **The fan responds to die temperature via the board's
   VBIOS curve.** That loop, running overnight, is the loud fan.
6. A reboot "fixes" it because it restores full RAM at boot and breaks the crash-loop.

## What the fan actually is

Nothing in Talos, Kubernetes, or the NVIDIA driver controls the fan curve. It lives in the
board's VBIOS thermal tables; on GeForce cards `nvidia-smi` cannot even set fan speed (needs
X11 + Coolbits, unavailable on Talos). A loud fan means the GPU was genuinely hot doing genuine
work. It is a symptom of the crash-loop, not a fault, and not a thermal-management failure.

Live state confirms the card is healthy: `Fan 0% / 43C / P8 / 2W of 220W`, zero Xid, zero AER,
zero NVRM error lines this boot.

## Ruled out, with evidence — do not re-litigate

- **There is no VRAM leak.** `10,435 MiB / 12,282 MiB` in use is vLLM's intentional KV-cache
  preallocation: `--gpu-memory-utilization 0.85` x 12,282 = 10,440 MiB. `timeSlicing.replicas: 1`
  means `nvidia.com/gpu: 1` hands the whole device to one pod, so there is no VRAM contention by
  construction. **Leave 0.85 alone; keep persistence mode On.**
- **"No running processes found"** from `nvidia-smi` was an artifact of running it in a container
  without `hostPID`. It reports device memory but not PIDs in other namespaces.
- **`nvidia-container-cli: nvml error: unknown error`** and the 182 `gpu-feature-discovery`
  restarts are host memory starvation, not a GPU fault. The prestart hook must fork and
  initialize NVML, allocating locked host memory; at `MemAvailable` = 47 MB that fails or the
  hook is OOM-killed mid-init. Resolves when Phases 1-2 land.
- **`pcie_aspm=off` is not the cause and must not be removed.** See Decision 3.

## Corrections to earlier analysis

Recorded so the same wrong turns are not retaken:

- The GPU **is** in a Thunderbolt/USB4 eGPU enclosure (`docs/hardware.md`; pve2 is a mini PC
  that cannot house a 4070 Super internally; `netops_thunderbolt_authorized{proxmox_host="pve2"}`
  is dashboarded). `docs/hardware.md` is **not** stale on this point. An earlier claim that this
  is plain PCIe passthrough was wrong.
- `mlops-work-00` **is** ballooned despite VFIO passthrough — measured at ~8.37 GiB against
  16384 MiB dedicated. An earlier claim that VFIO pinning exempts it is wrong.
- **The control plane is `192.168.2.195`**, not `192.168.2.18`. Any `talosctl -n 192.168.2.18`
  command will fail.
- There **is** a remote-write backend: `http://prometheus.homelab.internal:9090/api/v1/write`
  with 15d retention at the `application` hub. The empty-endpoints Service on mlops is a normal
  agent-mode artifact. The reason there is no telemetry is Decision 5, not agent mode.

---

# ~~Blocking unknown~~ — resolved 2026-10-02

**`pve2` is 32 GiB installed, 31.05 GiB usable.** `docs/hardware.md` was right. Host stats:
85.79% RAM used (26.63 of 31.05 GiB), KSM sharing 1.26 GiB, swap 41.59% (3.33 of 8.00 GiB).

The sizing target proposed below was **6144 / 16384 / 6144 = 28,672 MiB**, and that is exactly what
is applied — `kubernetes/terraform/mlops/terraform.tfstate` shows `dedicated` 6144 / 16384 / 6144 and
`floating: 0` on all three VMs. Decision 1 landed in full, 1a and 1b together.

Two corrections to what is written below:

1. **"leaving ~4 GiB for the host" used 32,768 MiB as the denominator.** Against the 31,795 MiB the
   host actually reports, 28,672 MiB leaves 3,123 MiB ≈ 3.05 GiB for PVE plus ZFS ARC. With ~2 GiB
   of PVE overhead and ~1 GiB of ARC that is fully consumed, which is why the host is swapping
   3.33 GiB and KSM is active. 90.2% committed is too tight, not comfortable.
2. **`kubernetes/terraform/mlops/main.tf` still reads 8096 / 16384 / 8120** — it was never updated
   to match the apply. The committed code asks for 102.5% of the host. An apply that reads it
   without the overrides that produced the 6144 values would re-create the original defect.

Fixing that file is the open action from this story. The structural fix for the remaining 90.2% is
in `.ai/stories/workload-reallocation.md`, not here.

---

# Decisions

### 1. Remove ballooning **and** right-size `ram_dedicated` in the same change

*Status 2026-10-02: done.* `floating` removal is committed (`88d0893`) **and applied** — tfstate
shows `floating: 0` on all five VMs across both clusters, and `dedicated` 6144 / 16384 / 6144 on
mlops. Live `MemTotal` tracks `dedicated` on every node. The one loose end is that
`kubernetes/terraform/mlops/main.tf` was never updated to the applied values; see the resolved
blocking unknown above.

Applying it alone would hand the hypervisor a hard 31.8 GiB commitment with nothing left for
PVE: VMs fail to start, or the host OOM-killer shoots qemu. **1a (remove `floating`) and
1b (reduce `ram_dedicated`) must land in one apply per node.** Both require a power cycle —
the balloon device is only truly gone after one, and `dedicated` cannot be reduced on a running
guest.

Also: strip the inline comment added at `main.tf:28`; rationale belongs in a README.

### 2. Enforce `max(pod memory limit) < node allocatable`

This is the invariant whose violation turned overcommit into global OOM. Reservations are
defence-in-depth, not a fix for ballooning — they are subtracted from a capacity that is itself
a lie once the hypervisor reclaims RAM. `evictionHard` is the one guardrail that partially
survives ballooning, because kubelet re-derives `memory.available` from live stats each
housekeeping interval; it would have evicted pods in an orderly way before the kernel reached
`etcd` and `kubelet`.

`tf_modules/talos_cluster/patches/kubelet.yaml` currently sets only `nodeIP.validSubnets` and is
shared by all three differently-sized nodes. Make reservations per-node: add an optional
`kubelet_reserved` object to the node type in `variables.tf` and render `kubelet.yaml` via
`templatefile` in `config.tf` (the module already per-node-templates `worker.yaml.tftpl` and
`controlplane.yaml.tftpl`). Set only accounting values plus `evictionHard` — Talos forbids cgroup
overrides, so do **not** set `kubeReservedCgroup`/`systemReservedCgroup`.

Note `etcd` lives in Talos's `podruntime` cgroup with containerd and kubelet, **not** `kubepods`,
so `kubeReserved` does not protect it. What protects it is keeping total pod usage below
allocatable. `allowSchedulingOnControlPlanes: false` means ctrl-00 runs no tenant pods — its
etcd OOM was caused purely by the balloon, and un-ballooning alone should fix it.

### 3. Keep `pcie_aspm=off` — load-bearing, do not remove

Confirmed live in `/proc/cmdline`. Correctly placed in `tf_modules/talos_cluster/image.tf` as
`local.gpu_kernel_args` → `customization.extraKernelArgs`, gated on `igpu = true`, which is the
canonical Talos mechanism for permanent kernel args. Omni cluster-template `kernelArgs` is not
applicable — this cluster is Terraform-managed via `siderolabs/talos` + `bpg/proxmox`.

**Why it matters:** ASPM L0s/L1 and L1-substate transitions add latency and jitter to PCIe
transactions, which on Thunderbolt/USB4 tunneling stalls host-to-device DMA during vLLM weight
loading. Link-transition latency is a performance property, so it produces **no AER counters by
construction** — the absence of AER signal is consistent with the flag being necessary, not
evidence against it. It was verified to have improved vLLM behaviour in practice.

**Kernel-arg changes are image-identity changes.** The chain:

```
gpu_kernel_args -> node_schematic -> node_image_hash = substr(sha256(schematic),0,12)
  -> node_image_key "<host_node>-<hash>" -> proxmox_download_file.file_name
  -> proxmox_virtual_environment_vm.disk.file_id
```

A one-character edit renames the image and changes the VM's boot `disk.file_id`, which can
surface as re-image or full VM replacement. Reapplying machine config does **not** take effect;
Talos requires booting the new asset or a no-op upgrade. Safe procedure:

1. `-target` only the new `proxmox_download_file` so the asset exists without touching VMs.
2. `talosctl -n <node> upgrade --image factory.talos.dev/installer/<new-schematic-id>:v1.11.5`
   (upgrading to the same version is supported and is what makes the arg take effect).
3. Reconcile Terraform so it does not want to replace the VM — consider adding `disk[0].file_id`
   to the existing `lifecycle.ignore_changes` in `main.tf`, since `file_id` only matters at
   install time.
4. Verify: `talosctl -n mlops-work-00 read /proc/cmdline | tr ' ' '\n' | grep pcie_aspm`.
   Declared in Terraform is not the same as booted with.

**Unverified:** whether `bpg/proxmox` treats `disk.file_id` as ForceNew. A `tofu plan` after a
deliberate arg change decides whether step 3 is required. Do not skip — the failure mode is a
wiped node. Also worth 5 minutes: whether `machine.kernel.extraArgs` is valid in Talos v1.11
(it appears in a v1.11 RPi doc but not in the `machine.kernel` config reference); if real, it is
a no-image-rebuild path that would simplify all of the above.

Minor: `overwrite = false` plus `ignore_changes` means superseded images accumulate in the
`local` datastore on pve2. Add a cleanup note.

### 4. Keep GPU fault *detection*; delete the *actuation*

Two planning passes diverged here and this is the reconciled position. The topology argument is
**withdrawn** — the Thunderbolt/Xid-119 premise in `watch.sh` matches the hardware, so
"wrong hardware" is not a reason to remove anything. Detection is cheap and the fan/Xid
correlation is real. What is asymmetric is **autonomous cordoning on a leading indicator**, on a
cluster with exactly one GPU node, plus an actuation path that is variously broken and dangerous.

So: keep the detectors, strip the authority to act. Reasons the actuation must go, in descending
strength:

1. **Its primary action is a no-op on the real signature, and it reports success.**
   `scripts/recover.sh:63-67` returns success when `nvidia-smi` is responsive and no compute
   apps are listed — precisely the observed state. It then records `success`,
   `clear_node_condition` → `kubectl uncordon`, exit 0. It would have cordoned a starving node,
   done nothing, declared victory, and uncordoned. Worse than absent.
2. **The escalation path is non-functional three ways.** `ENABLE_NODE_REBOOT=false`;
   `recover.sh` invokes `/usr/local/bin/talosctl` but the image is `alpine/k8s:1.30.3`, which
   does not ship it; and the `gpu-recovery-talosconfig` Secret it mounts does not exist and has
   no manifest anywhere in the repo.
3. **Its middle steps are dangerous here.** `nvidia-smi -r` and in-guest PCI remove/rescan/bind
   operate on a VFIO-passed-through function. Removing the device from the guest's virtual PCI
   bus does not re-run the hypervisor's VFIO binding, so the likely outcome is the guest losing
   the GPU until the VM is power-cycled. *(Reasoned from VFIO behaviour; not tested on this host.)*
4. **Standing privilege for zero demonstrated value.** Always-on `privileged` + `hostPID` +
   `SYS_ADMIN`/`SYS_PTRACE` + host `/sys` RW, plus cluster-wide `nodes` patch/update, `pods`
   delete and `pods/eviction` create in all namespaces — a standing cluster-wide DoS primitive.
   Against it: `gpu-recovery-state` contains only `initialized: "true"`. It has never recovered
   anything.
5. **It is BestEffort**, so it dies from the condition it exists to handle. Its current process
   only started 15:25Z the day of investigation. The watchdog shares the failure domain it
   watches and structurally cannot witness an overnight event.

**Keep:** `runtimeclass.yaml`, `priorityclass.yaml`, and node-problem-detector with the Xid and
fallen-off-bus rules — cheap, generic, correct. Keep NPD as a **detector**. Keep the fan metric
as a *warning-level alert* only (see the alert list below): a fan at 95% under real inference
load is correct behaviour, not a fault, but it is still worth seeing.

**Delete:** the actuation and its privilege — `recovery-daemonset.yaml`, `recovery-job.yaml`,
`recovery-configmap.yaml`, `recovery-rbac.yaml`, `scripts/watch.sh`, `scripts/recover.sh`, the
`configMapGenerator` block in `kustomization.yaml`, and `kubernetes/.taskfiles/gpu/Taskfile.yaml`.

**If instead you choose to keep the DaemonSet** (the ADR's preferred shape), the minimum set of
changes is: remove its cordon authority and the cluster-wide `nodes` patch / `pods delete` RBAC;
delete the `nvidia-smi -r` and in-guest PCI remove/rescan steps; fix `recover.sh:63-67` so
"responsive and idle" is not reported as a successful recovery; remove the non-functional
`talosconfig` volume; and give it a memory request. Note `priorityClassName:
system-node-critical` governs *preemption*, not OOM-kill ordering — the memory request is what
moves `oom_score_adj`. Until its QoS is fixed, **absence of a `gpu-recovery` signal is not
evidence of absence of the fault**, and any new detector built on it inherits that blind spot.

**Deletion mechanics — do not miss this.** The nvidia tree is applied by a `presync` hook,
`kustomize build ... | kubectl apply -f -`. `kubectl apply` does not delete removed resources.
Removing manifests from `kustomization.yaml` leaves the privileged DaemonSet running forever.
An explicit `kubectl delete` (or `apply --prune` with a label selector) is required. No Helmfile
stage reordering is needed — everything is inside stage 03.

**Break-glass replacement already exists:** `kubernetes/.taskfiles/talos/Taskfile.yaml` provides
`reboot-node`. Document: cordon → drain → `task kubernetes:talos:reboot-node NODE=<ip>` → if the
guest reboot does not reset the passed-through device, `qm stop/start <vmid>` on pve2, which also
re-runs the VFIO bind. **A VM power cycle is the only reliable device reset on this topology** —
module unload/reload is not an available Talos operation (`/lib/modules` is read-only, modules
are declared in machine config and loaded at boot, and containerd plus the device plugin hold
references). This is a platform constraint, not a gap to engineer around.

**Alerts are currently inert and must move.** `xid-alerts.yaml` is applied into mlops
`kube-system`, but mlops runs agent mode with `alertmanager.enabled: false` and evaluates no
rules, while the hub selects rules from the *application* cluster's namespaces. Move them to
`platform/observability/kubernetes/apps/prometheus/overlays/application/rules/` and delete the
mlops copy. While moving:

- Delete `GPUFanRunaway` — a fan at 95% under real inference load is correct behaviour.
- Delete `GPURecoveryCircuitBreakerOpen` — its expr is
  `kube_configmap_info{configmap="gpu-recovery-state"}`, which is 1 whenever the ConfigMap
  exists, so this `critical` alert fires unconditionally from the first recovery attempt onward
  and claims "manual intervention required" forever.
- Rewrite `GPUFallenOffBus` — it contains `absent(DCGM_FI_DEV_GPU_UTIL{Hostname="mlops-work-00"})`,
  a hardcoded hostname that fires whenever DCGM simply is not scraped, i.e. the current state.
- Consolidate with the near-duplicate `overlays/application/rules/gpu-alerts.yaml`
  (`GPUXidError` vs `GPUXidFatalError`).

### 5. Do not enable node-reboot escalation

Least-privilege Talos role that can reboot is **`os:operator`** (`os:reader` cannot; `os:admin`
is broader). It also grants **shutdown of any node, including the sole control plane**, and
`talosctl --nodes` is cluster-wide. Mounting it in an always-on privileged `hostPID` DaemonSet
escalates that pod from host root on one node to `os:operator` on every node, and makes it the
highest-value target in the cluster alongside its existing cluster-wide `nodes` patch and `pods
delete` RBAC. The certificate has a TTL and this repo has no renewal automation, so it becomes a
silent expiry landmine — expired precisely when needed, with nothing reporting it.

Recurring real cost, to save a couple of minutes of manual work on a 3-node homelab with one GPU
node and one control plane. **Recommendation: no.** Remove the non-functional `talosconfig`
volume rather than provisioning the Secret.

If it is ever wanted, the pre-approved shape is
`talosctl -n 192.168.2.195 config new gpu-recovery-talosconfig --roles os:operator --crt-ttl <ttl>`,
SOPS-encrypted to `kubernetes/apps/hardware/nvidia/recovery-talosconfig.sops.yaml` (matches the
existing `kubernetes/*` SOPS path rule), materialized via a kustomize secret generator, scoped
through `machine.features.kubernetesTalosAPIAccess` with `allowedRoles: [os:operator]` in a
**dedicated namespace — not `kube-system`**, since that allowlist grants every pod in the
namespace the same mint. Fix its BestEffort QoS first or it will not be alive to use the
credential.

### 6. The telemetry gap: the metrics never existed

**Confirmed, not hypothesised.** The mlops PrometheusAgent carries
`serviceMonitorSelector: {matchLabels: {release: prometheus-community}}`. Live ServiceMonitor
labels:

| ServiceMonitor | `release` label | selected? |
|---|---|---|
| `default/netops-agent` | `prometheus-community` | yes |
| `observability/prometheus-community-*` | `prometheus-community` | yes |
| `kube-system/dcgm-exporter` | **none** | **no** |
| `kube-system/node-problem-detector` | **none** | **no** |
| `kube-system/cilium-envoy`, `kube-system/hubble` | none | no |

A ServiceMonitor without that label is created and then **silently ignored — no targets, no
error**. So **every DCGM-based alert in the repo has never had data**, and NPD's metrics never
arrived either. `kubernetes/apps/hardware/netops/values.yaml` documents this exact trap and adds
the label for that reason; dcgm-exporter and NPD do not.

Compounding it, the mlops overlay disables `nodeExporter`, `kubeStateMetrics`, and `kubelet`.
There is no `node_memory_MemAvailable_bytes`, no `node_vmstat_oom_kill`, no
`kube_node_status_capacity` and no kubelet metric for mlops anywhere. **No alert about this
failure could have been written, regardless of pod placement.**

On placement: with two workers and the GPU pinned to work-00, no placement makes the monitoring
plane independent of what it monitors, and control-plane placement is unavailable
(`allowSchedulingOnControlPlanes: false`). The durable record already lives off-cluster at the
hub with 15d retention, which is the right architecture. So the fix is **resources, not
relocation** — plus rebalancing work-01, the *smallest* node, which currently carries
cert-manager, CNPG, the Prometheus agent, the otel operator and the otel collector.

Anything whose job is to observe or repair a memory-pressure event must have a memory request.
Currently BestEffort: the gpu-recovery watcher, the mlops Prometheus agent, and the kagent agent
pods.

### 7. ~~Relocate `mlops-work-01` to host `pve`~~ — superseded: delete the node instead

> **Superseded 2026-10-01 by Decision 8 in `.ai/stories/workload-reallocation.md`.** Relocation
> and deletion free the same 8120 MiB on `pve2`; deletion avoids the replacement-forcing VM
> rebuild and the 6 vCPU added to `pve`. The host-memory table and the CPU reasoning below remain
> valid and are why relocation was narrowed to one node — they are kept as the record of how that
> conclusion was reached. The relocation *action* is not to be taken.



Both Proxmox hosts are in one PVE cluster (single `provider "proxmox"` block, one endpoint, the
module targets both by `node_name`), so this is available. Host memory budget on pve2:

| scenario | pve2 committed |
|---|---|
| today | 99.5% |
| shrink `ram_dedicated` only (1b) | 87.5% |
| relocate work-01 only | 74.7% |
| relocate work-01 + ctrl-00 | 68.8% |

**Do 1b now as the cheap unblocker.** ~~Relocation as the structural fix, `work-01` only.~~
The structural fix is node deletion — see Decision 8 in `workload-reallocation.md`.
Three costs decide the "only":

1. **CPU, not RAM, is the binding constraint on `pve`.** The M11SDV-8C-LN4F is an 8-core /
   16-thread EPYC 3251 at ~55 W — "low powered and quiet" in `docs/hardware.md` is a statement
   about the CPU, and it is accurate. The application cluster already allocates 4 + 4 = 8 vCPU.
   Adding work-01 (6 vCPU) reaches 14 of 16 threads, which is workable. Adding `ctrl-00` (8 vCPU)
   as well would be 22 vCPU on 8 physical cores — 2.75x core over-commit. **This is the reason to
   move one node, not two.**
2. **Relocation forces a VM rebuild by construction.** `host_node` feeds `node_image_key` →
   `disk.file_id`, and `node_name` is replacement-forcing in `bpg/proxmox`. Terraform will not
   migrate a VM between hosts. Same coupling as Decision 3.
3. **`work-01` holds node-local data, so that rebuild is destructive.** Postgres uses
   `storageClass: local-path` 10Gi pinned to that hostname; Qdrant and n8n are pinned there too.
   A migration plan is mandatory: `pg_dump`/restore, Qdrant snapshot, and n8n's existing export
   CronJob. Also confirm `pve` has `local-lvm` with >=40 GiB free plus `local` for the image
   download — `datastore_id` is not overridden and defaults to `local-lvm`.

`ctrl-00` stays on pve2. **Correcting a cost stated earlier:** cross-host etcd latency is the
wrong worry, because mlops runs a *single* control-plane member — there is no quorum traffic to
slow down, so that cost is zero. The real risk is differently shaped and larger: replacing a
single-member etcd node is a snapshot-and-restore operation, not a rolling move. That is why
`ctrl-00` does not move. What does start crossing the LAN after relocation is kubelet↔apiserver
and Cilium pod-to-pod traffic — a latency question, not a correctness one.

Consequences to accept: a destructive PV rebuild on `work-01`, and mlops becomes asymmetric
across hosts with its control plane sharing the GPU host. Upside beyond memory: it resolves the
"no placement makes monitoring independent of what it monitors" limitation in Decision 6, which
until now had no expiry date.

---

# Implementation

## Phase 0 — Pre-flight (blocking, read-only)

1. **pve2 memory budget** (see Blocking unknown). Decides Phase 2 numbers.
2. Confirm ballooning is what moved: `qm config 100 102 103 | grep -Ei 'memory|balloon'`,
   `journalctl -u pvestatd | grep -i balloon`.
3. **Read the pending plan.** `tofu -chdir=terraform/mlops plan` with the `-var` set from
   `kubernetes/Taskfile.yml`. `config.tf` has
   `replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]`, so a VM change
   replaces `talos_machine_configuration_apply` — a harmless config re-apply.
   **If the plan shows `proxmox_virtual_environment_vm` itself as `-/+ destroy and then create`,
   STOP — that wipes node disks.** Verify, do not infer.
4. Read effective current reservations before choosing new ones:
   `talosctl -n <node> get kubeletconfig -o yaml`, `talosctl -n <node> cgroups --preset=memory`.
   Talos already sets defaults; do not set values worse than they are.
5. **etcd snapshot now**, stored off pve2:
   `talosctl -n 192.168.2.195 etcd snapshot ./mlops-etcd-preincident.db`.
   Single control-plane member — there is no quorum to fall back on.

## Phase 1 — Stabilize, one node at a time

Order: work-01 first (already down, zero marginal cost, validates the procedure); work-00 second
(draining it needs work-01 healthy); ctrl-00 last (single point of failure, prove workers first).

Each node gets **one** window doing both the `floating` removal and its `ram_dedicated` change.
Use `-target` per node with the `-var` set from `kubernetes/Taskfile.yml`.

**1.1 `mlops-work-01`** — cordon; set final `ram_dedicated`; targeted apply;
`qm config 103 | grep balloon` → expect absent/0; `qm stop 103 && qm start 103`. Verify in order:
`MemTotal` matches `dedicated`; `kubectl get node mlops-work-01 -o jsonpath='{.status.capacity.memory}'`
now matches live `MemTotal`; `cgroups --preset=memory` shows nothing near its limit; dmesg clean
of OOM since boot. Uncordon; confirm cert-manager, CNPG and the Prometheus agent return Ready.
Confirm the control plane was untouched.

**1.2 `mlops-work-00` (GPU node, planned outage)** — **scale GPU consumers to zero first** so
nothing is mid-CUDA and the heating crash-loop stops:
`kubectl -n ai scale deploy/vllm-selfhosted --replicas=0`, then the kagent agents. Confirm
`nvidia-smi` shows 0 MiB FB used. Cordon, drain. Set `ram_dedicated` (keep 16384). Targeted
apply; `qm stop 102 && qm start 102`. GPU verification — the `hostpci0` mapping re-binds at VM
start:

- on pve2: `dmesg | grep -i vfio` → clean bind of `nvidia_4070_super`
- `talosctl -n 192.168.2.19 read /proc/cmdline` → **`pcie_aspm=off` still present**
- `talosctl -n 192.168.2.19 dmesg | grep -iE 'nvrm|xid|aer'` → clean
- `nvidia.com/gpu: "1"` in node allocatable
- device-plugin restart counts stop climbing

Uncordon; scale vLLM back to 1 and watch its 10-minute startup budget. The power cycle also
clears any wedged NVML state.

**1.3 `mlops-ctrl-00` (last, highest risk)** — fresh etcd snapshot off pve2. **State the blast
radius rather than engineering around it:** with one control-plane member there is no rolling
procedure and no quorum to preserve. Accept a ~1-2 min full control-plane outage with a
restorable snapshot. During the window worker kubelets keep running existing pods, Cilium keeps
forwarding, nothing new schedules, no API. Its 8096 MiB is likely already correct (no tenant pods
land there) — change only `floating`. Verify `talosctl health`, `service etcd status`,
`kubectl get --raw '/readyz?verbose'`, `MemTotal`, and `podruntime` comfortably under its limit.

**1.4 Exit `-target`** — run a full un-targeted `plan`. It must be empty; anything left is drift.

## Phase 2 — Guardrails so it cannot recur silently

1. Per-node `kubeReserved` / `systemReserved` / `evictionHard` via the `templatefile` refactor
   (Decision 2).
2. vLLM `requests.memory` 6Gi → **4Gi**, `limits.memory` 12Gi → **8Gi**. The point is not to
   shave memory but to make the invariant hold: the pod's own cgroup must bind before the node
   does. Remember the `shm: emptyDir medium: Memory sizeLimit: 2Gi` counts as node RAM.
3. **Highest-leverage single change:** add a `LimitRange` to the `ai` namespace with `default`
   and `defaultRequest` for cpu and memory. This retroactively gives **every** kagent agent pod
   a request and limit without touching the kagent chart or each Agent CR — the actual fix for
   the 8 OOM kills, and therefore for the fan.
4. `platform/ai/kubernetes/resource-quotas.yaml`: `limits.memory: 24Gi` exceeds any single node's
   capacity, and the GPU nodeSelector means the whole `ai` namespace lands on one node. Reduce to
   ≤ that node's allocatable.
5. Add `resources.requests` to the mlops Prometheus agent.

## Phase 3 — Make it observable

1. Enable `nodeExporter`, `kubeStateMetrics` and `kubelet` on the mlops overlay. Cost: one small
   DaemonSet and one small Deployment. Nothing below can be written without this.
   Gotchas: node-exporter needs the privileged `observability` namespace (already documented in
   `04-monitoring.gotmpl.yaml`); kubelet scraping needs serving certs, and
   `kubelet-csr-approver/values.yaml` already lists all three mlops nodes.
2. **Add `additionalLabels: {release: prometheus-community}`** to the dcgm-exporter and NPD
   ServiceMonitors (Decision 6). Add scrape annotations or a labeled ServiceMonitor for vLLM,
   which currently has neither.
3. Alerts, in value order:
   1. `increase(node_vmstat_oom_kill[15m]) > 0` → critical. Best value-per-effort in this plan.
   2. Balloon/stale-capacity divergence:
      `abs(kube_node_status_capacity{resource="memory"} - on(node) group_left() node_memory_MemTotal_bytes) / kube_node_status_capacity{resource="memory"} > 0.05`
      for 10m → critical. The label join needs work (node-exporter `instance` → KSM `node`);
      treat the expression as a starting point.
   3. `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes` < 0.10 for 5m (warning),
      < 0.05 for 2m (critical).
   4. `kube_node_status_condition{condition="Ready",status="true"} == 0` for 5m, plus
      `up{job="kubelet"} == 0`. Today a kubelet that stops posting status is invisible.
   5. `increase(kube_pod_container_status_restarts_total{namespace="ai"}[30m]) > 3` and
      `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1`. **This is the
      alert that maps to the original complaint** — it surfaces kagent-adk x8 and GFD x182.
   6. GPU: **not** "FB_USED high with zero compute apps" — that is a permanent false positive
      given 0.85 preallocation on an exclusive card, and the "zero apps" half was a hostPID
      artifact. The real signal is sustained `DCGM_FI_DEV_GPU_UTIL` / `DCGM_FI_DEV_POWER_USAGE`
      **not** accompanied by vLLM serving work (`vllm:num_requests_running` and token rate ~0) —
      i.e. "the card is being cooked by a retry loop."
   7. Hub-side staleness/dead-man's switch on the `cluster="mlops"` series. Today a dead agent
      looks identical to a quiet cluster.
4. Rebalance work-01: move the Prometheus agent to work-00, or unpin cert-manager/CNPG. Keep the
   otel agent on mlops — the Cilium global-service rationale for a local collector is sound.

## Phase 4 — Strip gpu-recovery's actuation, keep its detectors

Per Decision 4, including the explicit `kubectl delete` (a `presync` `kubectl apply` will not
remove what you delete from `kustomization.yaml`) and the alert move to the hub.

## Phase 5 — Same fix on `application` — *done*

`kubernetes/terraform/application/terraform.tfstate` now shows `floating: 0` on both VMs
(`dedicated` 8192 and 12192 on host `pve`). The module fix covered them. No action.

---

# Repo hygiene

1. **Add `kubernetes/apps/hardware/nvidia/README.md`**: why `pcie_aspm=off` lives in the Image
   Factory schematic and the Decision 3 procedure for changing it; the ballooning incident and
   the two invariants (never set `floating`; `max(pod memory limit) < node allocatable`); why
   `--gpu-memory-utilization 0.85` is correct and not a leak; why gpu-recovery was removed and
   what the manual break-glass is. Then strip the long inline comment blocks from `npd-values.yaml`
   and the alert files.
2. **Add `tf_modules/talos_cluster/README.md`** and remove the inline comment at `main.tf:28`.
3. **Dead files:**
   - `kubernetes/apps/hardware/nvidia/helm-values.yaml` — not referenced by the release, and its
     `gfd.enabled: false` **contradicts** the `gfd.enabled: true` actually deployed. This is why
     GFD runs (and restarts) despite a repo file that appears to disable it. Delete.
   - `tf_modules/talos_cluster/patches/host-dns.yaml` — referenced by neither branch of
     `config.tf`. Decide deliberately: the absence of `forwardKubeDNSToHost: false` +
     `resolveMemberNames: true` may be load-bearing for Cilium ClusterMesh DNS.
4. **Stale comments:** `deployment.yaml` and `resource-quotas.yaml` both assert "~15.5Gi
   allocatable", which was never true under ballooning and changes again once reservations land.

---

# Suggested commit sequencing

1. Phase 0 — read-only, no commits.
2. `tf_modules/talos_cluster`: per-node reservations + `evictionHard` + module README. Not applied.
3. `kubernetes/terraform/mlops/main.tf`: final `ram_dedicated` from Phase 0.
4. Staged apply 1.1 → 1.2 → 1.3 → 1.4. No commits; record verification output in an ops note.
5. `platform/ai`: LimitRange + vLLM limits + quota correction.
6. Observability: enable exporters, add `release` labels, move and fix GPU rules, add alerts.
7. Retire gpu-recovery + explicit delete + nvidia README.
8. `application` cluster ballooning fix.

**If time is short:** Phase 0, Phase 1, plus `node_vmstat_oom_kill` and the `ai` LimitRange
deliver most of the value.

---

# Open questions

1. *Resolved 2026-10-02.* pve2 is 32 GiB / 31.05 usable; see the resolved blocking unknown. ZFS
   ARC size is still unread and still competes with the VM budget.
2. Whether the pending plan replaces only `talos_machine_configuration_apply` or also the VMs.
   A VM replace wipes disks. Must be read, not inferred.
3. Whether `bpg/proxmox` treats `disk.file_id` as ForceNew.
4. Whether `machine.kernel.extraArgs` is valid in Talos v1.11 — if so, a much simpler kernel-arg
   path than Decision 3.
5. Effective current Talos kubelet reservations and cgroup limits.
6. Whether the kagent `v1alpha2` Agent CRD exposes pod `resources` (no CRDs found under the
   vendored chart). Determines whether the LimitRange is the only available mechanism.
7. netops-agent's metric surface (sibling repo). pve2 already runs a host exporter scraped as
   `job="netops-host"` — if it exposes host memory or a balloon actual-vs-target signal, that is
   the cheapest possible hypervisor-side detector and beats the divergence alert on both effort
   and directness.
8. Where NVIDIA persistence mode is set On — not found in this repo. Minor; leave it alone.
9. `platform/ai/kubernetes/harness/hermes.yaml` and
   `platform/ai/agents/computer_control/chart/templates/agent.yaml` not read — check for the same
   missing-resources gap.
10. *Resolved, then superseded.* Relocation was evaluated and narrowed to `mlops-work-01`
    only (Decision 7), then dropped in favour of deleting the node — see Decision 8 in
    `.ai/stories/workload-reallocation.md`. The `pve` `local-lvm` capacity sub-question is moot:
    no VM is created on `pve`.
11. **`kubernetes/terraform/mlops/main.tf` reads 8096 / 16384 / 8120; the apply is
    6144 / 16384 / 6144.** Code-vs-state drift of 3.9 GiB. Correcting the file is a no-op plan and
    should ship on its own. Whatever supplied the 6144 values (Taskfile `-var`, `.env`, tfvars) has
    to be found first, or the drift just moves. See Phase 0 of `workload-reallocation.md`.
