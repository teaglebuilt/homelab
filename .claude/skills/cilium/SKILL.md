---
name: cilium
description: >
  Cilium eBPF networking for this homelab's Talos clusters. Use for ClusterMesh
  peering between the mlops and application clusters, shared-CA trust, native
  routing and pod CIDR allocation, LB-IPAM pools and L2 announcements, Hubble,
  CiliumNetworkPolicy, and eBPF datapath debugging. Also use when changing
  kubernetes/apps/networking/cilium/**, kubernetes/clusters/*/identity-values.yaml.gotmpl,
  kubernetes/clusters/*/clustermesh-values.yaml.gotmpl, kubernetes/clusters/*/mesh.yaml,
  or kubernetes/.taskfiles/cilium/**. Do not use for UniFi VLAN or UDM firewall
  changes, or for Gateway API routing, unless the issue crosses into the CNI
  datapath.
metadata:
  product: cilium
  repository: teaglebuilt/homelab
---

# Cilium for the Homelab

Two-cluster native-routing mesh. Peering is **declarative Helm**, not the
`cilium clustermesh connect` CLI.

| | mlops | application |
| --- | --- | --- |
| Host | pve2 | pve |
| Cluster ID | 1 | 2 |
| Pod CIDR | `10.244.0.0/16` | `10.245.0.0/16` |
| LB pool | `.200–.240` | `.241–.254` |

`ipv4NativeRoutingCIDR` is `10.244.0.0/15` in both overlays so cross-cluster pod
traffic is treated as natively routed.

## Primary Reference

Read [.ai/context/runbook/clustermesh.md](../../../.ai/context/runbook/clustermesh.md)
before any mesh work. It owns the two-pass deploy model, the repo inventory, the
shared-CA procedure, the LB pool cutover, the UniFi static-route derivation, and
the prerequisite invariants. Do not reconstruct that procedure from upstream docs.

Supporting repo context:

- `kubernetes/clusters/_shared/README.md` — shared CA generation and SOPS handling.
- `.ai/context/invariants/KUBERNETES.md` — cluster-wide invariants.
- `kubernetes/.taskfiles/cilium/Taskfile.yml` — `ensure-shared-ca`, `apply-shared-ca`,
  `clustermesh-status`.

## Configuration Ownership

| Concern | File |
| --- | --- |
| Base values | `kubernetes/apps/networking/cilium/values.yaml` |
| Identity overlay (cluster name/id, native routing CIDR) | `kubernetes/clusters/<cluster>/identity-values.yaml.gotmpl` |
| Mesh overlay (apiserver, authMode, peers) | `kubernetes/clusters/<cluster>/clustermesh-values.yaml.gotmpl` |
| Mesh upgrade release | `kubernetes/clusters/<cluster>/mesh.yaml` |
| LB-IPAM pool | `kubernetes/apps/networking/cilium/overlays/<cluster>/ip-pool.yaml` |
| Overlay injection | `kubernetes/helmfile.d/01-bootstrap.gotmpl.yaml` (`clusterOverlay`) |
| Shared CA | `kubernetes/clusters/_shared/cilium-ca.sops.yaml` |

The LB pool overlay is applied by the cilium release's postsync hook
(`kustomize build overlays/<cluster> | envsubst`), so it lands on every
`helmfile sync`. Do not apply it by hand.

## Safety Rules

1. Phase 1 (`bootstrap-cluster`) must never depend on a peer or shared CA. Mesh
   activation is Phase 2 (`connect-clusters`) and requires both clusters healthy.
2. Verify the prerequisite invariants — disjoint pod CIDRs, unique cluster IDs,
   shared CA present in both clusters, disjoint LB pools on the shared L2 — before
   any mesh upgrade.
3. Never commit a presync/postsync hook that references a file not yet in the repo.
4. Pod CIDRs are set in Terraform. Changing one is a cluster rebuild, not a Helm edit.
5. Match documentation to the installed Cilium minor version. Confirm it first:
   `kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}'`
6. Underlay routes for native routing are **per node**, not per cluster. Derive them
   from live `podCIDR` → `InternalIP` and hand the table to `network-agent`.

## Live Inspection

Read-only first. Prefer the MCP tools when the result belongs inline:

- `kagent-tools_cilium_get_endpoint_health`, identities, IP cache, BPF maps,
  encryption state, PCAP recorders.
- `kagent-tools_k8s_get_*` / events / pod logs for the cilium DaemonSet and operator.

Direct equivalents when output is large or piped:

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose
kubectl -n kube-system get svc clustermesh-apiserver
kubectl -n kube-system get secret cilium-clustermesh
cilium clustermesh status --context <ctx> --wait
```

`cilium clustermesh status` is the one acceptable read-only CLI use. Never use
`cilium clustermesh connect` / `disconnect` — they drift from the declarative overlays.

## Source Precedence

1. Live cluster state for what is running or failing.
2. `.ai/context/runbook/clustermesh.md` for mesh procedure.
3. Repository overlays for intended configuration.
4. Official Cilium docs for the installed minor version.
5. General knowledge only when the above do not answer the question.
