# 0002. Address Talos nodes with UniFi DHCP reservations and DNS names, not static IPs

- **Status:** Proposed
- **Date:** 2026-10-03
- **Deciders:** teaglebuilt
- **Tags:** networking, talos, terraform, unifi, dns
- **Target Talos version:** v1.14.2 (docs: `docs.siderolabs.com/talos/v1.14`)
- **Amends:** ADR-0001 file layout (node IPs move from `homelab.sops.env` to `kubernetes/clusters/*/cluster.yaml`)

## Context

Every Talos node IP is written by hand and then copied into five places:

1. `.envrc` (`MLOPS_MASTER_NODE_IP=192.168.2.195`, `APP_MASTER_NODE_IP=192.168.2.6`, ...). ADR-0001 moves these to `homelab.sops.env`.
2. `kubernetes/Taskfile.yml`, as `-var` flags on every plan, apply and destroy.
3. Proxmox cloud-init: `initialization.ip_config` in `tf_modules/talos_cluster/main.tf`, with `/24` and the gateway.
4. The Talos machine config: `machine.network.interfaces[eth0].addresses` in both `templates/*.yaml.tftpl`, with **no prefix length**.
5. The Kubernetes API endpoint: `cluster.endpoint` is the control plane node IP, which ends up in every kubeconfig.

Measured on 2026-10-03:

- **Every node has its address twice.** `talosctl get addressspecs` shows
  `eth0/192.168.2.195/24` (from nocloud) and `eth0/192.168.2.195/32` (from the machine config) on every
  node. Sources 3 and 4 disagree, and the Talos default for a bare IP is `/32`. Nothing breaks today
  only because the `/24` from cloud-init supplies the connected route.
- **The router doesn't know any of these addresses.** The UniFi `proxmox` network (VLAN 2,
  `192.168.2.0/24`, domain `internal`) runs DHCP over **`.6`–`.254`**. All four node IPs
  (`.6`, `.7`, `.19`, `.195`), both Cilium LB pools (`.200`–`.240` mlops, `.241`–`.254` application) and
  both ClusterMesh API server IPs are inside that range, and none of them are reserved. UniFi has
  already handed `.253` (inside the application LB pool) to an earlier VM. The only reserved
  addresses on the network are the two Proxmox hosts (`.100`, `.101`).
- **Every rebuild creates a new MAC.** `network_device` has no `mac_address`, so Proxmox makes up a
  new `bc:24:11:*` MAC on every replacement. UniFi holds about 35 orphaned client records from past rebuilds.
- **The API endpoint is tied to one node's IP.** Replacing or renumbering `*-ctrl-00` breaks every kubeconfig.
  Adding a second control plane isn't possible without changing the endpoint.
- `templates/controlplane.yaml.tftpl` gives every control plane node `[controlplane IPs][0]`.
  That works only because each cluster has one control plane node.

Constraints:

- **Talos v1.11.5 has been out of community support since 1.12.0.** The current release is v1.14.2
  (2026-09-29), and this design targets the 1.14 docs. Since 1.12, `.machine.network` is deprecated in favour
  of separate documents (`LinkConfig`, `DHCPv4Config`, `HostnameConfig`, `LinkAliasConfig`,
  `Layer2VIPConfig`; 1.12.0 release notes). 1.14 does the same for `.cluster.*`
  (`KubeClusterConfig`, `KubeAPIServerConfig`, ...). Deprecated fields and their replacement documents are
  mutually exclusive unless the docs say otherwise (v1.14 upgrade guide, "Machine configuration changes").
- **Kubernetes:** Talos 1.14 supports Kubernetes 1.33–1.37 (v1.14 support matrix). Cilium 1.18.11 is tested on
  1.30–1.33. The only version both support is **1.33**. The clusters run 1.32.2.
- **Provisioning needs IPs, not names.** `talos_machine_configuration_apply` targets
  `node = <ip>`, and the provider's new `talos_cluster` resource rejects non-IP node addresses at plan time
  (terraform-provider-talos v0.12.0). Provider 0.12.0 (Talos SDK 1.14) and bpg/proxmox 0.114.0 are already locked.
