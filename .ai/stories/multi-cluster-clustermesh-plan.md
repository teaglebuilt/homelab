# Multi-Cluster ClusterMesh Architecture & Rebuild Plan

Status: **Planning / not yet executed.** Phase 1 is concrete and file-level; Phase 2 is
architectural. Decisions below are locked unless explicitly revisited.

## Target model — three clusters

| Cluster | Role | Phase | Cilium identity |
|---|---|---|---|
| `mlops` | GPU/AI compute: `ai` namespace, nvidia/dcgm/npd, kwasm/spin | 1 | `name: mlops`, `clusterId: 1` |
| `application` | General workloads: **front door** (cloudflare-tunnel + external-dns), **central observability**, databases, HTTP apps. This is the live meshed cluster. | 1 | `name: administration`, `clusterId: 2` (live identity retained — see note) |
| `administration` | Management/edge plane: ArgoCD hub, Hubble UI, backup/DR. **Does not exist yet.** | 2 | `name: administration-mgmt` (TBD), `clusterId: 3` |

> **Live-identity note.** The `application` cluster was provisioned under the name
> `administration` (clusterId 2) and is already meshed. The directory/logical layer is being
> renamed to `application`, but inside `clusters/application/cluster.yaml` and
> `identity-values.yaml.gotmpl` the Cilium `name: administration` + `id: 2` **must stay exactly
> as-is** — the running mesh keys off them. Only the helmfile/logical layer is `application`.
> The future dedicated `administration` management cluster (Phase 2) is a *different* cluster
> (clusterId 3) and will need a distinct Cilium name to avoid collision.

## Locked decisions

| Decision | Choice |
|---|---|
| Cluster rename | Logical only — repo=`application`, live Cilium identity=`administration`/`2` unchanged (user handles the rename) |
| `application` role | Full second workload cluster (HTTP apps, DBs) + owns the front door |
| Front door (cf-tunnel + external-dns) | **Moves off mlops → application** |
| Observability | Central Prometheus/Grafana on `application`; mlops runs a prometheus **agent** that `remote_write`s over the front-door LB. DCGM/AI exporters stay on mlops |
| cert-manager | Independent per cluster (own CA issuer each) |
| Secrets | SOPS + AWS KMS only. No ESO/Vault. reflector stays intra-cluster |
| Global Cilium services | **None** in Phase 1 |
| New operators | Reloader ✅, Hubble ✅ (already on). argocd/openebs/external-secrets orphans stay OFF |
| Phase 2 | ArgoCD hub-spoke from `administration`; seam at stage `05-gitops` |

## Secrets across clusters — answer: **not shared at runtime**

- `clusters/_shared/cilium-ca.sops.yaml` is the **Cilium mesh mTLS trust anchor only** (the
  `cilium-ca` Secret in `kube-system`), shared so both clusters sign mesh/identity certs from
  the same root. It is **not** for app secrets. **Never regenerate it** — that re-keys the whole mesh.
- SOPS + AWS KMS: the **same KMS key decrypts on both clusters**, so both *can* decrypt the same
  `.enc.yaml` files, but decryption is client-side at deploy time against the targeted context —
  no runtime replication.
- cert-manager: independent per cluster; internal CAs are **not** shared.
- reflector: intra-cluster secret fan-out only.

Simplest correct approach: **SOPS stays the source of truth**; reflector for intra-cluster fan-out.
Adopt ESO only if runtime secret rotation into multiple clusters becomes a real need.

---

# Phase 1 — `mlops` + `application` (helmfile-only, no ArgoCD)

## A. File operations

**New files**
1. `kubernetes/clusters/mlops/environment.yaml`
2. `kubernetes/clusters/application/environment.yaml`
3. `kubernetes/helmfile.d/05-gitops.gotmpl.yaml` (disabled placeholder)

**Edited files**
4. `kubernetes/defaults.yaml` — add `environments:` block.
5. `kubernetes/clusters/mlops/helmfile.yaml` — inject `environment.yaml` into every stage.
6. `kubernetes/clusters/application/helmfile.yaml` — inject `environment.yaml`; **add stages
   02/03/04/05** (currently stops at 01); **fix the broken `identityOverlay` path** (points at
   deleted `../clusters/administration/...`).
