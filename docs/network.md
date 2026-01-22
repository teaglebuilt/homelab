# Network

!!! note "Work in Progress"
    Network documentation is being expanded. Check back soon for detailed configuration.

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
