# Network

!!! warning "Unreconciled"
    This diagram and the [VLANs](#vlans) table below disagree. The diagram shows VLANs 10–70
    (Mgmt, Trust, Media, VPN, Ext, Guest, Lab) behind gateway `10.0.0.1`. The table lists only
    Default, IoT and Lab. Neither one has been checked against the live UniFi controller. The
    Kubernetes nodes and LoadBalancer pools are on `192.168.2.0/24` (`kubernetes/clusters/*/cluster.yaml`),
    and neither source shows that subnet.

```mermaid
flowchart TB
    wan([Internet / WAN])

    udm["UDM Pro · gateway / firewall<br/>10.0.0.1 (gateway for all VLANs)"]

    subgraph fw["Zone firewall engine"]
        direction LR
        r1["MGMT ↔ TRUST : allow"]
        r2["TRUST → MEDIA : allow"]
        r3["MEDIA → TRUST : deny"]
        r4["CLIENTS → MEDIA : limited"]
        r5["DL/VPN → ALL : deny"]
        r6["IOT → ALL : deny"]
        r7["GUEST → ALL : deny"]
        r8["LAB ← TRUST : allow"]
    end

    agg["USW Aggregation · 10G<br/>Layer 2 backbone · all VLANs trunked"]

    promax["UniFi Pro Max 16 · 2.5G PoE+<br/>access ports:<br/>VLAN 10 Mgmt · VLAN 20 Trust · VLAN 50 Ext<br/>VLAN 60 Guest · VLAN 70 Lab"]

    nas["Media server (NAS) · Docker host<br/>VLAN 30: Plex, Overseerr, Sonarr, Radarr, Prowlarr<br/>VLAN 40: VPN"]

    pve["Proxmox One"]
    pve2["Proxmox Two"]

    wan --> udm
    udm --- fw
    udm ==>|SFP+ 10G| agg
    agg ==>|10G| promax
    agg ==>|10G| nas
    promax --> pve
    promax --> pve2
```

## Overview

The homelab network is built on Ubiquiti UniFi equipment for reliable, enterprise-grade networking at home.

## Key Components

- **Dream Machine Pro** - Core router and security gateway
- **USW Aggregation** - 10G backbone connectivity
- **UniFi Pro Max 16** - 2.5GbE PoE+ for high-speed device connectivity
- **Aruba 2930f** - Additional PoE+ capacity

## VLANs

| VLAN | Purpose |
|------|---------|
| Default | Management network |
| IoT | Isolated IoT devices |
| Lab | Kubernetes and development |

See [Hardware](hardware.md) for full network equipment details.