- One operator, two clusters, one L2 subnet, one UDM Pro that is already the default gateway and DNS server
  for every node (`talosctl get resolvers`: `192.168.2.1`).
- The application cluster now holds state (postgres, qdrant, n8n, open-webui; local-path PVs). The
  migration must work **in place**. A rebuild isn't acceptable.

## Decision Drivers

1. **One source of truth per address.** An IP is written once and everything else derives from it.
2. **The router knows every address.** Nothing the cluster uses can be handed out by DHCP to something else.
3. **Rebuilds need no manual steps.** Replacing a VM gives it back the same IP and name with nothing done by hand.
4. **People and tools use names.** kubeconfigs, docs and runbooks shouldn't hard-code node IPs.
5. **Don't add a dependency without paying for it.** Each new provider or runtime dependency has to earn its place.
6. **Follow the direction Talos is going.** Machine config is the primary source of network truth
   (v1.14 networking overview), written in 1.12+ documents.

## Considered Options

1. **Static IPs, cleaned up.** Keep static addressing with one source (cloud-init) and shrink the DHCP range.
2. **UniFi DHCP reservations managed by Terraform, plus DNS names (chosen).**
3. **Fully dynamic DHCP, with IPs read back from the QEMU guest agent, plus DNS.**
4. **Talos Layer 2 VIP for the API endpoint now.** Considered alongside 1–3 and deferred (see Decision).

### 1. Static IPs, cleaned up

- **How it works:** remove `interfaces[].addresses` from the Talos templates and let the Proxmox
  cloud-init network-config be the only static source. A static source outside the machine config is
  needed because the node has to have an address in maintenance mode, before Terraform can apply config.
  Shrink the UniFi DHCP range so it excludes the node and LB space. Add `unifi_dns_record`s for names if wanted.
- **Good:** no runtime dependency on DHCP. A node gets its address even if the UDM is down. Smallest change.
- **Bad:** UniFi still doesn't know which MAC owns which IP. Collisions are prevented only by range hygiene,
  which is the defect we have today. Addressing stays tied to the `nocloud` platform, which is Tier 3 (v1.14 support
  matrix), and to cloud-init. That goes against the docs' advice to treat machine config as the source of truth. Names still need a
  separate DNS mechanism, which brings in the UniFi provider anyway, so the dependency saving mostly disappears.

### 2. UniFi DHCP reservations, managed by Terraform (chosen)

- **How it works:** each node gets a fixed `mac` and `ip` in `cluster.yaml`. The `talos_cluster` module
  creates a `unifi_client` per node (`mac`, `fixed_ip`, `local_dns_record = <node>.homelab.internal`,
  `allow_existing = true`). It sets the same `mac_address` on the Proxmox `network_device`, and sets cloud-init
  `ip_config` to `dhcp`. The Talos machine config contains no IP. It declares
  `LinkAliasConfig net0` (selected by that MAC), `DHCPv4Config net0`, and `HostnameConfig`. On first boot Talos
  runs DHCP by default in maintenance mode and gets the reserved IP, so Terraform still knows the
  node's address at plan time. The API endpoint becomes `https://api.<cluster>.homelab.internal:6443`, a
  `unifi_dns_record` pointing at the control plane's reserved IP.
- **Good:** each IP is written once (`cluster.yaml`) and the router enforces it (drivers 1, 2). A rebuild gets the same MAC,
  so the same IP and name, with nothing done by hand (driver 3). Names come from the same UniFi object as the
  reservation (driver 4). Machine config becomes identical across nodes apart from hostname and MAC. Templates lose
  `node_ip`, `network_gateway`, and the multi-control-plane IP bug. **The migration needs no renumbering:** reserve
  each node at its current IP and MAC, so etcd peer URLs, certificate SANs and Cilium don't change.
- **Bad:** a node that boots while the UDM's DHCP server is down gets no address (see Consequences). Adds a
  pre-1.0 provider (`ubiquiti-community/unifi`, v0.59.0, active; the `paultyng` original is archived). UniFi
  becomes part of the Terraform blast radius.
