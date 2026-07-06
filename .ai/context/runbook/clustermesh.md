# Declarative Cilium ClusterMesh Runbook (PR 2)

Two-cluster mesh: **mlops** (pve2, id 1, pods `10.244.0.0/16`) ↔ **application**
(pve, id 2, pods `10.245.0.0/16`). Native routing (no tunnel), apiserver exposed
via L2/LB-IPAM, service discovery via Cilium global-service annotations. No
`cilium clustermesh` CLI — peering is declarative Helm.

Prereq: PR 1 (Cilium 1.18.11) landed and validated on mlops.

## Two-pass model (why the mesh is a separate helm upgrade)

Mesh activation has cross-cluster prerequisites (shared CA in both clusters, both
apiservers reachable), so it **cannot** live in a single cluster's base bootstrap —
that would wedge the sync on a peer/CA that doesn't exist yet. The deploy is split:

- **Phase 1 — `bootstrap-cluster` (per cluster, independent):**
  `clusters/<name>/helmfile.yaml` deploys plain Cilium + the **identity** overlay
  (`identity-values.yaml.gotmpl`: `cluster.name/id` + `ipv4NativeRoutingCIDR`) + the
  cluster's LB-IPAM pool. No ClusterMesh, no cross-cluster deps — boots standalone.
- **Phase 2 — `connect-clusters` (barrier, after BOTH are healthy):** apply the
  shared CA to both, then a Cilium **helm upgrade** via `clusters/<name>/mesh.yaml`
  (`--selector name=cilium`) that layers the **clustermesh** overlay
  (`clustermesh-values.yaml.gotmpl`) on top. Then routes + status.

`task deploy-homelab` runs both phases in order. `mesh-upgrade` has a precondition
that fails fast if `clusters/_shared/cilium-ca.sops.yaml` is missing.

## What is already in the repo (staged, inert until activated)

| Area | File(s) | State |
|---|---|---|
| Talos CIDR param | `tf_modules/talos_cluster/{variables,config}.tf`, `templates/controlplane.yaml.tftpl` | ✅ merged, `terraform validate` ✅, mlops behaviour unchanged |
| mlops explicit CIDR | `kubernetes/terraform/mlops-cluster.tf` | ✅ `10.244.0.0/16` |
| application cluster | `kubernetes/terraform/application/` (separate root) | ✅ `terraform validate` ✅, needs real IP vars to apply |
| Cilium overlays | `kubernetes/clusters/{mlops,application}/clustermesh-values.yaml` | ✅ render clean vs chart 1.18.11 |
| LB pools | `kubernetes/clusters/{mlops,application}/lb-ippool.yaml` | ✅ staged (not yet in kustomize) |
| Per-cluster deploy | `kubernetes/clusters/{mlops,application}/helmfile.yaml` | ✅ overlay injection validated |
| Overlay injection | `kubernetes/helmfile.d/01-bootstrap.gotmpl.yaml` (`clusterOverlay` conditional) | ✅ backward-compatible |
| Shared CA procedure | `kubernetes/clusters/_shared/README.md` | ✅ documented |
| Identity docs | `kubernetes/clusters/{mlops,application}/cluster.yaml` | ✅ |

## Activation sequence (gated — do in order)

### Step 1 — Provision application (pve)
Fill real values and apply the separate root. Point Proxmox env at **pve**
(`PROXMOX_VE_ENDPOINT=https://<pve-ip>:8006`, pve API token / SSH key):
```bash
cd kubernetes/terraform/application
terraform init
terraform apply \
  -var admin_k8s_api_server_ip=<ADMIN_API_IP> \
  -var admin_master_node_ip=<ADMIN_CTRL_IP> \
  -var admin_worker_node_ip=<ADMIN_WORKER_IP> \
  -var network_gateway=$PROXMOX_NETWORK_GATEWAY \
  -var graylog_ip=$GRAYLOG_IP \
  -var proxmox_ssh_private_key=$PROXMOX_NODE_ONE_PRIVATE_KEY
```
Talos applies `podSubnets: 10.245.0.0/16` — disjoint from mlops. Kubeconfig lands in
`kubernetes/generated/application/kubeconfig`.
> A dedicated Taskfile task (mirroring `provision-cluster` but with pve env) is the
> clean home for this — not yet added.

