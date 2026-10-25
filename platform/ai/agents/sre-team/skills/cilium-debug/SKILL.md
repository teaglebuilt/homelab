---
name: cilium-debug
description: >
  Cilium datapath debugging for the homelab. Use for pod-to-pod connectivity
  failures and policy drops — endpoint health, identities, IP cache, BPF maps,
  FQDN cache, encryption state and packet capture. Carries the layer-by-layer
  method from cheapest to most expensive, the context-blowout warning, and the
  destructive tools that need confirmation.
---

# Cilium datapath debugging for the homelab

Cilium is the CNI on both clusters and they are peered with ClusterMesh, so a
reachability failure may be local or cross-cluster.

**Establish which before going deep.** A global Service that resolves but
refuses connections is a different problem from one that does not resolve at
all. If the destination is cross-cluster, peering health comes first and that is
the cilium-manager specialist's question, not a datapath question.

## Layers, cheapest first

Work down this list and stop when you have the answer. Each layer explains a
distinct class of failure.

**1. Endpoint and node state.**
`cilium_get_endpoint_health`, `cilium_get_endpoints_list`,
`cilium_list_cluster_nodes`.

An endpoint not in ready state explains most "pod cannot talk" reports on its
own. Check this before anything else — it is one call and it ends many
investigations.

**2. Identity and policy.**
`cilium_list_identities`, `cilium_get_identity_details`,
`cilium_display_policy_node_information`, `cilium_display_selectors`.

A drop with no matching allow rule is a **policy** problem, not a datapath
problem. Cilium is default-allow until a policy selects the endpoint, and then
default-deny for that endpoint — so adding the first policy to a namespace
breaks everything it does not explicitly allow. That is the most common
self-inflicted outage here.

**3. Address resolution.**
`cilium_list_ip_addresses`, `cilium_show_ip_cache_information`, and
`cilium_show_dns_names` or `cilium_fqdn_cache` when the destination is a name
and the policy is FQDN-based.

A stale FQDN cache entry presents exactly like an intermittent outage — the
connection works, then does not, with no config change between.

**4. The datapath itself.**
`cilium_list_bpf_maps`, `cilium_get_bpf_map`, `cilium_list_bpf_map_events`, and
`cilium_display_encryption_state` when traffic crosses nodes.

**5. Drop counters.**
`cilium_list_metrics` tells you whether a drop is ongoing or was a one-off,
which decides whether you are debugging a live fault or a past one.

## Expensive calls

`cilium_request_debugging_information` returns an enormous dump and **will crowd
out your context**. Treat it as a last resort, never as a first look. If you
call it, say why the cheaper layers were insufficient.

Packet capture through the PCAP recorder tools: create one only when the
operator asks and you have a specific flow to capture, and **delete it when you
are done**. A recorder left running costs resources indefinitely.

## Always pass node_name

Most tools take a `node_name`. Supply it when the problem is on a specific node.
Without it the result is whichever agent happens to answer, which makes findings
irreproducible and can send you chasing a healthy node.

## Destructive tools

Confirm with the operator before any of these, and never run one to test a
theory:

| Tool | Effect |
| --- | --- |
| `cilium_flush_ipsec_state` | disrupts encrypted traffic cluster-wide |
| `cilium_disconnect_endpoint` | cuts a pod off the network |
| `cilium_manage_endpoint_labels` | can change which policies apply to a live pod |
| `cilium_manage_endpoint_config` | changes live endpoint behaviour |

A label change is the sneaky one: it looks like metadata but it re-evaluates
policy selection, so it can open or close traffic immediately.

## Repo

Cilium config lives in `kubernetes/apps/networking/cilium/` with per-cluster
identity and mesh values under `kubernetes/clusters/*/`. Policy objects belong
in the repo; a live-applied CiliumNetworkPolicy is reverted on the next sync.

## Reporting

Name the layer you proved broken — endpoint, identity, policy, resolution,
datapath or encryption — and quote the state or counter that shows it. Give the
remedy and label it **read-only** or **mutating**.
