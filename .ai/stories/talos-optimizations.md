# Talos Optimizations

1. Replace static ip addresses. Can we use dhcp|dns or something with talos config?

Decision record: `docs/adr/0002-node-addressing-dhcp-reservations-dns.md`.
Target: Talos **v1.14.2**, Kubernetes **1.33.13**, docs at `docs.siderolabs.com/talos/v1.14`.

---

# Goal

Write each node IP exactly once, have the router enforce it, and give people and tools names instead of IPs.
Do it in place on both clusters, with no renumbering and no rebuild, since `application` now holds
postgres, qdrant, n8n and open-webui. Talos is three minors behind, and the networking config this
needs only exists from 1.12 onwards, so the upgrade is part of this story.

Scope: `tf_modules/talos_cluster`, `kubernetes/terraform/{mlops,application}`, `kubernetes/clusters/*/cluster.yaml`,
`kubernetes/Taskfile.yml`, `.envrc` / `homelabs.sops.env`, and the UniFi `proxmox` network (VLAN 2).

---

# Diagnosis

Measured 2026-10-03 against both clusters and the UDM.

## The addresses are duplicated, and the copies disagree

Each node IP goes `.envrc` → Taskfile `-var` → Terraform var. From there it is written into both cloud-init
`ip_config` (`/24` plus gateway) **and** Talos `machine.network.interfaces[eth0].addresses`, with no prefix.
Talos treats a bare IP as `/32`, so every node has its address twice:

```
192.168.2.195   AddressSpec   eth0/192.168.2.195/24
192.168.2.195   AddressSpec   eth0/192.168.2.195/32
```

Same on `.19`, `.6`, `.7`. It works only because the cloud-init `/24` supplies the connected route.
The default route also comes from cloud-init. `network_gateway` is passed to both Talos templates and never used.

## The router hands out the cluster's addresses

UniFi `proxmox` network: `192.168.2.1/24`, domain `internal`, **DHCP pool `.6`–`.254`**.

| Address(es) | Used for | In DHCP pool | Reserved |
|---|---|---|---|
| `.6`, `.7` | application ctrl/work | yes | no |
| `.19`, `.195` | mlops work/ctrl | yes | no |
| `.200`–`.240` | Cilium LB pool, mlops (ClusterMesh `.240`) | yes | no |
| `.241`–`.254` | Cilium LB pool, application (ClusterMesh `.248`, n8n tunnel origin `.241`) | yes | no |
| `.100`, `.101` | pve, pve2 | n/a | **yes**, with local DNS |

UniFi has already leased `.253` to an earlier VM (`mlops-worker01`). The Proxmox hosts show the pattern
we want: fixed IP plus local DNS record on the UniFi client.

## Every rebuild makes a new MAC

`network_device` has no `mac_address`. UniFi has about 35 orphaned `bc:24:11:*` client records. Its
`mlops-ctrl-00` record holds `.195` against `bc:24:11:7f:6b:ca`, but the live NIC is `bc:24:11:34:75:78`.
Current MACs, which are the values to pin:

| Node | IP | MAC |
|---|---|---|
| mlops-ctrl-00 | 192.168.2.195 | bc:24:11:34:75:78 |
| mlops-work-00 | 192.168.2.19 | bc:24:11:88:30:ac |
| application-ctrl-00 | 192.168.2.6 | bc:24:11:0b:a8:75 |
| application-work-00 | 192.168.2.7 | bc:24:11:aa:ba:e9 |

## The API endpoint is a node IP

`cluster.endpoint = var.k8s_api_server_ip = MLOPS_MASTER_NODE_IP`. Replacing `*-ctrl-00` breaks every kubeconfig.
`controlplane.yaml.tftpl` also gives *every* control plane node `[controlplane IPs][0]`. That's a latent bug,
hidden only because each cluster has one control plane node.

## Version reality