- **Evidence:** the Proxmox hosts are already addressed this way (UniFi fixed IP plus local DNS record), and
  `external-dns-unifi` already writes `*.homelab.internal` into the same controller.

### 3. Fully dynamic DHCP, IPs read from the QEMU guest agent

- **How it works:** no reservations. Terraform reads `ipv4_addresses` from the bpg VM resource after boot and
  feeds it to the config apply. DNS follows the leases.
- **Bad:** node IPs are only known after apply, so every apply depends on boot timing. The provider's `talos_cluster`
  rejects non-IP nodes at plan time. A control plane node whose lease changes moves its etcd peer URL. The address
  plan stops being declarative. This solves a problem we don't have, because nodes are not
  short-lived, and gives up drivers 1 and 3.
- **Verdict:** rejected.

### 4. Talos Layer 2 VIP for the API endpoint

- **How it works:** `Layer2VIPConfig` on control plane nodes, with a VIP outside the DHCP range.
- **Why deferred:** with one control plane per cluster there's nothing to fail over to. The VIP only comes up
  once etcd is healthy, and it must not be used as a talosconfig endpoint (v1.14 VIP guide, "Caveats"). The DNS name
  from option 2 already separates clients from the node's IP. When a cluster gets three control plane nodes, add the VIP and point
  the `api.<cluster>` record at it. The kubeconfig doesn't change.

### Scoring

Weights reflect a single-operator homelab: correctness and rebuild ergonomics outweigh boot-time independence,
because a node without the UDM has no gateway or DNS anyway.

| Driver (weight) | 1. Static, cleaned up | 2. Reservations + DNS | 3. Dynamic + agent |
|---|---|---|---|
| Single source of truth (25) | 4 | 5 | 2 |
| Rebuild with no manual steps (20) | 4 | 5 | 2 |
| No DHCP dependency at boot (20) | 5 | 3 | 2 |
| Names for people and tools (15) | 2 | 5 | 4 |
| New dependencies / complexity (10) | 5 | 3 | 2 |
| Fits Talos 1.14 direction (10) | 3 | 5 | 3 |
| **Weighted (/500)** | **390** | **440** | **240** |

Option 1 is a reasonable choice if zero new dependencies matters most. The gap comes from DNS and from UniFi
knowing every MAC-to-IP binding. Option 1 needs the UniFi provider for names anyway, so it saves less than it seems.

## Decision

Option 2. Option 4 is deferred until a cluster has more than one control plane node.

### Address plan for `192.168.2.0/24`

| Range | Use | Managed by |
|---|---|---|
| `.1` | UDM gateway / DNS | UniFi |
| `.6`–`.189` | DHCP pool (was `.6`–`.254`). Node reservations stay at their current IPs | UniFi (pool), Terraform (reservations) |
| `.190`–`.199` | Outside the pool, reserved for future API VIPs | `cluster.yaml` |
| `.200`–`.240` | Cilium LB pool, mlops (incl. ClusterMesh `.240`) | `cluster.yaml` |
| `.241`–`.254` | Cilium LB pool, application (incl. ClusterMesh `.248`) | `cluster.yaml` |

`mlops-ctrl-00` (`.195`) keeps its current IP as a reservation in the `.190`–`.199` block. Move it the next time the node is rebuilt.

### `cluster.yaml` becomes the addressing source

```yaml
apiEndpoint: api.mlops.homelab.internal
nodes:
  mlops-ctrl-00: { ip: 192.168.2.195, mac: "bc:24:11:34:75:78" }
  mlops-work-00: { ip: 192.168.2.19,  mac: "bc:24:11:88:30:ac" }
```

Terraform reads it with `yamldecode(file(...))` and merges it into the per-node spec in `main.tf` (vm_id, cpu, ram, pci).
Helmfile already reads the same file. `*_NODE_IP` leaves `.envrc` / `homelab.sops.env` and the Taskfile `-var` flags.
New nodes use the MAC convention `bc:24:11:00:HH:LL`, where `HHLL` is the `vm_id` in hex.

### Talos documents (per node, generated by the module)