7. `kubernetes/helmfile.d/00-prepare.gotmpl.yaml` — add shared-CA apply hook (before Cilium).
8. `kubernetes/helmfile.d/01-bootstrap.gotmpl.yaml` — add Reloader release; make coredns
   `clusterIP` key off `.Values.cluster.kubeDnsIP` (not the `eq $cluster "administration"` literal).
9. `kubernetes/helmfile.d/02-core.gotmpl.yaml` — gate every release with `installed:`; move front
   door to application; template nodeSelectors from env.
10. `kubernetes/helmfile.d/03-hardware.gotmpl.yaml` — gate on `enable.gpu`/`enable.wasm`; **delete
    the duplicate `metrics-server` release** (already in 01).
11. `kubernetes/helmfile.d/04-monitoring.gotmpl.yaml` — add central Prometheus stack (application)
    + prometheus agent (mlops, remote_write).

No app-config dirs deleted. Orphans (`apps/gitops/argocd`, `apps/security/external-secrets`,
`apps/storage/openebs`) stay on disk, unwired.

## B. Per-stage release + `installed:` toggle matrix

Legend: ✅ installed · ❌ not · → moved.

| Stage / release | mlops | application | Toggle | Notes |
|---|:--:|:--:|---|---|
| **00-prepare** (hooks) | ✅ | ✅ | — | Add `sops -d clusters/_shared/cilium-ca.sops.yaml \| kubectl apply -f -` **before Cilium**. Keep storageclass / aws+ghcr decrypt / Gateway-API + Prometheus CRDs. |
| **01** reflector | ✅ | ✅ | always | |
| **01** reloader (NEW) | ✅ | ✅ | always | emberstack/reloader |
| **01** cilium (+identity overlay) | ✅ | ✅ | always | **do not touch name/id** |
| **01** coredns | ✅ | ✅ | always | `clusterIP` from `.Values.cluster.kubeDnsIP` (`10.96.0.10` mlops / `10.97.0.10` application) |
| **01** spegel / csi-driver-nfs / metrics-server | ✅ | ✅ | always | nfs overlay path `overlays/<logical>` |
| **02** internal-dns | ✅ | ✅ | always | each cluster resolves its own records |
| **02** cert-manager (+CA issuer) | ✅ | ✅ | `enable.certManager` | independent per cluster; nodeSelector from `.Values.nodeSelector.certManager` |
| **02** homelab-gateway (kgateway) | ✅ | ✅ | `enable.gateway` | |
| **02** cnpg | ✅ | ✅ | `enable.cnpg` | nodeSelector from `.Values.nodeSelector.cnpg` |
| **02** cloudflare-tunnel | ❌ → | ✅ | `enable.frontDoor` | **MOVED off mlops** |
| **02** external-dns (public) | ❌ → | ✅ | `enable.frontDoor` | **MOVED** |
| **03** nvidia-device-plugin / dcgm / node-problem-detector | ✅ | ❌ | `enable.gpu` | |
| **03** kwasm-operator / spin-operator | ✅ | ❌ | `enable.wasm` | |
| **03** metrics-server (duplicate) | ❌ | ❌ | — | **DELETE** — already in 01 |
| **04** vector | ✅ | ✅ | always | logs |
| **04** kube-prometheus-stack (NEW) | ❌ | ✅ | `enable.monitoringCentral` | CRDs already in 00 → `crds.enabled:false` |
| **04** prometheus agent-mode (NEW) | ✅ | ❌ | `enable.monitoringAgent` | scrapes local ServiceMonitors (DCGM + AI); `remote_write` → application |
| **05-gitops** argocd (NEW) | ❌ | ❌ | `enable.gitops` (false) | disabled Phase-2 seam |

**Cross-cluster observability path (no global service):** the mlops agent `remote_write`s to the
central Prometheus via the **internal-dns record / LAN LoadBalancer IP** of application (e.g.
`https://prometheus.<internal-domain>`), routable on `192.168.2.0/24`. No `service.cilium.io/global`
annotation needed — decision "no global services" holds.