| | Running | Target | Why |
|---|---|---|---|
| Talos | v1.11.5 (out of support since 1.12.0) | **v1.14.2** | 1.14.2 released 2026-09-29. The network documents (`DHCPv4Config`, `LinkAliasConfig`, `HostnameConfig`, `Layer2VIPConfig`) are 1.12+ |
| Kubernetes | 1.32.2 | **1.33.13** | Talos 1.14 supports 1.33–1.37. Cilium 1.18.11 is tested on 1.30–1.33. The only version both support is 1.33 |
| talosctl (local) | **v1.9.1** | v1.14.2 | Too old to validate 1.12+ documents or run the upgrades |
| terraform-provider-talos | 0.12.0 (locked) | — | Already ships Talos SDK 1.14 |
| bpg/proxmox | 0.114.0 (locked) | — | — |

Platform: `talos.platform=nocloud`, `net.ifnames=0` (hence `eth0`), `pcie_aspm=off` present on `mlops-work-00`.

---

# Decisions

Full reasoning, alternatives and scoring are in ADR-0002. Summary:

### 1. DHCP reservations managed by Terraform, not static IPs and not dynamic DHCP

Each node gets a `unifi_client` (`mac`, `fixed_ip`, `local_dns_record`, `allow_existing = true`), and the same MAC is pinned
on the Proxmox NIC. Talos runs DHCP in maintenance mode by default, so the node gets its reserved IP on first boot,
and Terraform still knows that IP at plan time. That's why we use reservations and not dynamic leases:
the provider's `talos_cluster` rejects non-IP nodes, and etcd peer URLs need a stable IP.

### 2. No renumbering

Reserve each node at its **current** IP and MAC. Switching from static to DHCP then changes nothing that
etcd, certificate SANs, Cilium or ClusterMesh can see. That is what makes the in-place migration safe.

### 3. Machine config carries no IP

The only per-node values are hostname and MAC. `.machine.network` is removed entirely (deprecated since 1.12, and it
conflicts with its replacement documents) and replaced by:

```yaml
apiVersion: v1alpha1
kind: LinkAliasConfig
name: net0
selector:
  match: mac(link.permanent_addr) == "${mac}"
---
apiVersion: v1alpha1
kind: DHCPv4Config
name: net0
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: ${hostname}
```

`net0` matched by MAC replaces the `eth0` assumption, which only holds because nocloud sets `net.ifnames=0`
(v1.14 predictable interface names guide). Add `auto: off` to `HostnameConfig` only if the generated base config
already contains a `HostnameConfig` (v1.14 hostname guide).

### 4. Shrink the DHCP pool to `.6`–`.189`

`.190`–`.199` stay outside the pool for future API VIPs, and `.200`–`.254` (the LB pools) leave the pool.
This is a one-time manual change in the UniFi UI, checked by `task network:check`. We don't manage the whole
`unifi_network` in Terraform, because that pulls in firewall zones.

### 5. The API endpoint becomes a name, and the VIP is deferred

`https://api.<cluster>.homelab.internal:6443` → `unifi_dns_record` → the control plane's reserved IP. With one
control plane node there's nothing for `Layer2VIPConfig` to fail over to. It needs etcd to be up, and it must never
be a talosconfig endpoint (v1.14 VIP guide). When a cluster gets three control plane nodes, add the VIP from `.190`–`.199`
and repoint the record. kubeconfigs don't change. The Talos API stays on control plane IPs.

### 6. `cluster.yaml` is the single addressing source

`apiEndpoint` plus a `nodes: {name: {ip, mac}}` map. Terraform reads it with `yamldecode` and merges it into the node spec in `main.tf`.
This amends the ADR-0001 layout, which put node IPs in `homelab.sops.env`. New-node MAC convention: `bc:24:11:00:HH:LL`,
where `HHLL` is the `vm_id` in hex.

### 7. Upgrade in place, not rebuild

The path is 1.11.5 → 1.12.12 → 1.13.11 → (Kubernetes 1.32.2 → 1.33.13) → 1.14.2. The upgrade guide only tests
adjacent minors, and Talos 1.14 won't run Kubernetes 1.32. Do `application` first: it's single-worker and has no GPU extensions.
Keep `talos_version` (the config contract) pinned at `v1.11.5`. The provider says to change it only for a
deliberate schema change, which would regenerate config. Deprecated `.cluster.*` fields stay valid on 1.14.

