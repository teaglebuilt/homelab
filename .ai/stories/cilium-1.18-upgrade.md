# Cilium Upgrade Runbook: 1.17.3 → 1.18.11

**Scope:** PR 1 of the ClusterMesh initiative. Upgrades the Cilium CNI on the running
`mlops` cluster to establish a stable, mesh-ready base **before** any multi-cluster work.
No ClusterMesh, no values changes — just the version.

## Why 1.18.11 (not 1.19.x)

Two Cilium 1.19 regressions hit this repo's exact Talos + L2-announcement config:

- [cilium/cilium#46010](https://github.com/cilium/cilium/issues/46010) — 1.19.3/1.19.4 with
  `kubeProxyReplacement: true` on Talos kills host networking during BPF/veth init. This repo
  runs exactly that (`kubernetes/apps/networking/cilium/values.yaml`, `kubeProxyReplacement: true`).
- [cilium/cilium#44222](https://github.com/cilium/cilium/issues/44222) — 1.19 breaks L2
  announcements that use a sharing key. **Still open, no fix** as of Feb 2026. This repo uses L2
  announcements (`kubernetes/apps/networking/cilium/announcement.yaml`).

1.18 provides everything the ClusterMesh design needs — declarative clustermesh (since 1.14),
KVStoreMesh default (since 1.16), global-service annotations — with neither regression.
Revisit 1.19 only after #44222 is fixed and the #46010 fix is confirmed in the target patch.

## What changed in this PR

- `kubernetes/helmfile.d/01-bootstrap.gotmpl.yaml` — `cilium` release `version: 1.17.3` → `1.18.11`.
- `kubernetes/helmfile.d/01-bootstrap.gotmpl.lock` — regenerated (`make helmfile_lock`).
- **No changes to `values.yaml`.** Verified by rendering the repo's actual values against the
  1.18.11 chart (`helm template ... -f apps/networking/cilium/values.yaml` → exit 0, no schema
  errors). Every key in this repo's values (`kubeProxyReplacement`, `bandwidthManager`+`bbr`,
  `l2announcements`, `endpointRoutes`, `loadBalancer.algorithm: maglev`, `bpf.hostLegacyRouting`,
  `gatewayAPI`, `envoy`, `hubble`, Talos `cgroup`/`securityContext`) is stable across 1.17→1.18.
- The vendored `charts/tetragon-1.6.0` subchart is independent of the Cilium chart version and is
  compatible with Cilium 1.18 — re-render after upgrade to confirm, but no edit required.

## Upgrade path

Cilium supports single-minor upgrades (1.17 → 1.18 is one hop and is valid). The committed
desired state is **1.18.11**. For maximum caution you MAY land on the latest 1.17 patch first;
it is optional, not a hard gate.

- **Direct (supported):** 1.17.3 → 1.18.11.
- **Extra-cautious (optional):** 1.17.3 → 1.17.17 → 1.18.11. To do the interim hop, temporarily
  set `version: 1.17.17`, `make helmfile_lock`, sync, validate, then restore `1.18.11`.

> Never skip a minor (e.g. 1.17 → 1.19 directly) — that is unsupported.

## Apply

Cilium lives in Helmfile stage `01-bootstrap`. Apply against the target cluster context:

```bash
# from repo root
cd kubernetes
make helmfile_lock                      # already done in this PR; re-run if you did an interim hop
task kubernetes:sync-cluster            # runs helmfile sync for the active kube-context
```

## Validation checkpoints (run after each hop)

1. **DaemonSet rollout, node by node** (the #46010 Talos host-networking failure surfaces here as
   a node going NotReady):
   ```bash
   kubectl -n kube-system rollout status ds/cilium --timeout=5m
   ```
2. **Nodes + pods healthy:**
   ```bash
   kubectl get nodes                     # all Ready
   kubectl get pods -A | grep -v Running # empty (ignore Completed)
   ```
3. **Cilium agent status:**
   ```bash
   kubectl -n kube-system exec ds/cilium -- cilium-dbg status --brief   # OK
   ```
4. **L2 / LoadBalancer sanity** (guards against the #44222 L2-announcement regression — the reason
   we hold at 1.18): pick an existing `LoadBalancer` Service, confirm it still holds its IP and is
   reachable:
   ```bash
   kubectl get svc -A --field-selector spec.type=LoadBalancer
   ```
5. **Data-plane spot check:** Gateway API routes and the Hubble UI still serve.

## Rollback (per cluster)

1. Revert the `version:` line in `01-bootstrap.gotmpl.yaml` to the prior value.
2. `make helmfile_lock`
3. `task kubernetes:sync-cluster` — Cilium is a DaemonSet; rollback is a re-sync of the prior
   chart. `helmDefaults.force: true` (`kubernetes/defaults.yaml`) makes the re-apply clean.
4. **Talos safety net:** if a node loses host networking mid-upgrade, recover it to its
   last-applied machine config while you revert the chart:
   ```bash
   task kubernetes:reboot-cluster-node NODE=<node-ip>   # talosctl reboot --nodes <node-ip>
   ```

## Next

PR 2 — declarative ClusterMesh — depends on this landing and validating. Its first work item is
standing up the `application` cluster in Terraform with a distinct PodCIDR (`10.245.0.0/16`),
since the repo is single-cluster today.