## C. `environments:` block + `environment.yaml` schema

`kubernetes/defaults.yaml` (append):

```yaml
environments:
  mlops:
    values: [clusters/mlops/environment.yaml]
  application:
    values: [clusters/application/environment.yaml]
```

Each `clusters/<name>/helmfile.yaml` also injects the same file as `values:` into every staged
sub-helmfile so `.Values.enable.*` / `.Values.nodeSelector.*` / `.Values.cluster.*` resolve inside
stage templates.

| Key | mlops | application |
|---|---|---|
| `cluster.kubeDnsIP` | `10.96.0.10` | `10.97.0.10` |
| `enable.gpu` | `true` | `false` |
| `enable.wasm` | `true` | `false` |
| `enable.gateway` | `true` | `true` |
| `enable.certManager` | `true` | `true` |
| `enable.cnpg` | `true` | `true` |
| `enable.frontDoor` | `false` | `true` |
| `enable.monitoringCentral` | `false` | `true` |
| `enable.monitoringAgent` | `true` | `false` |
| `enable.gitops` | `false` | `false` |
| `nodeSelector.certManager` | `mlops-work-01` | `administration-work-00` |
| `nodeSelector.cnpg` | `mlops-work-01` | `administration-work-00` |

(`administration-work-00` is the live node hostname of the `application` cluster — unchanged by the
logical rename.)

## D. Bootstrap / apply order (fresh cluster into the mesh)

1. **Provision** — `mlops` (pve2, `terraform/mlops`), `application` (pve1, `terraform/administration`
   root — path unchanged).
2. **`mlops`: 00 → 01.** 00 applies shared `cilium-ca` before Cilium; 01 = cilium(identity, no mesh)
   → coredns → spegel → nfs → metrics-server → reflector → reloader. **Standalone-healthy.**
3. **`application`: 00 → 01.** Same. Standalone-healthy.
4. **Mesh join (`task connect-clusters`)** — gates only on both clusters through 01 + shared CA + LB
   pools: `mesh-upgrade` each → `clustermesh-routes` (UniFi static routes) → `clustermesh-status`.
   *(Orthogonal to 02–04 — can run concurrently.)*
5. **02-core.** mlops: internal-dns, cert-manager, gateway, cnpg (front door OFF). application: same
   **plus cloudflare-tunnel + external-dns** (front door ON).
6. **03-hardware** — mlops only (gpu + wasm).
7. **04-monitoring** — application brings up kube-prometheus-stack + Grafana **before** the mlops
   agent can push; mlops agent `remote_write`s to it. vector both.
8. **05-gitops** — skipped (`enable.gitops:false`).

## E. Risk / do-not-touch (mesh survives)

Keep exactly — changing any re-keys or breaks the live mesh:

- `clusters/application/cluster.yaml` → `name: administration`, `clusterId: 2`.
- `clusters/application/identity-values.yaml.gotmpl` → `cluster.name: administration`, `cluster.id: 2`.
- `clusters/application/clustermesh-values.yaml.gotmpl` → apiserver SANs + LB IP
  (`ADMIN_CLUSTERMESH_APISERVER_IP`).
- `clusters/mlops/clustermesh-values.yaml.gotmpl` → peering entry `name: administration` +
  `ADMIN_CLUSTERMESH_APISERVER_IP`.
- Plumbing that stays `administration`: kube-context `admin@administration`,
  `generated/administration/kubeconfig`, `terraform/administration` root, `ADMIN_*` env vars,
  `PROXMOX_NODE_ONE_*` (pve1), node hostnames `administration-ctrl-00/work-00`.
- `clusters/_shared/cilium-ca.sops.yaml` — **never regenerate**.

## F. Ordered execution checklist (each group independently verifiable)

- **G1 — environments wiring.** Write both `environment.yaml`; add `environments:` to `defaults.yaml`;
  inject env into every stage in both `clusters/*/helmfile.yaml`; add stages 02–05 to
  `application/helmfile.yaml`; fix its `identityOverlay` path.
  **Verify:** `helmfile -e mlops template` and `helmfile -e application template` render with no
  missing-value errors.