---

# Implementation

## Phase 0 — Pre-flight (read-only, blocking)

- [ ] Install talosctl v1.14.2 and pin it (`.tool-versions` / mise).
- [ ] **Check whether bumping the image version replaces VMs.** Bump `image.version` in a scratch plan.
      If `proxmox_download_file` → `disk.file_id` forces replacement of `proxmox_virtual_environment_vm`, add
      `ignore_changes = [disk[0].file_id]` (or freeze `image.version` at the install version) **before** any upgrade.
      Otherwise the first post-upgrade `tofu apply` destroys the node.
- [ ] Back up: `talosctl etcd snapshot` (both control plane nodes), CNPG backup/`pg_dump`, qdrant snapshot, n8n export, and the
      local-path PV contents on `application-work-00`.
- [ ] UniFi: list clients whose `last_ip` is in `.190`–`.254` and aren't LB IPs. Confirm `.190`–`.199` are free.
- [ ] Spike: `unifi_client` with `allow_existing = true` adopts an existing record and creates one for a MAC the
      controller has never seen. Test with a throwaway MAC, then destroy it.
- [ ] Confirm `local_dns_record` serves the FQDN exactly as given (`dig mlops-ctrl-00.homelab.internal @192.168.2.1`).
- [ ] Confirm external-dns-internal (`policy: sync`, `domainFilters: [internal, ...]`) ignores records it doesn't
      own: a Terraform-created `api.*` record survives an external-dns sync loop.

## Phase 1 — Stop DHCP collisions (no node changes)

- [ ] UniFi UI: set the `proxmox` network DHCP range to `192.168.2.6`–`192.168.2.189`. Record it in `docs/network.md`.
- [ ] Pin `ubiquiti-community/unifi` to an exact version in `tf_modules/talos_cluster/version.tf`. Configure the provider in both
      roots with `UNIFI_API` (`homelab.sops.env`) and `UNIFI_API_KEY` (already in `homelab.sops.env`).
- [ ] Add `nodes` (ip, mac) and `apiEndpoint` to both `cluster.yaml`, using the MAC table above.
- [ ] Module: add `mac` to the node object, set `network_device.mac_address`, and add `unifi_client` per node (with
      `fixed_ip` and `allow_existing`, no DNS yet). The VM `depends_on` its `unifi_client`, so a new node's reservation exists before first boot.
- [ ] `tofu plan` for both clusters must show **only** the `unifi_client` creates. A pinned MAC equal to the live MAC
      shouldn't change the VM. If the plan shows a VM update, stop and find out why.
- [ ] Verify the UniFi UI shows four fixed-IP clients that match `cluster.yaml`.

## Phase 2 — Talos and Kubernetes upgrade, in place

For each cluster, `application` first: control plane node, then worker. Run `talosctl health` between every step.

- [ ] Installer image: Image Factory for the node's existing schematic, at the target version. Since 1.14,
      `ghcr.io/siderolabs/installer` is no longer published (v1.14 upgrade guide). Take the URL from
      `talos_image_factory_urls` rather than writing it by hand.
- [ ] `talosctl upgrade` → v1.12.12 → v1.13.11.
- [ ] `talosctl upgrade-k8s --to 1.33.13`.
- [ ] `talosctl upgrade` → v1.14.2.
- [ ] `mlops-work-00` after every hop: `talosctl read /proc/cmdline` contains `pcie_aspm=off`, the NVIDIA extensions are
      loaded, and a GPU pod schedules (1.13 switched Talos to CDI).
- [ ] Update `image.version`, `update_version` and `kubernetes_version` in both `main.tf`. Plan must show no VM replacement (see Phase 0).
      Leave `talos_version` at `v1.11.5`.

## Phase 3 — Machine config stops carrying IPs

- [ ] Add `templates/network.yaml.tftpl` (Decision 3) to both control plane and worker patch lists.
- [ ] Remove `machine.network` from `controlplane.yaml.tftpl` and `worker.yaml.tftpl`. Remove the `node_ip` and `network_gateway`
      template params and the `node_ip` entry in `machine.certSANs`. Interface IPs are added automatically.
