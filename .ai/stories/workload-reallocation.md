# Goal

Shrink `mlops` from three nodes to two by deleting `mlops-work-01`, moving the non-GPU
workloads it carries onto the `application` cluster, and leaving `mlops` as an honestly
single-purpose GPU cluster.

This supersedes Decision 7 of `gpu-hardware-reliability.md` ("Relocate `mlops-work-01` to host
`pve`"). Both options free the same 6144 MiB on `pve2`; this one does it without a cross-host VM
rebuild and without adding 6 vCPU to `pve`'s 8-core EPYC 3251.

Scope: `kubernetes/terraform/mlops/main.tf`, `kubernetes/clusters/mlops/environment.yaml`, the
`platform/data`, `platform/automation` and `platform/ai` stacks, and the NFS StorageClass gap on
`application`. Out of scope: anything that needs the GPU.

---

# Where the RAM saving actually comes from

Deleting the `work-01` VM frees 6144 MiB on `pve2` **regardless of where its pods land**. Pods
could simply reschedule onto `mlops-ctrl-00` and `mlops-work-00`, and `pve2` would still drop from
90.2% to 70.9% committed.

So moving workloads to `application` is not what buys the memory. It buys **not re-concentrating
non-GPU load onto the GPU node**, which is the node that was failing in the first place. Keep
those two claims separate; conflating them overstates the case for the harder half of the work.

The arithmetic that makes re-concentration unattractive:

| mlops node | allocatable | mem requested | mem limits | free |
|---|---|---|---|---|
| mlops-ctrl-00 | 4.48 GiB | 1,952 Mi (42%) | 3,464 Mi (75%) | ~2.6 GiB |
| mlops-work-00 | 13.82 GiB | 11,680 Mi (82%) | 24,636 Mi (174%) | ~2.4 GiB |
| mlops-work-01 | 4.48 GiB | 3,196 Mi (69%) | 7,412 Mi (161%) | — |

`work-00` is the GPU node and already at 82% requested / 174% limits. The movable set is ~2,048 Mi
of requests, which *would* fit across the two remaining nodes — but it lands on a node whose
limit over-commit is already the worst in the fleet.

`application` has the room, and at a quarter the pressure:

| application node | vCPU | allocatable | mem requested | free |
|---|---|---|---|---|
| application-ctrl-00 | 4 | 6.35 GiB | 1,952 Mi (30%) | ~4.4 GiB |
| application-work-00 | 4 | 9.99 GiB | 3,140 Mi (30%) | ~6.9 GiB |

~11.4 GiB free against ~2.0 GiB of incoming requests and ~4.75 GiB of incoming limits. `pve` has
idle RAM, so `ram_dedicated` can be raised there later without contention. CPU requests on
`application` are 840m and 980m against 4 vCPU each — the incoming set adds well under a core.

---

# Corrections to the 2026-09-26 analysis

Verified against both live clusters and the repo on 2026-10-01. Five things have changed or were
wrong.

### The vLLM invariant is already satisfied

Sep 26 called the vLLM limit reduction "mandatory, not optional" for this plan.
`platform/ai/kubernetes/llm-providers/selfhosted/deployment.yaml` now sets
`limits.memory: 8Gi` against ~13.8 GiB allocatable. Decision 2's invariant holds. This is no
longer a precondition.

`work-00` is still at 174% memory limits, but the cause is now the ~22 kagent agent pods in `ai`
(128Mi request / 256Mi–1Gi limit each) plus vLLM's 8Gi — the LimitRange landed, so they are no
longer BestEffort. That is a separate sizing question and does not block this work.

### There are twelve hostname pins, not two

Sep 26 named only the two n8n pins. The full inventory of `mlops-work-01` references:

| file | what it pins |
|---|---|
| `kubernetes/clusters/mlops/environment.yaml:17,19` | cert-manager, cnpg (via helmfile `nodeSelector`) |
| `kubernetes/apps/networking/externaldns/internal-values.yaml.gotmpl:50` | internal external-dns |
| `kubernetes/apps/networking/externaldns/external-values.yaml.gotmpl:24` | public external-dns |
| `kubernetes/apps/gitops/argocd/values.yaml.gotmpl:31,35` | argocd (not deployed — `gitops: false`) |
| `kubernetes/apps/security/kubelet-csr-approver/values.yaml:2` | `providerRegex` allowlist |
| `kubernetes/terraform/mlops/main.tf:54` | the VM itself |
| `platform/observability/.../prometheus/overlays/mlops/values.yaml:12,15` | Prometheus agent |
| `platform/ai/kubernetes/integrations/openwebui/values.yaml:126` | open-webui |
| `platform/ai/kubernetes/integrations/openedai-speech/deployment.yaml:22` | openedai-speech |
| `platform/automation/kubernetes/n8n/deployment.yaml:28` | n8n |
| `platform/automation/kubernetes/n8n/cronjob-workflow-export.yaml:26` | n8n export CronJob |
| `platform/data/kubernetes/apps/postgres/cluster.yaml:15` | postgres |
| `platform/data/kubernetes/apps/qdrant/kustomization.yaml:38` | qdrant |

`kubelet-csr-approver`'s `providerRegex` is the one that bites silently: leave `work-01` in it and
nothing breaks, but it is a stale allowlist entry. The `environment.yaml` pins are the cleanest —
they already render as `{}` on `application`, so removing them is a two-line edit.

### n8n's data migration is free; postgres, qdrant and open-webui are the hard ones

Sep 26 concluded "n8n is the real friction, not postgres." That is right about the *wiring* and
backwards about the *data*.

n8n binds a **static** PV (`platform/automation/kubernetes/automation-platform-storage.yaml`,
`persistentVolumeReclaimPolicy: Retain`) to the NFS share
`unas.internal:/var/nfs/shared/automation_platform_data` via `volumeName`. Recreating the same PV
and PVC on `application` reattaches the same directory. Zero copy, zero dump/restore.

The destructive ones are all `local-path`:

| claim | class | size | migration |
|---|---|---|---|
| `data/postgres-1` | local-path | 10Gi | `pg_dump` / restore |
| `default/qdrant-storage-qdrant-0` | local-path | 10Gi | snapshot / restore |
| `ai/open-webui` | local-path | 2Gi | backup / restore (chats, settings) |
| `automation/n8n-storage-pvc` | nfs-csi (static) | 15Gi | none — reattach |

### `application` has no `nfs-csi` StorageClass

The NFS CSI *driver* runs on `application` (controller + 2 node pods). The **StorageClass does
not exist** there: `kubernetes/apps/storage/nfs/overlays/` contains `administration/` and
`mlops/` but no `application/`. The helmfile hook at
`kubernetes/helmfile.d/01-bootstrap.gotmpl.yaml:154` builds
`../apps/storage/nfs/overlays/{{ $cluster }}`, gets nothing for `application`, and prints
"No NFS storage resources ... skipping" without failing.

This is a hard prerequisite for n8n. It is also small: one overlay directory and one StorageClass
manifest, mirroring `overlays/mlops/storageclass.yaml`.

### `platform/ai` and `platform/automation` cannot target `application` at all

Sep 26 treated open-webui and openedai-speech as a simple move. They live inside
`platform/ai/kubernetes/integrations/`, and `platform/ai/Taskfile.yml:56` **hardcodes the mlops
kubeconfig** with `status: test "{{.CLUSTER}}" != "mlops"`. `platform/automation/Taskfile.yml:17`
is gated the same way and has no `overlays/` directory.

Only `platform/data` and `platform/observability` ship per-cluster overlays. So moving anything
out of `ai` or `automation` requires restructuring those stacks first — this is the real cost of
the plan, and it was understated.

### `platform/data`'s application overlay is empty

`platform/data/kubernetes/overlays/application/kustomization.yaml` references only `../../base`.
Sep 26's "both overlays already exist; this is the supported path" is half true: the overlay
exists, the apps are not in it. Moving postgres and qdrant means adding them there and removing
them from `overlays/mlops`.

---

# Host reality on `pve2` (resolved 2026-10-02)

```
RAM usage    85.79% (26.63 GiB of 31.05 GiB)
KSM sharing  1.26 GiB
SWAP usage   41.59% (3.33 GiB of 8.00 GiB)
CPU usage    6.46% of 16 CPU(s)
Load average 1.54, 1.37, 1.27
```

### `pve2` is 32 GiB. The documented spec was right.

`docs/hardware.md` is accurate: 31.05 GiB usable of 32 GiB installed. The 2026-09-26 inference
that the spec might be stale — drawn from the VMs staying up at 32,600 MiB nominal — was wrong.
They stayed up because they were never actually given 32,600 MiB. See below.

This closes open question 1 of `gpu-hardware-reliability.md`.

### Ballooning is gone, and `ram_dedicated` right-sizing was already applied

`kubernetes/terraform/mlops/terraform.tfstate` (serial 14):

| node | applied `dedicated` | applied `floating` | live `MemTotal` |
|---|---|---|---|
| mlops-ctrl-00 | 6144 | 0 | 5,904 MiB |
| mlops-work-00 | 16384 | 0 | 15,969 MiB |
| mlops-work-01 | 6144 | 0 | 5,905 MiB |

`floating: 0` on all three — ballooning is fully off, and `MemTotal` tracks `dedicated` minus the
usual firmware/reserved overhead on every node. There is no balloon mystery and no drift between
kubelet capacity and real RAM.

**Decision 1b was applied — to exactly its proposed target of 6144 / 16384 / 6144 = 28,672 MiB.**
Per the 2026-09-26 session, another session ran the apply concurrently with that planning.

### The actual defect: `main.tf` never caught up

| | ctrl-00 | work-00 | work-01 | total |
|---|---|---|---|---|
| `kubernetes/terraform/mlops/main.tf` | 8096 | 16384 | 8120 | 32,600 MiB |
| applied (tfstate) | 6144 | 16384 | 6144 | 28,672 MiB |

The committed code asks for 102.5% of the host; the applied state asks 90.2%. The right-sizing was
applied via overrides and the file was never updated, so `main.tf` has been lying by ~3.9 GiB since
`3115b41`. The next `tofu apply` that reads `main.tf` without those overrides would re-inflate the
host back into over-allocation.

**This is the first thing to fix, and it is a one-file edit with no runtime effect.** It is also
what made the earlier read of this situation wrong: live `MemTotal` looked 2.2 GiB short of
configured RAM, which looks exactly like ballooning if you only read `main.tf`.

### 90.2% is still why the host swaps

28,672 MiB of 31,795 MiB leaves 3,123 MiB ≈ 3.05 GiB for PVE plus ZFS ARC. The GPU story's
"leaving ~4 GiB" used 32,768 MiB as the denominator rather than the 31,795 MiB the host reports.
Against the real figure, PVE overhead (~2 GiB) and ARC (~1 GiB from the 2026-09-26 `arcstat`,
`c` = 993M) consume essentially all of it — hence 3.33 GiB of swap and KSM working 1.26 GiB.

The guests are healthy: no `MemoryPressure`, no OOM or eviction events, all three booted
`2026-09-28T20:30:36Z` with kubelet capacity matching live `MemTotal`. The pressure is entirely
on the host, and it is paid in swap — which is a latency problem invisible from inside Kubernetes.

### This is the argument for consolidation

Trimming further is unattractive: `ctrl-00` is at 42% memory requested and `work-01` at 69%, so
there is little to take. Deleting a node is what actually buys the margin.

| scenario | total MiB | % of 31,795 | left for PVE + ARC |
|---|---|---|---|
| `main.tf` as committed (never apply this) | 32,600 | 102.5% | negative |
| applied today | 28,672 | 90.2% | ~3.0 GiB — swapping |
| 2 nodes, `ctrl-00` at 6144 | 22,528 | 70.9% | ~9.0 GiB |
| 2 nodes, `ctrl-00` at 8192 | 24,576 | 77.3% | ~7.0 GiB |

The Sep 26 figure of "74.7%" for deleting `work-01` was computed from the stale `main.tf` values
against a 32,768 MiB denominator. The correct number is **70.9%**, and it leaves 9 GiB — enough to
stop the swapping and still grow `work-00` later, which is where GPU work will want it.

### Remaining pre-flight

1. Confirm the swap is PVE/ARC and not guest pages. Host-swapped guest memory is a latency
   problem that looks like nothing from inside Kubernetes:
   ```
   ! ssh pve2.local 'cat /sys/module/zfs/parameters/zfs_arc_max; arcstat | head -2; for v in 100 102 103; do echo -n "vm$v "; grep VmSwap /proc/$(cat /run/qemu-server/$v.pid)/status; done'
   ```
2. Confirm nothing else overrides `ram_dedicated` — check `kubernetes/.env`, the Taskfile's
   `-var` wiring, and any `*.tfvars` — before editing `main.tf`, so the fix does not re-introduce
   the drift from the other direction.
3. Confirm whether `ram_dedicated` changes are in-place or replacement-forcing in `bpg/proxmox`.
   Read the plan; do not infer. A replace wipes disks, and `work-01` holds three `local-path` PVCs.
   This matters for Phase 7, not for the `main.tf` correction, which should produce an empty diff.
4. `/` on `pve2` is at 46.81% (43.97 of 93.93 GiB) while VM `disk_size` totals 260 GiB, so the
   disks are thin and elsewhere — confirm which datastore backs them before assuming the
   consolidation frees disk as well as RAM.

---

# Decision ordering

1. **Correct `main.tf` to 6144 / 16384 / 6144.** One file, no runtime effect, removes a live
   foot-gun. Verify with a plan that shows no changes.
2. **The consolidation** (Phases 1–6 below). This is what resolves the 90.2% and the swapping.
3. **Reclaim headroom afterwards** (Phase 7), deliberately and separately.

Do not trim `ctrl-00` or `work-01` below 6144 as an alternative to step 2 — they are at 42% and
69% memory requested respectively, and the GPU story's `max(pod limit) < allocatable` invariant
has to keep holding.

---

# Decisions

### 8. Delete `work-01`; do not relocate it (supersedes Decision 7)

Frees the 6144 MiB `work-01` actually holds, taking `pve2` from 90.2% to **70.9%** committed and
~9.0 GiB clear for PVE and ARC — enough to stop the swapping. (The Sep 26 figures of "8120 MiB"
and "74.7%" both came from the stale `main.tf` values.)

Avoided: a replacement-forcing VM rebuild (`node_name` is ForceNew in `bpg/proxmox`), 6 vCPU added
to an 8-core/16-thread EPYC 3251 already carrying 8 vCPU, and one more VM to patch and monitor.

Costs to accept:

1. **No drain target.** One worker means any `work-00` maintenance is a full `mlops` outage. The
   practical loss is smaller than it reads — GPU pods cannot migrate anyway, and Phase 1.2 of the
   GPU story already scales vLLM to zero for maintenance.
2. **The control plane shares the GPU host.** Unchanged from today, and unchanged by relocation of
   `work-01` either; `ctrl-00` was never moving.
3. **Decision 6's limitation persists.** Relocation would have made monitoring independent of
   what it monitors by putting the Prometheus agent on a different host. Deleting `work-01` does
   not: the agent moves to `work-00` or `ctrl-00`, both on `pve2`. The hub on `application`
   already scrapes across ClusterMesh, so the agent is not the only signal path — but the
   "monitoring is co-resident with the monitored" gap stays open, with no expiry date again.

### 9. Move the non-GPU workloads to `application`, not onto `work-00`

Per "Where the RAM saving actually comes from". `work-00` at 174% limits is not a landing zone.

The movable set, with current requests:

| workload | ns | requests | limits | blocker |
|---|---|---|---|---|
| postgres | data | 512Mi | 1Gi | local-path → dump/restore |
| qdrant | default | none | none | local-path → snapshot/restore |
| open-webui | ai | 512Mi | 2Gi | local-path; `platform/ai` is mlops-gated |
| openedai-speech | ai | 512Mi | 1Gi | `platform/ai` is mlops-gated |
| n8n | automation | 512Mi | 768Mi | gateways + DNS; stack is mlops-gated |
| firecrawl (playwright, worker) | automation | none | none | stack is mlops-gated |

Total: ~2,048 Mi requests, ~4.75 GiB limits.

What simply reschedules inside `mlops` once unpinned, and needs no migration: cert-manager (×3),
cnpg operator, external-dns-unifi, cilium-operator, the Prometheus agent, the otel operator.
What vanishes with the node: the cilium, cilium-envoy, vector, spegel, netops-agent, csi-nfs,
node-problem-detector and node-exporter DaemonSets.

### 10. Keep open-webui and qdrant together

`platform/ai/kubernetes/integrations/openwebui/values.yaml` sets
`QDRANT_URI: http://qdrant.data.svc.cluster.local:6333`. Either both move or the dependency
crosses ClusterMesh — and the otel overlay in this repo already documents global services as
invisible to endpoint discovery. Move them in the same step.

Note the live drift: `qdrant-0` and its PVC are in namespace `default`, while
`platform/data/kubernetes/apps/qdrant/kustomization.yaml` declares `namespace: data`. The
`QDRANT_URI` above points at `data`. Resolve which is authoritative **before** moving, not during.

### 11. n8n moves last, and the public gateway moves with it

n8n is the only workload whose move changes the front-door topology. It depends on two gateways:

- `homelab-internal-gateway` (192.168.2.200) — full app plus the internal-only
  `/mcp-server/http` prefix
- `homelab-external-gateway` (192.168.2.201) — OAuth callbacks only, two exact paths

`homelab-external-gateway` exists **only** on `mlops` (`publicGateway: true` there, `false` on
`application`), and `terraform/cloudflare_tunnel.tf:30` routes `n8n.teaglebuilt.tech` to
`https://${var.mlops_external_gateway_ip}`. The split is deliberate and load-bearing; it is not
accidental coupling to be refactored away.

An HTTPRoute cannot reach a backend in another cluster, so n8n on `application` with its external
gateway on `mlops` is not a configuration — it is broken. Two real options:

**(a) Move the public gateway to `application`.** Set `publicGateway: true` on `application` and
`false` on `mlops`, pin an IP from `application-pool` (192.168.2.241–254, 11 free), and repoint
the tunnel variable. This *preserves* the split-horizon property — still two gateways, two IPs,
same path split — while removing the cross-host LAN hop, since `cloudflared` already runs on
`application` (`frontDoor: true`). The cost is that the .200/.201 addressing changes, which is
documented in several places and in operator muscle memory.

**(b) Leave n8n on `mlops`.** It then lands on `work-00` or `ctrl-00`. Costs 512Mi of requests on
the GPU node and keeps `automation` as an mlops-only stack — no restructuring needed. The 6144 MiB
on `pve2` is still freed.

Recommendation: **(a)**, but it is genuinely a judgement call, and (b) is a legitimate stopping
point that still achieves the two-node goal. Decide this before Phase 4, not during it.

---

# Implementation

## Phase 0 — Make `main.tf` match what is applied (do this first, on its own)

Pure hygiene, no runtime effect, removes the risk that the next apply re-inflates `pve2` past its
RAM.

1. Run pre-flight 2 — find whatever supplied the `6144` values (Taskfile `-var`, `.env`, tfvars) so
   the edit does not simply move the drift.
2. Set `ram_dedicated` to 6144 / 16384 / 6144 in `kubernetes/terraform/mlops/main.tf`.
3. `tofu -chdir=kubernetes/terraform/mlops plan` must show **no changes**. If it shows a VM
   replacement, stop — that is open question 2 and it would destroy `work-01`'s PVCs.
4. While in the file: strip the inline comment at `tf_modules/talos_cluster/main.tf:28` per the GPU
   story's Decision 1; rationale belongs in the README, not the module.

## Phase 1 — Consolidation pre-flight (blocking, read-only)

1. Resolve the qdrant namespace drift (`default` live vs `data` declared).
2. Confirm `local-path` capacity on `application` nodes for the three incoming local-path PVCs
   (10Gi + 10Gi + 2Gi = 22Gi). `application-work-00` has `disk_size` to check in
   `kubernetes/terraform/application/main.tf`.
3. Take the backups before anything moves: `pg_dump`, a Qdrant snapshot, an open-webui volume
   copy, and run n8n's existing export CronJob once on demand.

## Phase 2 — Prerequisites on `application` (no workload movement)

1. Create `kubernetes/apps/storage/nfs/overlays/application/` with a `storageclass.yaml` mirroring
   `overlays/mlops/`. Decide the share: n8n's static PV names
   `/var/nfs/shared/automation_platform_data` explicitly, so the StorageClass `share` parameter
   only matters for future dynamic claims.
2. Verify the StorageClass lands via the bootstrap hook, not by hand.

Verification: `kubectl --context=admin@application get sc` shows `nfs-csi`.

## Phase 3 — `platform/data`: postgres + qdrant → `application`

The only stack with a working per-cluster overlay split. Do it first precisely because it is the
supported path and will surface cross-cluster problems cheaply.

1. Move `../../apps/postgres`, `../../apps/qdrant`, `../../apps/redis` from
   `overlays/mlops/kustomization.yaml` to `overlays/application/kustomization.yaml`. Decide
   whether `redis` goes too — it currently runs on `work-00`, not `work-01`, so it is not forced.
2. Drop the `kubernetes.io/hostname` selectors from `apps/postgres/cluster.yaml:15` and
   `apps/qdrant/kustomization.yaml:38`.
3. `overlays/mlops/pv.yaml` (static NFS PV `data-platform-storage`) is currently **bound to
   nothing** — no claim references it. Confirm, then delete rather than port it.
4. Deploy, restore postgres from dump and qdrant from snapshot, verify
   `qdrant.homelab.internal` resolves to an `application-pool` IP.
5. Once postgres is off `mlops`, flip `cnpg: false` in `kubernetes/clusters/mlops/environment.yaml`
   and remove the `cnpg` nodeSelector — the operator can leave the cluster entirely.

Verification: n8n (still on mlops) can reach postgres across ClusterMesh, or n8n is broken until
Phase 4 — establish which **before** starting, since n8n's DB connection is the one dependency
that spans this phase and Phase 5.

## Phase 4 — `platform/ai`: open-webui + openedai-speech → `application`

Requires restructuring, because `platform/ai/Taskfile.yml:56` hardcodes the mlops kubeconfig.

1. Choose: give `platform/ai/kubernetes/` per-cluster overlays, or move these two integrations out
   of `platform/ai` into a stack that already has them. The second is smaller and more honest —
   neither workload touches the GPU, so their being under `ai/` is a naming artifact.
2. Remove the pins at `integrations/openwebui/values.yaml:126` and
   `integrations/openedai-speech/deployment.yaml:22`.
3. Move with qdrant's new location in hand — update `QDRANT_URI` if the namespace resolution from
   Phase 1 changed it.
4. Restore the open-webui volume.

## Phase 5 — n8n (gated on the Decision 11 choice)

Only if option (a). If (b), skip to Phase 6 and leave `automation` where it is.

1. Add `overlays/{mlops,application}` to `platform/automation/kubernetes/`, and remove the
   `status: test "{{.CLUSTER}}" != "mlops"` gate from `platform/automation/Taskfile.yml:17`.
2. Recreate the static PV `automation-platform-storage` on `application` — same share, same
   `Retain` policy — and bind the PVC by `volumeName`. No data copy.
3. Flip `publicGateway` to `true` on `application` / `false` on `mlops`; set
   `externalGateway.loadBalancerIP` to a free `application-pool` address and clear it on `mlops`.
4. Repoint `var.mlops_external_gateway_ip` in `terraform/cloudflare_tunnel.tf` (rename it —
   "mlops" in the name becomes a lie).
5. Drop the pins at `n8n/deployment.yaml:28` and `n8n/cronjob-workflow-export.yaml:26`.
6. Verify, in this order: `n8n.homelab.internal` over LAN DNS; the internal-only
   `/mcp-server/http` prefix is *not* reachable publicly; the two OAuth callback paths work end
   to end through the tunnel.

Update the split-horizon note in memory once the IPs change — it currently records .200/.201.

## Phase 6 — Unpin what stays, then delete the node

1. Empty the `certManager` and `cnpg` nodeSelectors in
   `kubernetes/clusters/mlops/environment.yaml:16-19` (match `application`'s `{}`).
2. Remove the `work-01` pins from both externaldns `*-values.yaml.gotmpl` files and from
   `kubernetes/apps/gitops/argocd/values.yaml.gotmpl` (inert today — `gitops: false`).
3. Repoint `platform/observability/.../prometheus/overlays/mlops/values.yaml:12,15` at
   `mlops-work-00`, or remove the pin.
4. Drop `mlops-work-01` from `kubernetes/apps/security/kubelet-csr-approver/values.yaml:2`.
5. Confirm nothing is scheduled on `work-01`, then `kubectl drain` and `talosctl reset` it.
6. Delete the `"mlops-work-01"` block from `kubernetes/terraform/mlops/main.tf:54-63` and apply.
   Read the plan before applying — confirm it destroys exactly one VM and does not touch the other
   two.

## Phase 7 — Reclaim the headroom

Only after the above is stable: raise `ram_dedicated` on `mlops-ctrl-00` (6144 → 8192 puts the
host at 77.3%, still ~7.0 GiB clear) or on `mlops-work-00`, or leave the slack on `pve2` as the
margin the GPU story was asking for. Do not do this in the same change as the node deletion, and
settle open question 2 first — this phase is the one where a replacement-forcing memory change
would actually bite.

---

# What this does not fix

- `work-00` at 174% memory limits. Caused by the ~22 kagent agents plus vLLM in `ai`, not by
  anything moving here. Separate sizing work.
- Monitoring co-residency (Decision 6). See Decision 8, cost 3.
- `platform/data/kubernetes/apps/qdrant/kustomization.yaml` ships a plaintext
  `apiKey: your-super-secret-api-key` in `valuesInline` with the SOPS alternative commented out
  directly above it. Pre-existing, unrelated, worth fixing while qdrant is being touched anyway.

---

# Implementation status (as of 2026-10-02)

## Completed phases

✅ **Phase 0:** Corrected main.tf RAM from 8096/16384/8120 to 6144/16384/6144. Stripped ballooning comment from tf_modules/talos_cluster/main.tf.

✅ **Phase 1:** Pre-flight checks completed. Qdrant namespace drift identified (live in `default`, declared in `data`). Disk capacity confirmed on application-work-00 (40 GiB). Backup procedures documented.

✅ **Phase 2:** Created `kubernetes/apps/storage/nfs/overlays/application/` with StorageClass mirroring mlops. NFS share: `/var/nfs/shared/application_platform_data`. Bootstrap hook will auto-apply on next helmfile run.

✅ **Phase 3:** Moved platform/data apps from mlops to application overlay:
- Postgres cluster.yaml: removed hostname selector
- Qdrant kustomization.yaml: removed nodeSelector pin
- mlops/pv.yaml: deleted (unused static NFS PV)
- application/kustomization.yaml: now includes postgres, qdrant, redis
- `enable.cnpg: false` on mlops (operator uninstalled; stays on application)

✅ **Phase 4:** Restructured platform/ai for multi-cluster deployment:
- Removed hostname pin from open-webui/values.yaml and openedai-speech/deployment.yaml
- Added `overlays/{mlops,application}` — mlops keeps GPU/kagent/ai-gateway; application gets open-webui + openedai-speech
- Added Cilium global Service `ai-gateway-mesh` so open-webui on application reaches mlops backends
- QDRANT_URI → `http://qdrant.homelab.internal:6333` (survives default-vs-data ns drift)
- Taskfile deploys `kubernetes/overlays/{{.CLUSTER}}`; CRD install skipped off mlops
- Deployed to application; removed open-webui/openedai from mlops

✅ **Phase 5:** Restructured platform/automation and migrated n8n to application with Option (a) — public gateway moves to application:
- Created platform/automation/kubernetes/overlays/{mlops,application}
- Moved base contents to platform/automation/kubernetes/base/
- Removed mlops-only gate from Taskfile.yml
- Removed hostname pins from n8n deployment.yaml and cronjob-workflow-export.yaml
- Flipped publicGateway: false on mlops, true on application
- Set externalGateway.loadBalancerIP to 192.168.2.241 on application (application-pool)
- Cleared externalGateway.loadBalancerIP on mlops
- Renamed var.mlops_external_gateway_ip → var.external_gateway_ip in cloudflare_tunnel.tf
- Updated n8n comment in tunnel config from "mlops" to "application"

✅ **Phase 6:** Unpinned remaining workloads and prepared node deletion:
- Emptied certManager and cnpg nodeSelectors in mlops/environment.yaml (both now `{}`)
- Removed mlops-work-01 pins from both external-dns *-values.yaml.gotmpl files
- Removed mlops-work-01 pins from argocd/values.yaml.gotmpl (inert since gitops: false)
- Repointed prometheus agent from mlops-work-01 to mlops-work-00 (GPU node, appropriate for DCGM/vLLM)
- Removed mlops-work-01 from kubelet-csr-approver/values.yaml providerRegex
- Deleted "mlops-work-01" block from kubernetes/terraform/mlops/main.tf (lines 54-62)

## Pending

⏳ **Phase 7:** Reclaim headroom (deferred, optional, post-stability). Raise mlops-ctrl-00 ram_dedicated from 6144 → 8192 (77.3% util, ~7.0 GiB clear) or similar.

---

# Open questions

1. *Resolved 2026-10-02.* `pve2` is 32 GiB (31.05 usable). Ballooning is off (`floating: 0`) and
   `ram_dedicated` right-sizing was applied at 6144 / 16384 / 6144 = 90.2% of usable, but
   `main.tf` still reads 8096 / 16384 / 8120. Code-vs-state drift, not ballooning. **FIXED.**

2. Whether `ram_dedicated` is in-place or replacement-forcing in `bpg/proxmox`. **Blocking for
   Phase 7**. A replace wipes `work-01`'s local-path PVCs. Verify before Phase 7.

3. *Resolved 2026-10-02.* What supplied the applied `6144` values. Not found in .env/Taskfile/tfvars; likely manual override. **NO ACTION NEEDED** — Phase 0 edit is safe.

4. Whether the 3.33 GiB of host swap holds guest pages or PVE/ARC. Low priority, diagnostic only.

5. ZFS ARC size on `pve2` — still unread. Low priority, diagnostic only.

6. *Resolved 2026-10-02.* Decision 11: option (a) or (b). **CHOSEN: (a)** — Move public gateway to application with new IP 192.168.2.241.

7. *Resolved 2026-10-02.* qdrant's authoritative namespace — `default` (live) or `data` (declared). **WORKED AROUND:** open-webui now uses `qdrant.homelab.internal` (LB DNS) so either ns works. Declared `data` remains the target; live still in `default`.

8. Whether `redis` should follow postgres to `application`. Left on mlops (on work-00 today). Can move later if desired; not forced by deletion.

9. *Resolved 2026-10-02.* `local-path` disk headroom on `application` nodes for 22Gi of incoming PVCs. **CONFIRMED:** application-work-00 has 40 GiB disk; should accommodate.

10. Whether n8n must keep reaching postgres between Phase 3 and Phase 5. Not yet tested; verify on first deployment.

11. *Resolved 2026-10-02.* Whether `platform/ai`'s two non-GPU integrations should get overlays or relocate. **CHOSEN:** Multi-cluster support via restructured Taskfile (simpler than relocation).

12. Which datastore backs the VM disks on `pve2`. Low priority, diagnostic only.

---

# Next steps to land

1. **Wait for open-webui image pull on application** (~1.5 GiB). Confirm:
   ```bash
   kubectl --context=admin@application -n ai get pods
   # open-webui-0 Running; openedai-speech already Running
   ```

2. **Verify connectivity:**
   - `openwebui.homelab.internal` over LAN
   - LLM calls via `ai-gateway-mesh` (ClusterMesh → mlops)
   - Qdrant via `qdrant.homelab.internal`

3. **Optional cleanup:** uninstall orphan `agentgateway-crds` / `kagent-crds` Helm releases from application (installed before the CRD-skip fix; CRDs are cluster-scoped leftovers).

4. **Phase 7 (optional, deferred):** Once stable, optionally raise mlops-ctrl-00 ram_dedicated to 8192 and verify plan is in-place (not replacement-forcing).