### Step 2 — Shared CA into BOTH clusters
Follow `kubernetes/clusters/_shared/README.md`: generate one CA, create the
SOPS-encrypted `cilium-ca` Secret, and apply it (decrypted) to `kube-system` in
**both** clusters BEFORE the Cilium release. Wire this as a `00-prepare` step /
cilium `presync` hook once the encrypted file exists (avoid committing a hook that
references a missing file).

### Step 3 — LB pool cutover
Both clusters share the `192.168.2.0/24` L2, so the single shared
`proxmox-pool` (`.12–.255`) is replaced by the disjoint per-cluster pools:
- `ip-pool.yaml` / `proxmox-pool` are **removed** from the repo. Each cluster's
  `clusters/<name>/lb-ippool.yaml` (mlops `.200–.240`, admin `.241–.254`) is now
  applied automatically by the **cilium release's postsync hook** (envsubst-rendered),
  so it lands on every `helmfile sync`. Pools start at `.200` so they never overlap
  the static node IPs (mlops `.19/.20/.195`, admin `.6/.7`) or hosts (`.100/.101`).
- **One-time manual cleanup** on the running mlops cluster (nothing recreates the
  legacy CR anymore, so this is no longer in any task):
  ```bash
  KUBECONFIG=kubernetes/generated/kubeconfig \
    kubectl delete ciliumloadbalancerippool proxmox-pool --ignore-not-found
  ```
> Do the cutover during the mesh activation window, confirming existing LoadBalancer
> IPs stay assigned after `mlops-pool` takes over.

### Step 4 — Deploy the mesh (declarative, no CLI)
Per cluster, with its kube-context active:
```bash
helmfile -f kubernetes/clusters/mlops/helmfile.yaml sync           # mlops
helmfile -f kubernetes/clusters/application/helmfile.yaml sync  # application
```
The overlay enables `clustermesh.useAPIServer`, the LoadBalancer apiserver (pinned
`.240` / `.248`), `authMode: cluster` (shared-CA trust), and declares the peer under
`clustermesh.config.clusters`. The operator auto-generates the `cilium-clustermesh`
secret — this replaces `cilium clustermesh connect`.

### Step 5 — UniFi static routes (native routing)
Native routing needs the underlay to route each remote **per-node** pod `/24` to that
node. With `ipam.mode: kubernetes` each node owns a `/24` from its cluster's `/16`, so
it is **one route per node**, not per cluster. Get the real values after Step 1/4:
```bash
# per cluster:
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.podCIDR}{" -> "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
```
Then hand the network-agent a route table: `dest = <remote per-node podCIDR>`,
`next-hop = <that remote node's InternalIP>`, both directions. Also set
`ipv4NativeRoutingCIDR: 10.244.0.0/15` (already in the overlays) so cross-cluster pod
traffic is treated as natively routed.

### Step 6 — Verify (declarative first)
```bash
kubectl -n kube-system get svc clustermesh-apiserver         # EXTERNAL-IP == .240/.248
kubectl -n kube-system get secret cilium-clustermesh         # auto-generated peer config
kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose | grep -A6 ClusterMesh
# one acceptable read-only CLI use:
cilium clustermesh status --context <ctx> --wait
```

### Step 7 — Global services (no MCS-API)
On a Service present in both clusters (same name+namespace), annotate:
```yaml
metadata:
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/affinity: "local"   # optional: prefer local, fail over remote
```

## Prerequisite invariants (verify before Step 4)
- **Pod CIDRs disjoint**: mlops `10.244.0.0/16`, application `10.245.0.0/16`. ✅ enforced in TF.
- **Cluster IDs unique**: mlops `1`, application `2`. ✅ in overlays.
- **Shared CA** present in both clusters (Step 2).
- **LB pools disjoint** on the shared L2 (Step 3).