- [ ] Set cloud-init `ip_config.ipv4.address = "dhcp"`. Confirm in the plan that it's an in-place cidata update.
- [ ] `talosctl validate --mode cloud` on every rendered config.
- [ ] Apply one node at a time: application-work-00 → application-ctrl-00 → mlops-work-00 → mlops-ctrl-00.
- [ ] Per node: `talosctl get addressspecs --namespace network-config` shows `dhcp4/net0/...` only, with no `/32`.
      `talosctl get links` shows alias `net0`. `talosctl get operatorspecs` shows one `dhcp4/` operator for the link.

## Phase 4 — Names and the API endpoint

- [ ] `unifi_client.local_dns_record = "<node>.homelab.internal"`. Add `unifi_dns_record` A `api.<cluster>.homelab.internal` →
      control plane IP.
- [ ] Add the API name to `cluster.apiServer.certSANs`. Apply the control plane node and check that the served cert includes the name
      (`openssl s_client -connect api.mlops.homelab.internal:6443`).
- [ ] Set `cluster_endpoint` to `https://${apiEndpoint}:6443`. Apply all nodes and regenerate kubeconfigs.
      Bootstrap/kubeconfig `endpoint` and `talos_client_configuration.endpoints` stay as control plane IPs.
- [ ] Verify Cilium (`k8sServiceHost: localhost:7445` via KubePrism, so unaffected) and ClusterMesh (LB IPs, so unaffected).
- [ ] Optional: `kubelet-csr-approver` `bypassDnsResolution: false` now that node names resolve.

## Phase 5 — Remove the old sources, add guardrails

- [ ] Delete `*_NODE_IP` from `.envrc`, `.envrc.next` and `homelab.sops.env`, the `-var ..._ip` flags in `kubernetes/Taskfile.yml`, the
      matching `variables.tf` entries (including the stale mlops `worker_two_node_ip`), and the env lookups in
      `tests/talos_cluster_test.go`.
- [ ] `task network:check` plus a pre-commit hook on `cluster.yaml`. Checks: IP/MAC uniqueness across clusters; IPs outside the LB pools and
      ClusterMesh IPs; read-only UniFi check that `dhcpd_stop` is below the lowest LB pool start and each MAC has
      `fixed_ip` == `cluster.yaml`.
- [ ] Guard: no `192.168.` literal in `tf_modules/talos_cluster/{templates,patches}`.
- [ ] Delete the ~35 orphaned `bc:24:11:*` UniFi client records (one-off).
- [ ] Fix the `image.tf` reference to the non-existent `docs/adr/0001-gpu-node-stability-on-mlops.md`.

---

# What this does not fix

- **API HA.** Each cluster still has one control plane node. The DNS name only makes adding a VIP non-disruptive.
- **Kubernetes beyond 1.33.** Blocked on a Cilium upgrade (1.18 is tested to 1.33).
- **The 1.14 config contract.** `.cluster.*` and `.machine.kubelet` stay on deprecated v1alpha1 fields. Move to
  `KubeClusterConfig` / `KubeAPIServerConfig` / `KubeNodeConfig` only on a future rebuild, with `talos_version` set to `v1.14`.
- **nocloud is a Tier 3 platform.** Once cloud-init carries no network data, `metal` (Tier 1) becomes an option. Not decided here.
- **Boot without the UDM.** A node that reboots while UniFi DHCP is down waits for it (accepted in ADR-0002).

---

# Open questions

1. Is kubectl ever used off the LAN (VPN/Tailscale)? If so, `*.homelab.internal` needs split DNS there, or the
   kubeconfig keeps an IP fallback context.
2. Is the UDM Pro on the UPS with the Proxmox hosts? This decides how much the DHCP-at-boot dependency matters after a power cut.
3. `homelab.internal` (matches the gateways) vs the network's own domain `internal` for node names. The ADR assumes `homelab.internal`.
4. Is the mlops `.195` reservation worth moving out of the VIP block now, or only on the next rebuild? The ADR assumes the next rebuild.