- **G2 — toggle gating.** Add `installed:` to every 02/03/04 release per the matrix.
  **Verify:** template diff shows GPU/WASM absent on application; cert-manager/gateway/cnpg present on both.
- **G3 — front-door move.** Gate cloudflare-tunnel + external-dns on `enable.frontDoor`.
  **Verify:** those two render on application only.
- **G4 — nodeSelector + coredns templating.** Replace hardcoded `mlops-work-01` (cert-manager, cnpg)
  and the coredns `eq $cluster` literal with env values.
  **Verify:** application renders `administration-work-00` and clusterIP `10.97.0.10`.
- **G5 — 00-prepare shared CA + 01 reloader + 03 metrics-server dedupe.**
  **Verify:** 00 renders the `cilium-ca` apply hook; reloader present both; one metrics-server across 01+03.
- **G6 — observability.** Add kube-prometheus-stack (application) + prometheus agent (mlops,
  remote_write to front-door LB).
  **Verify:** central stack on application only; agent on mlops only; remote_write URL points at
  application internal-dns/LB; no `service.cilium.io/global` anywhere.
- **G7 — 05-gitops placeholder.** Add disabled argocd release.
  **Verify:** renders nothing while `enable.gitops:false`.

---

# Phase 2 — `administration` cluster + ArgoCD (architecture)

Introduce `administration` (clusterId 3) as the management/edge plane and mesh it as a third peer:
disjoint pod CIDR `10.246.0.0/16`, widen the native-routing supernet to `10.244.0.0/14`, own LB pool,
add peering entries on the other two + its own, share the same `cilium-ca`. **Give it a distinct
Cilium `name`** (e.g. `administration-mgmt`) — the existing meshed cluster already uses the Cilium
name `administration`.

## What lives on `administration` (honest homelab sizing)

- **ArgoCD hub — yes.** One ArgoCD managing all three clusters via ApplicationSet **cluster
  generator**. The reason the cluster exists.
- **Hubble UI / mesh observability surface — yes, cheap.** Central cross-cluster flow view.
- **Backup/DR (Velero) — reasonable, modest.** Manifest + PV-snapshot backups to S3/R2, single instance.
- **Identity/SSO — only if** you already have >1 human-facing UI to protect; else over-engineering.
- **ESO/Vault — skip** unless a concrete runtime-rotation need appears. SOPS stays source of truth.
- **Full service mesh beyond Cilium — skip.**

## Migrate front door / observability to administration?

- **Observability → migrate** (it's naturally a management concern; lets it outlive any single
  workload cluster). Cost: one more remote-write hop.
- **Front door → leave on `application`** unless administration genuinely becomes the only edge —
  moving ingress twice is churn for little homelab gain.

## Hub-spoke handoff (the stage-05 seam)

Helmfile keeps owning the **bootstrap floor on every cluster** — CNI/Cilium + mesh join, cert-manager,
secrets (SOPS), gateway, storage (stages 00–02). ArgoCD, deployed by the now-enabled **`05-gitops`**
stage on administration, takes over **app delivery (stage 03+ equivalents)** to all three clusters.
The `enable.gitops` toggle + cluster-labeled `environment.yaml` map directly onto ArgoCD cluster
labels, so Phase-1 work is not throwaway. HA/failover (Cilium global-service `affinity`) is revisited
only after ArgoCD is the backbone.

## Bootstrap order to add `administration` into the running mesh

1. Provision (clusterId 3, disjoint CIDRs, own LB pool); widen native-routing supernet on all three.
2. `administration`: 00 (apply shared `cilium-ca`) → 01 (standalone-healthy).
3. Add administration's peering to `mlops` + `application` overlays and vice-versa; `mesh-upgrade`
   all three; `clustermesh-routes` (UniFi) + `clustermesh-status` → 3-way mesh.
4. Enable `05-gitops` on administration; register all three as ArgoCD clusters; convert the
   ApplicationSet to the cluster generator.
5. Cut over app delivery cluster-by-cluster (administration → application → mlops), shrinking each
   helmfile to the bootstrap floor as ArgoCD assumes ownership. Optionally re-home observability to
   administration.
