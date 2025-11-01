---
sidebar_position: 2
---

[Talos Linux](https://www.talos.dev/v1.9/) is a linux operating system that runs and manages kubernetes.

## Core

### Networking

* **CNI**
  - [Cilium](https://docs.cilium.io/en/stable/index.html)
    - [ClusterMesh](https://cilium.io/use-cases/cluster-mesh/) - used for establishing inter cluster networking between `administration` and `mlops`.
* **DNS**
  - [CoreDNS](https://coredns.io/manual/toc/) _ Originally custom coredns configurations were required when running clustermesh. Need to consider if this is still necessary now that cilium created the [mcsapi](https://docs.cilium.io/en/latest/network/clustermesh/mcsapi) which handled resolving dns for services when clustermesh is enabled.
  - [ExternalDNS](https://github.com/kubernetes-sigs/external-dns)
  - [ExternalDNS Unifi Webhook](https://github.com/kashalls/external-dns-unifi-webhook)

* **Certificate Management**
  - [CertManager](https://github.com/cert-manager/cert-manager)

**Layer 4 Proxy**
  - [Gateway API](https://gateway-api.sigs.k8s.io/)
    - [Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/)
  - [Kgateway](https://kgateway.dev/docs/main) - AIGateway for all traffic in `ai` namespace. View docs in [platform/ai]() for further information on all ai related resources.

**Gateways**

Cilium and Kgateway both utilizie GatewayAPI for creating gateway & route declerations. For that reason, we have several different base `Gatewayclasses`. All ai traffic should use `Gatewayclass` with a target from kgateway and non ai workloads will use cilium.

- `Internal Gateway` - All standard ingress traffic
- `Egress Gateway` - All standard egress traffic
- `External Gateway` - Cloudflare tunnel for oauth callbacks from external providers
- `AI Gateway` - All AI traffic in `ai` namespace bot `http`/`tcp`
- `VPN Gateway` - Site to Site VPN traffic from homelab to AWS VPC

#### VPN Gateway

Routes exchanged:
- From Homelab -> AWS: Pod CIDRs (per cluster), Service LB CIDR, on-prem subnets
- From AWS -> Homelab: VPC CIDRs, AWS service subnets

```
      Homelab (Unifi / Proxmox)                      AWS VPC (10.XX.0.0/16)
                |                                               |
         Talos Cluster(s)
           VPN Gateway                                EC2 (FRR+WG)
            Cilium                                         wg0 + BGP
                |                                               |
        +-------+----------------+                      +--------+------+
        | WireGuard tunnel (wg0) |======================| WireGuard wg0 |
        +------------------------+                      +---------------+
                 |   BGP (64512 <-> 64513) over WireGuard   |
                 |-------------------------------------------|

```

**Inter Cluster Networking**

[MCS API](https://docs.cilium.io/en/latest/network/clustermesh/mcsapi/?utm_source=chatgpt.com)
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
                   LAN XXX.XX.X.0/24
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

### Security

  * `Certificates` - certmanager is used to automate certificate management and rotation for all services both internal and external routes.
    - `internal` certficates use internal dns resolution with [externaldns webhook](https://github.com/kashalls/external-dns-unifi-webhook). A cluster issuer exists for issuing all internal certificates.
    - `external` certificates are managed with cloudflare and a issuer exists using cloudflare for issuing these certificates. These services are only exposed over [cloudflare tunnels]().

### Clusters

Cilium clustermesh is used for multi cluster networking. `administration cluster` is responsible for gitops operations and cluster management using [ApplicationSets]() in argocd.

### Administration Cluster

- `admin-ctrl-00`
- `admin-work-00`
- `admin-work-01`

### MLOps Cluster

- `mlops-ctrl-00`
- `mlops-work-00`
- `mlops-work-01`

**vfio-pci** is set as the kernel driver on the GeoForce RTX 4070 Super. This is needed for gpu passthrough to work so the virtualized kubernetes node can utilize it. It is registered in proxmox as a PCIE device which is defined in terraform [here](https://github.com/teaglebuilt/homelab/blob/main/tf_modules/talos_cluster/pci_mapping.tf)

![GPU Node](https://raw.githubusercontent.com/teaglebuilt/homelab/main/docs/static/img/gpu-node.png)
