# Network

```
                         ┌─────────────────────────────────────┐
                         │           INTERNET / WAN            │
                         └──────────────────┬──────────────────┘
                                            │
                              ┌─────────────┴─────────────────┐
                              │     UDM PRO (Gateway/FW)      │
                              │   10.0.0.1 (all VLAN gw)      │
                              │                               │
                              │  Zone Firewall Engine         │
                              │  ┌─────────────────────────┐  │
                              │  │ MGMT ←→ TRUST : allow   │  │
                              │  │ TRUST → MEDIA : allow   │  │
                              │  │ MEDIA → TRUST : deny    │  │
                              │  │ CLIENTS→MEDIA : limited │  │
                              │  │ DL/VPN → ALL  : deny    │  │
                              │  │ IOT   → ALL   : deny    │  │
                              │  │ GUEST → ALL   : deny    │  │
                              │  │ LAB   ← TRUST : allow   │  │
                              │  └─────────────────────────┘  │
                              └─────────────┬─────────────────┘
                                            │ SFP+ 10G
                                            │
                              ┌─────────────┴───────────────── ┐
                              │    USW AGGREGATION (10G)       │
                              │    Layer 2 Backbone            │
                              │    All VLANs trunked           │
                              └──┬────────────── ┬─────────────┘
                                 │ 10G           │ 10G
                    ┌────────────┴───┐    ┌──────┴──────────────┐
                    │ UniFi Pro Max  │    │  Media Server (NAS)  │
                    │ 16-port 2.5G   │    │  Docker Host         │
                    │ PoE+           │    │                      │
                    │                │    │  VLAN 30: Plex,      │
                    │ Access Ports:  │    │    Overseerr, Sonarr │
                    │  VLAN 10: Mgmt │    │    Radarr, Prowlarr  │
                    │  VLAN 20: Trust│    │  VLAN 40: Gluetun +  │
                    │  VLAN 50: IoT  │    │    qBittorrent       │
                    │  VLAN 60: Guest│    └──────────────────────┘
                    │  VLAN 70: Lab  │
                    └────────┬───────┘

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
