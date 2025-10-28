# Kubernetes Cluster Networking

### Layer 4 Traffic Routing

- Cilium provides L2/L3 networking and LB IPs from `CILIUM_LB_CIDR`.
- ExternalDNS syncs DNS: Cloudflare (public) and Unifi (internal).
- ai-gateway terminates TLS and routes to app HTTPRoutes.

```
                       Internet
                           |
                 +---------+---------+
                 |                   |
        Cloudflare (Public DNS)   Unifi (Internal DNS)
                 |                   |
                 +---------+---------+
                           |
                  Unifi Gateway / Edge
                           |
                   LAN 192.168.2.0/24
                           |
                  +-------------------+
                  |    Proxmox Host   |
                  +-------------------+
                     |      |      |
                 192.168.2.195  .19   .20
                   Talos ctl  worker0 worker1
                           |
                   Kubernetes Cluster
                           |
        +------------------+------------------+
        |                  |                  |
     Cilium           Gateway API        cert-manager
   (LB/IPAM           (Gateways &         (ACME via
  CILIUM_LB_CIDR)      HTTPRoutes)        Cloudflare)
        |                  |                  |
   LoadBalancer        ai-gateway         TLS Secrets
      IPs          (ai.homelab.internal)        |
                           |                   |
                   HTTPRoutes (e.g. /ollama)   |
                           |                   |
                        Backends / Services <--+
                       (Ollama, vLLM, n8n)
```


### Inter Cluster Networking

connects multiple Talos clusters (e.g., `mlops` and `administration` from using ciliums clustermesh for cross-cluster service discovery and traffic.

```
                       Internet
                           |
                 +---------+---------+
                 |                   |
        Cloudflare (Public DNS)   Unifi (Internal DNS)
                 |                   |
                 +---------+---------+
                           |
                  Unifi Gateway / Edge
                           |
                   LAN 192.168.2.0/24
                           |
         +-----------------+-----------------+
         |                                   |
   Proxmox Host(s)                       Proxmox Host(s)
         |                                   |
   Talos Cluster: mlops               Talos Cluster: administration
   (AI workloads)                     (platform/ops)
         |                                   |
   +-----+-------------------+         +-----+-------------------+
   | Cilium (BGP, LB/IPAM)   |         | Cilium (BGP, LB/IPAM)   |
   | ClusterMesh (peer)      |<------->| ClusterMesh (peer)      |
   +-----------+-------------+         +-----------+-------------+
               |                                   |
     Gateway API / KGateway                Gateway API
     ai-gateway (TLS)                      admin-gateway (TLS)
               |                                   |
        HTTPRoutes (/ollama, ...)          HTTPRoutes (admin apps)
               |                                   |
        Services / Backends                Services (Argocd, Observability, etc.)
```

### VPN Routing

Cilium supports bgp routing which allows us to use dynamic vpn configurations. In other words, AWS will mirror the same network configurations and advertise accordingly.

```
      Homelab (Unifi / Proxmox)                      AWS VPC (10.20.0.0/16)
                |                                               |
         Talos Cluster(s)                                 EC2 (FRR+WG)
            Cilium                                         wg0 + BGP
                |                                               |
        +-------+----------------+                      +--------+------+
        | WireGuard tunnel (wg0) |======================| WireGuard wg0 |
        +------------------------+                      +---------------+
                 |   BGP (64512 <-> 64513) over WireGuard   |
                 |-------------------------------------------|

```