```yaml
apiVersion: v1alpha1
kind: LinkAliasConfig
name: net0
selector:
  match: mac(link.permanent_addr) == "bc:24:11:34:75:78"
---
apiVersion: v1alpha1
kind: DHCPv4Config
name: net0
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: mlops-ctrl-00
```

If the generated base config already contains a `HostnameConfig` (talos_version contract 1.12 or later), the patch also sets
`auto: off` (v1.14 hostname guide). The `.machine.network` block is removed entirely: it's deprecated, and the
replacement documents conflict with it. Control plane nodes add the API name to the API server cert SANs.
Under the pinned contract that is `cluster.apiServer.certSANs`; under a 1.14 contract it is
`KubeAPIServerConfig.certExtraSANs`. Interface IPs don't need listing in `machine.certSANs`, because Talos adds all
non-loopback interface IPs automatically (v1alpha1 reference).

Talos API access stays on control plane IPs (`talos_client_configuration.endpoints`, bootstrap and kubeconfig
`endpoint`), never the API name or a VIP. If DNS or the VIP is down, the Talos API is how you recover.

## Consequences

### Positive

- One write per address. The `/32` duplicate, the unused `network_gateway`, the `node_ip`-for-every-control-plane bug, and
  four `-var` flags per Taskfile command all go away.
- The router can no longer hand a node IP or LB IP to another device.
- VM replacement is repeatable: same MAC, same lease, same name. UniFi forgets the client when Terraform destroys it,
  so orphaned records stop piling up.
- kubeconfigs survive control plane replacement, and the path to an HA control plane is just adding the VIP.
- `kubelet-csr-approver` can drop `bypassDnsResolution: true` once node names resolve.

### Negative

- **Nodes need DHCP at boot.** If the UDM is down when a node boots, the node has no address until it
  comes back. Talos keeps retrying, and a node that is already running keeps its lease until expiry (UniFi default: 1 day).
  A static node would come up but still have no gateway or DNS. We accept this.
- **A pre-1.0 provider in the provisioning path.** Pin it to an exact version. UniFi OS updates can change the
  controller API under it. Needs `UNIFI_API` (homelab.sops.env) and `UNIFI_API_KEY` (already in `homelab.sops.env`) inside
  `task secrets:run`.
- **Clients off the LAN need split DNS** to resolve `*.homelab.internal` for kubectl. LAN clients already depend on it for gateways.
- **`cluster.yaml` is now read by both Helmfile and Terraform.** A schema change affects both.
- **MACs are now config.** A copy-pasted MAC is a silent conflict. The fitness check catches it.

### Neutral / follow-ups

- The DHCP range change is done once by hand in the UniFi UI, recorded in `docs/network.md`, and checked by
  the fitness function. Managing the whole `unifi_network` in Terraform pulls firewall zones in too, which is too much.
- Switching the image from `nocloud` (Tier 3) to `metal` (Tier 1) becomes possible once cloud-init carries no
  network data. Not decided here.
- `image.tf` cites `docs/adr/0001-gpu-node-stability-on-mlops.md`, which doesn't exist (0001 is secrets). Fix the reference.

## Fitness functions

- `task network:check` (also a pre-commit hook on `kubernetes/clusters/*/cluster.yaml`): node IPs and MACs are unique
  across clusters, inside `192.168.2.0/24`, outside every `lbPool` and ClusterMesh IP, and outside `.190`–`.199` (except grandfathered `.195`).
  Read-only against the UniFi API: the `proxmox` network's `dhcpd_stop` is below the lowest `lbPool` start, and each
  node MAC has `use_fixedip` with `fixed_ip` equal to `cluster.yaml`.
- `tofu test` / plan-time check: no `192.168.` literal in `tf_modules/talos_cluster/{templates,patches}`, and
  `talosctl validate --mode cloud` passes on each rendered machine config.
- Post-apply: `talosctl get addressspecs --namespace network-config` shows only `dhcp4/net0/...` for the node
  address, and no `/32`. `dig +short api.<cluster>.homelab.internal @192.168.2.1` returns the control plane IP.
